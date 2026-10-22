# frozen_string_literal: true

require "test_helper"

class ContestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contest = Contest.create!(
      title: "Controller Cup",
      description: "A contest controller test.",
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      status: "running"
    )
    @problem = Problem.create!(
      title: "Contest Sum",
      slug: "contest-sum",
      statement: "Add two numbers.",
      rating: 1000,
      tags: [ "math" ]
    )
    ContestProblem.create!(contest: @contest, problem: @problem, position: 1, letter: "A")
  end

  test "index and show render database contests and contest problem links" do
    get contests_path

    assert_response :success
    assert_select ".contest-card__title", text: @contest.title
    assert_select ".contest-card__meta", text: /1 problem/

    get contest_path(@contest)

    assert_response :success
    assert_select "a[href='#{problem_path(@problem, contest_id: @contest.id)}']", text: @problem.title
  end

  test "signed-in user registers once" do
    sign_in_as(users(:one))

    assert_difference("ContestParticipation.count", 1) do
      post register_contest_path(@contest)
    end
    assert_redirected_to contest_path(@contest)

    assert_no_difference("ContestParticipation.count") do
      post register_contest_path(@contest)
    end

    delete destroy_user_session_path
    sign_in_as(users(:two))

    assert_difference("ContestParticipation.count", 1) do
      post register_contest_path(@contest)
    end
  end

  test "scoreboard renders participants in rank order" do
    ContestParticipation.create!(user: users(:one), contest: @contest)
    ContestParticipation.create!(user: users(:two), contest: @contest)
    Submission.create!(
      user: users(:two),
      problem: @problem,
      contest: @contest,
      language: "python",
      source_code: "print(1)",
      status: "ac",
      submitted_at: @contest.starts_at + 12.minutes
    )
    Contests::Scoring.recompute_contest!(@contest)

    get scoreboard_contest_path(@contest)

    assert_response :success
    assert_select "tbody tr", count: 2
    assert_select "tbody tr:first-child td:nth-child(2)", text: users(:two).username
    assert_select "tbody tr:first-child td:nth-child(3)", text: "1"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
