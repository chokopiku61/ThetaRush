# frozen_string_literal: true

require "test_helper"

class JudgeSubmissionJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @problem = Problem.create!(
      title: "Job Recovery Sum",
      slug: "job-recovery-sum",
      statement: "Add two numbers.",
      rating: 800,
      tags: [ "math" ]
    )
    @problem.test_cases.create!(position: 1, stdin: "1 2\n", expected_output: "3\n")
  end

  test "resumes a judging submission with stored Judge0 tokens" do
    submission = @user.submissions.create!(
      problem: @problem,
      language: "python",
      source_code: "print(3)",
      status: "judging",
      judge0_token: [ "existing-token" ].to_json
    )
    client = Object.new
    client.define_singleton_method(:create_batch) { |_| raise "batch must not be duplicated" }
    client.define_singleton_method(:fetch_batch) do |tokens|
      raise "unexpected Judge0 tokens" unless tokens == [ "existing-token" ]

      [ { "status" => { "id" => 3, "description" => "Accepted" }, "stdout" => "3\n" } ]
    end

    with_client(client) do
      JudgeSubmissionJob.perform_now(submission.id)
    end

    assert_equal "ac", submission.reload.status
    assert_equal "3\n", submission.stdout
  end

  test "unexpected Judge0 errors leave a terminal internal error verdict" do
    submission = @user.submissions.create!(
      problem: @problem,
      language: "python",
      source_code: "print(3)",
      status: "queued"
    )
    client = Object.new
    client.define_singleton_method(:create_batch) { |_| raise Net::OpenTimeout, "Judge0 timed out" }

    with_client(client) do
      JudgeSubmissionJob.perform_now(submission.id)
    end

    assert_equal "ie", submission.reload.status
    assert_equal "Judge0 timed out", submission.stderr
  end

  test "polling exhaustion leaves a terminal internal error verdict" do
    submission = @user.submissions.create!(
      problem: @problem,
      language: "python",
      source_code: "print(3)",
      status: "queued"
    )
    client = Object.new
    client.define_singleton_method(:create_batch) { |_| [ "new-token" ] }
    job = JudgeSubmissionJob.new
    job.define_singleton_method(:poll_until_finished!) { |_submission| false }

    with_client(client) do
      job.perform(submission.id)
    end

    assert_equal "ie", submission.reload.status
    assert_match(/did not finish/, submission.stderr)
  end

  private

  def with_client(client)
    original = Judge0Client.method(:new)
    Judge0Client.define_singleton_method(:new) { |*| client }
    yield
  ensure
    Judge0Client.define_singleton_method(:new, original) if original
  end
end
