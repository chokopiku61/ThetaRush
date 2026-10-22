# frozen_string_literal: true

require "test_helper"

class ContestSubmissionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
    @contest = Contest.create!(
      title: "Submission Cup",
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      status: "running"
    )
    @problem = Problem.create!(
      title: "Contest Output",
      slug: "contest-output",
      statement: "Print the answer.",
      rating: 1100,
      tags: [ "implementation" ]
    )
    ContestProblem.create!(contest: @contest, problem: @problem, position: 1, letter: "A")
    sign_in_as(@user)
  end

  test "registered user creates a contest submission" do
    ContestParticipation.create!(user: @user, contest: @contest)

    assert_enqueued_with(job: JudgeSubmissionJob) do
      assert_difference("Submission.count", 1) do
        post problem_submissions_path(@problem), params: {
          contest_id: @contest.id,
          language: "python",
          source_code: "print(42)"
        }
      end
    end

    submission = Submission.order(:id).last
    assert_equal @contest, submission.contest
    assert_redirected_to submission_path(submission)
  end

  test "unregistered user cannot create a contest submission" do
    assert_no_difference("Submission.count") do
      post problem_submissions_path(@problem), params: {
        contest_id: @contest.id,
        language: "python",
        source_code: "print(42)"
      }
    end

    assert_redirected_to contest_path(@contest)
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
