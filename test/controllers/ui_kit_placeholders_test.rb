require "test_helper"

class UiKitPlaceholdersTest < ActionDispatch::IntegrationTest
  setup do
    @problem = Problem.create!(
      title: "A + B",
      slug: "a-plus-b-test",
      statement: "Print the sum of two integers.",
      rating: 800,
      tags: [ "implementation" ],
      sample_input: "1 2",
      sample_output: "3"
    )
    @problem.test_cases.create!(
      position: 1,
      sample: true,
      stdin: "1 2\n",
      expected_output: "3\n"
    )
  end

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

  test "guest can browse problem and contest screens" do
    get problems_path
    assert_response :success
    assert_select ".problem-card", minimum: 1

    get problem_path(@problem)
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

  test "signed in user can open profile and submit" do
    user = User.create!(email: "placeholder@example.com", password: "password123")
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    get profile_path
    assert_response :success
    assert_select ".rating-block__value"

    get problem_path(@problem)
    assert_response :success
    assert_select "form"

    assert_enqueued_with(job: JudgeSubmissionJob) do
      post problem_submissions_path(@problem), params: {
        language: "python",
        source_code: "print(1)"
      }
    end
    assert_redirected_to %r{/submissions/\d+}
    follow_redirect!
    assert_response :success
    assert_select ".badge", text: /Queued|Judging/i
  end

  test "guest cannot create submission" do
    post problem_submissions_path(@problem), params: {
      language: "python",
      source_code: "print(1)"
    }
    assert_redirected_to new_user_session_path
  end
end
