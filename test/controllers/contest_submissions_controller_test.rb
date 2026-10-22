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

  test "signed in user without prior participation auto joins and submits" do
    assert_not ContestParticipation.exists?(user: @user, contest: @contest)

    get problem_path(@problem, contest_id: @contest.id)
    assert_response :success
    assert_select "form[action=?]", problem_submissions_path(@problem)
    assert ContestParticipation.exists?(user: @user, contest: @contest)

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

  test "user cannot create a contest submission when contest is closed" do
    @contest.update!(status: "finished", ends_at: 1.hour.ago)

    assert_no_difference("Submission.count") do
      post problem_submissions_path(@problem), params: {
        contest_id: @contest.id,
        language: "python",
        source_code: "print(42)"
      }
    end

    assert_redirected_to contest_path(@contest)
  end

  test "turbo stream status update does not include submit control" do
    ContestParticipation.create!(user: @user, contest: @contest)

    assert_difference("Submission.count", 1) do
      post problem_submissions_path(@problem),
           params: {
             contest_id: @contest.id,
             language: "python",
             source_code: "print(42)"
           },
           as: :turbo_stream
    end

    assert_response :success
    assert_match(/id="submission-status"/, response.body)
    assert_match(/pkg-menu__latest/, response.body)
    assert_match(/Queued|Judging|queued|judging/i, response.body)
    assert_no_match(/type="submit"/, response.body)
  end

  test "workspace package menu shows latest and older submissions" do
    ContestParticipation.create!(user: @user, contest: @contest)
    older = @user.submissions.create!(
      problem: @problem,
      contest: @contest,
      language: "python",
      source_code: "print(1)",
      status: "wa",
      submitted_at: 2.hours.ago
    )
    latest = @user.submissions.create!(
      problem: @problem,
      contest: @contest,
      language: "cpp",
      source_code: "int main(){}",
      status: "ac",
      time_ms: 45,
      memory_kb: 12000,
      submitted_at: 7.minutes.ago
    )

    get problem_path(@problem, contest_id: @contest.id)
    assert_response :success
    assert_select ".pkg-menu__latest"
    assert_select ".pkg-menu__latest .badge--ac"
    assert_select ".pkg-menu__latest", text: /C\+\+|cpp/i
    assert_select ".pkg-menu__open[href=?]", submission_path(latest)
    assert_select ".pkg-menu__row", minimum: 1
    assert_select ".pkg-menu__id[href=?]", submission_path(older)
    assert_select ".workspace__status-actions input[type=submit]"
    assert_select ".workspace__status-actions a", text: /All submissions|Все посылки/
  end

  test "contest workspace shows letter tabs and adjacent links" do
    problem_b = Problem.create!(
      title: "Contest B",
      slug: "contest-b",
      statement: "Second task.",
      rating: 1200,
      tags: [ "implementation" ]
    )
    ContestProblem.create!(contest: @contest, problem: problem_b, position: 2, letter: "B")

    get problem_path(@problem, contest_id: @contest.id)
    assert_response :success
    assert_select ".contest-nav"
    assert_select ".contest-nav__letter", count: 2
    assert_select ".contest-nav__letter--active", text: "A"
    assert_select "a.contest-nav__letter[href=?]", problem_path(problem_b, contest_id: @contest.id), text: "B"
    assert_select "a.contest-nav__adjacent[rel=next][href=?]", problem_path(problem_b, contest_id: @contest.id)
    assert_select ".contest-nav__adjacent--disabled", text: "Previous"

    get problem_path(problem_b, contest_id: @contest.id)
    assert_response :success
    assert_select ".contest-nav__letter--active", text: "B"
    assert_select "a.contest-nav__adjacent[rel=prev][href=?]", problem_path(@problem, contest_id: @contest.id)
    assert_select ".contest-nav__adjacent--disabled", text: "Next"
    assert_select "input[type=submit]"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
