# frozen_string_literal: true

require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  test "guest is redirected and non-admin is forbidden" do
    get admin_root_path
    assert_redirected_to new_user_session_path

    sign_in_as(users(:one))
    get admin_root_path
    assert_response :forbidden
  end

  test "admin can create a problem" do
    users(:one).update!(admin: true)
    sign_in_as(users(:one))

    assert_difference("Problem.count", 1) do
      post admin_problems_path, params: {
        problem: {
          title: "Admin Problem",
          slug: "admin-problem",
          statement: "Created through Administrate.",
          rating: 1300,
          tags: "math, implementation",
          time_limit_ms: 1000,
          memory_limit_mb: 256
        }
      }
    end

    problem = Problem.find_by!(slug: "admin-problem")
    assert_equal [ "math", "implementation" ], problem.tags
    assert_redirected_to admin_problem_path(problem)
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
