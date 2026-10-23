# frozen_string_literal: true

require "test_helper"

class CustomRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @problem = Problem.create!(
      title: "Custom Run Sum",
      slug: "custom-run-sum",
      statement: "Add two numbers.",
      rating: 800,
      tags: [ "math" ],
      time_limit_ms: 1000,
      memory_limit_mb: 256
    )
  end

  teardown do
    CustomRunsController.stub_client = nil
  end

  test "guest cannot custom run" do
    post problem_custom_runs_path(@problem), params: {
      language: "python",
      source_code: "print(1)",
      stdin: ""
    }, as: :json

    assert_includes [ 401, 302 ], response.status
  end

  test "signed-in user gets judge0 result as json" do
    sign_in_as(users(:one))

    stub = Object.new
    stub.define_singleton_method(:create_run) do |**|
      {
        status: "ac",
        stdout: "3\n",
        stderr: nil,
        compile_output: nil,
        time_ms: 12,
        memory_kb: 2048
      }
    end
    CustomRunsController.stub_client = stub

    post problem_custom_runs_path(@problem), params: {
      language: "python",
      source_code: "print(sum(map(int, input().split())))",
      stdin: "1 2"
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "ac", body["status"]
    assert_equal "3\n", body["stdout"]
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
