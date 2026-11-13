# frozen_string_literal: true

require "test_helper"

class ContestsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

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
    assert_select ".contest-card__meta", text: /1 · 0/

    get contest_path(@contest)

    assert_response :success
    assert_select "a[href='#{problem_path(@problem, contest_id: @contest.id)}']", text: @problem.title
  end

  test "signed-in user registers once" do
    sign_in_as(users(:one))

    assert_no_broadcasts("#{@contest.to_gid_param}:scoreboard") do
      assert_difference("ContestParticipation.count", 1) do
        post register_contest_path(@contest)
      end
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

  test "scoreboard stays public and only signed-in pages render a live subscription" do
    get scoreboard_contest_path(@contest)
    assert_response :success
    assert_select "turbo-cable-stream-source", count: 0
    assert_select "tbody#scoreboard_rows td[colspan='4']", text: I18n.t("contests.no_participants")
    assert_select "p.empty-state", count: 0

    sign_in_as(users(:one))
    get scoreboard_contest_path(@contest)
    assert_response :success
    assert_select "turbo-cable-stream-source[channel=?][data-contest-id=?]",
                  "ScoreboardChannel", @contest.id.to_s
    assert_select "turbo-frame#scoreboard turbo-cable-stream-source", count: 0
  end

  test "manual frame refresh recovers current standings for guests and signed-in viewers" do
    [ nil, users(:one) ].each do |viewer|
      sign_in_as(viewer) if viewer
      participation = ContestParticipation.find_or_create_by!(contest: @contest, user: users(:two))
      participation.update!(solved_count: 0, penalty: 0, rank: 1)
      get scoreboard_contest_path(@contest)
      assert_response :success
      assert_select "turbo-frame#scoreboard a[href=?][data-turbo-frame=scoreboard]",
                    scoreboard_contest_path(@contest), text: I18n.t("contests.refresh_scoreboard")
      assert_select "turbo-frame#scoreboard tbody tr td:nth-child(3)", text: "0"

      participation.update!(solved_count: 1, penalty: 32, rank: 1)

      get scoreboard_contest_path(@contest), headers: { "Turbo-Frame" => "scoreboard" }
      assert_response :success
      assert_select "turbo-frame#scoreboard tbody#scoreboard_rows tr" do
        assert_select "td:nth-child(2)", text: users(:two).username
        assert_select "td:nth-child(3)", text: "1"
        assert_select "td:nth-child(4)", text: "32"
      end
      assert_select "turbo-frame#scoreboard turbo-cable-stream-source", count: 0
    end
  end

  test "scoreboard explains automatic and manual updates in both locales" do
    %i[en ru].each do |locale|
      cookies[:locale] = locale.to_s
      get scoreboard_contest_path(@contest)
      assert_response :success
      assert_select "p.page-meta", text: I18n.t("contests.scoreboard_updates", locale: locale)
      assert_select "turbo-frame#scoreboard a", text: I18n.t("contests.refresh_scoreboard", locale: locale)
    end
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
