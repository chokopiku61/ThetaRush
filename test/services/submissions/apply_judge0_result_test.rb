# frozen_string_literal: true

require "test_helper"

module Submissions
  class ApplyJudge0ResultTest < ActiveSupport::TestCase
    include ActionCable::TestHelper

    parallelize(workers: 1)

    setup do
      @contest = Contest.create!(
        title: "Verdict Cup",
        starts_at: 1.hour.ago,
        ends_at: 1.hour.from_now,
        status: "running"
      )
      @problem = Problem.create!(
        title: "Verdict Problem",
        slug: "verdict-problem",
        statement: "Return the expected value.",
        rating: 1200,
        tags: [ "math" ]
      )
      ContestProblem.create!(contest: @contest, problem: @problem, position: 1, letter: "A")
      @participation = ContestParticipation.create!(user: users(:one), contest: @contest)
      @submission = Submission.create!(
        user: users(:one),
        problem: @problem,
        contest: @contest,
        language: "python",
        source_code: "print(42)",
        status: "judging",
        judge0_token: [ "token-1" ].to_json,
        submitted_at: @contest.starts_at + 10.minutes
      )
    end

    test "terminal contest verdict updates standings" do
      client = Object.new
      client.define_singleton_method(:fetch_batch) do |_tokens|
        [
          {
            "status" => { "id" => 3, "description" => "Accepted" },
            "time" => "0.01",
            "memory" => 1024
          }
        ]
      end

      ApplyJudge0Result.call(@submission, client: client)

      assert_equal "ac", @submission.reload.status
      assert_equal 1, @participation.reload.solved_count
      assert_equal 10, @participation.penalty
      assert_equal 1, @participation.rank
    end

    test "judging result does not change standings" do
      client = Object.new
      client.define_singleton_method(:fetch_batch) do |_tokens|
        [ { "status" => { "id" => 2, "description" => "Processing" } } ]
      end

      ApplyJudge0Result.call(@submission, client: client)

      assert_equal "judging", @submission.reload.status
      assert_equal 0, @participation.reload.solved_count
      assert_nil @participation.rank
    end

    test "accepted verdict replaces all rows in rank order on this contest stream only" do
      opponent = ContestParticipation.create!(user: users(:two), contest: @contest,
                                               registered_at: @participation.registered_at - 1.minute)
      Contests::Scoring.recompute_contest!(@contest)
      assert_equal 1, opponent.reload.rank
      other = Contest.create!(title: "Other Cup", starts_at: @contest.starts_at,
                              ends_at: @contest.ends_at, status: "running")

      assert_no_broadcasts("#{other.to_gid_param}:scoreboard") do
        messages = capture_broadcasts(stream) { apply_result(3) }
        assert_equal 1, messages.size
        fragment = Nokogiri::HTML5.fragment(messages.first)
        replacement = fragment.at_css('turbo-stream[action="replace"][target="scoreboard_rows"]')
        assert replacement
        assert_equal 1, replacement.css("template tbody#scoreboard_rows").size
        assert_equal [ [ "1", users(:one).username, "1", "10" ],
                       [ "2", users(:two).username, "0", "0" ] ],
                     replacement.css("tbody tr").map { |row| row.css("td").map { |cell| cell.text.strip } }
      end
    end

    test "wrong answer then accepted and duplicate callbacks keep penalty and rows stable" do
      assert_broadcasts(stream, 1) { apply_result(4) }
      assert_equal 0, @participation.reload.penalty

      accepted = @submission.dup
      accepted.assign_attributes(status: "judging", judge0_token: [ "token-2" ].to_json,
                                 submitted_at: @submission.submitted_at + 5.minutes)
      accepted.save!
      @submission = accepted
      first = capture_broadcasts(stream) { apply_result(3) }
      duplicate = capture_broadcasts(stream) { apply_result(3) }

      assert_equal 35, @participation.reload.penalty
      assert_equal 1, @participation.solved_count
      assert_equal first, duplicate
      assert_equal 1, Nokogiri::HTML5.fragment(duplicate.first).css("tbody tr").size
    end

    test "pending and practice results do not broadcast" do
      assert_no_broadcasts(stream) { apply_result(2) }
      @submission.update!(contest: nil)
      assert_no_broadcasts(stream) { apply_result(3) }
      assert_equal "ac", @submission.reload.status
    end

    test "terminal verdict without participation does not broadcast" do
      @submission.update!(user: users(:two))

      assert_no_broadcasts(stream) { apply_result(3) }
      assert_equal "ac", @submission.reload.status
    end

    test "stale pending callback cannot overwrite a persisted terminal verdict" do
      stale = Submission.find(@submission.id)
      apply_result(3)
      @submission = stale

      assert_no_broadcasts(stream) { apply_result(2) }
      assert_equal "ac", @submission.reload.status
    end

    test "broadcast waits for the enclosing transaction to commit" do
      assert_broadcasts(stream, 1) do
        Submission.transaction do
          assert_no_broadcasts(stream) { apply_result(3) }
          assert_equal 1, @participation.reload.solved_count
        end
      end
    end

    test "rollback discards verdict standings and broadcast" do
      assert_no_broadcasts(stream) do
        Submission.transaction do
          apply_result(3)
          raise ActiveRecord::Rollback
        end
      end

      assert_equal "judging", @submission.reload.status
      assert_equal 0, @participation.reload.solved_count
      assert_nil @participation.rank
    end

    test "scoring failure rolls back verdict and does not broadcast" do
      contest = @submission.contest
      contest.define_singleton_method(:contest_participations) { raise "Scoring unavailable" }
      @submission.define_singleton_method(:contest) { contest }

      assert_no_broadcasts(stream) do
        error = assert_raises(RuntimeError) { apply_result(3) }
        assert_equal "Scoring unavailable", error.message
      end
      assert_equal "judging", @submission.reload.status
      assert_equal 0, @participation.reload.solved_count
    end

    test "broadcast failure preserves the committed verdict and standings" do
      adapter = pubsub_adapter
      adapter.define_singleton_method(:broadcast) { |*_args| raise "Cable unavailable" }

      apply_result(3)

      assert_equal "ac", @submission.reload.status
      assert_equal 1, @participation.reload.solved_count
      assert_equal 10, @participation.penalty
    ensure
      adapter.singleton_class.remove_method(:broadcast)
    end

    private

    def stream
      "#{@contest.to_gid_param}:scoreboard"
    end

    def apply_result(status_id)
      client = Object.new
      client.define_singleton_method(:fetch_batch) do |_tokens|
        [ { "status" => { "id" => status_id }, "time" => "0.01", "memory" => 1024 } ]
      end
      ApplyJudge0Result.call(@submission, client: client)
    end
  end
end
