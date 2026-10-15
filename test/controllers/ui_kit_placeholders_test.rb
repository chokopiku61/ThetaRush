require "test_helper"

class UiKitPlaceholdersTest < ActionDispatch::IntegrationTest
  test "ui kit page renders core sections" do
    get ui_kit_path
    assert_response :success
    assert_select "h1", text: "UI kit"
    assert_select "#buttons"
    assert_select "#forms"
    assert_select "#badges"
    assert_select "#tables"
    assert_select ".badge--ac"
    assert_select ".textarea--code"
  end

  test "guest can browse placeholder problem and contest screens" do
    get problems_path
    assert_response :success
    assert_select ".problem-card", minimum: 1

    get problem_path(1)
    assert_response :success
    assert_select "#submit"
    assert_select "a", text: /Sign in/

    get contests_path
    assert_response :success
    assert_select ".contest-card", minimum: 1

    get contest_path(1)
    assert_response :success
    assert_select "a", text: /Scoreboard/

    get scoreboard_contest_path(1)
    assert_response :success
    assert_select ".table"
  end

  test "signed in user can open profile and placeholder submit" do
    user = User.create!(email: "placeholder@example.com", password: "password123")
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    get profile_path
    assert_response :success
    assert_select ".rating-block__value"

    get problem_path(1)
    assert_response :success
    assert_select "form"

    post problem_submissions_path(1), params: { language: "python", source: "print(1)" }
    assert_redirected_to %r{/submissions/}
    follow_redirect!
    assert_response :success
    assert_match(/placeholder|not implemented/i, flash[:notice].to_s + response.body)
  end
end
