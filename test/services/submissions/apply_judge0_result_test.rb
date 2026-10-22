# frozen_string_literal: true

require "test_helper"

module Submissions
  class ApplyJudge0ResultTest < ActiveSupport::TestCase
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
  end
end
