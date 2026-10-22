# frozen_string_literal: true

require "test_helper"

class FinalizeContestJobTest < ActiveJob::TestCase
  setup do
    @contest = Contest.create!(
      title: "Finished Cup",
      starts_at: 2.hours.ago,
      ends_at: 1.hour.ago,
      status: "running"
    )
    @problem = Problem.create!(
      title: "Rating Problem",
      slug: "rating-problem",
      statement: "Solve it.",
      rating: 1200,
      tags: [ "math" ]
    )
    ContestProblem.create!(contest: @contest, problem: @problem, position: 1, letter: "A")
    ContestParticipation.create!(contest: @contest, user: users(:one))
    ContestParticipation.create!(contest: @contest, user: users(:two))
    Submission.create!(
      contest: @contest,
      problem: @problem,
      user: users(:one),
      language: "python",
      source_code: "print(1)",
      status: "ac",
      submitted_at: @contest.starts_at + 10.minutes
    )
  end

  test "finalizes standings and persists rating changes once" do
    assert_difference("RatingHistory.count", 2) do
      FinalizeContestJob.perform_now(@contest.id)
    end

    assert_equal "finalized", @contest.reload.status
    assert_equal 1, @contest.contest_participations.find_by!(user: users(:one)).rank
    assert_equal 1516, users(:one).reload.rating
    assert_equal 1484, users(:two).reload.rating
    assert_equal 1516, users(:one).max_rating

    assert_no_difference("RatingHistory.count") do
      FinalizeContestJob.perform_now(@contest.id)
    end
    assert_equal 1516, users(:one).reload.rating
  end

  test "does not finalize an active contest" do
    @contest.update!(ends_at: 1.hour.from_now)

    assert_raises(ArgumentError) { FinalizeContestJob.perform_now(@contest.id) }
    assert_not_equal "finalized", @contest.reload.status
    assert_not RatingHistory.exists?(contest: @contest)
  end
end
