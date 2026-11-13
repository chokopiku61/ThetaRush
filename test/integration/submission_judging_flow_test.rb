# frozen_string_literal: true

require "test_helper"

class SubmissionJudgingFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionCable::TestHelper

  parallelize(workers: 1)

  setup do
    @user = users(:one)
    @problem = Problem.create!(
      title: "Integration Sum", slug: "integration-sum", statement: "Add two integers.",
      rating: 800, tags: [ "math" ], time_limit_ms: 1000, memory_limit_mb: 256
    )
    @problem.test_cases.create!(position: 1, stdin: "1 2\n", expected_output: "3\n")
    @problem.test_cases.create!(position: 2, stdin: "4 5\n", expected_output: "9\n")
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    assert_response :redirect
  end

  { "python" => "print(sum(map(int, input().split())))",
    "cpp" => "#include <iostream>\nint main(){int a,b;std::cin>>a>>b;std::cout<<a+b;}" }.each do |language, source|
    test "practice #{language} submission reaches accepted through the judging job" do
      get problems_path
      assert_response :success
      assert_select "a[href=?]", problem_path(@problem), text: @problem.title
      get problem_path(@problem)
      assert_response :success
      assert_select "form[action=?]", problem_submissions_path(@problem)

      with_judge0_transport(status_id: 3) do |requests|
        submission = submit_solution(language, source)
        assert_nil submission.contest_id
        perform_enqueued_jobs(only: JudgeSubmissionJob)
        assert_equal "ac", submission.reload.status
        assert_equal 20, submission.time_ms
        assert_equal 2048, submission.memory_kb
        assert_equal "9\n", submission.stdout
        assert_batch_payload(requests, submission, language == "python" ? 71 : 54)

        get submission_path(submission)
        assert_response :success
        assert_select "pre", text: source
        assert_includes response.body, I18n.t("submissions.finished")
        assert_includes response.body, "9"
        get status_submission_path(submission)
        assert_response :success
        assert_includes response.body, "AC"
      end
    end
  end

  test "contest wrong answer then accepted callbacks update the refreshed scoreboard" do
    freeze_time do
      contest = Contest.create!(title: "Integration Cup", starts_at: 30.minutes.ago,
                                ends_at: 1.hour.from_now, status: "running")
      ContestProblem.create!(contest: contest, problem: @problem, position: 1, letter: "A")
      opponent = ContestParticipation.create!(contest: contest, user: users(:two))

      get problem_path(@problem, contest_id: contest.id)
      assert_response :success
      participation = ContestParticipation.find_by!(contest: contest, user: @user)

      with_judge0_transport(status_id: 4) do |requests|
        wrong = submit_solution("python", "print(0)", contest: contest)
        start_callback_job(wrong)
        deliver_callback(wrong)
        assert_equal "wa", wrong.reload.status
        assert_equal 0, participation.reload.solved_count
        assert_equal 0, participation.penalty
        assert_batch_payload(requests, wrong, 71)
      end

      travel 5.minutes
      with_judge0_transport(status_id: 3) do |requests|
        accepted = submit_solution("cpp", "int main(){}", contest: contest)
        start_callback_job(accepted)
        deliver_callback(accepted)
        assert_equal "ac", accepted.reload.status
        assert_equal 1, participation.reload.solved_count
        assert_equal 55, participation.penalty
        assert_equal 1, participation.rank
        assert_equal 2, opponent.reload.rank
        assert_batch_payload(requests, accepted, 54)

        deliver_callback(accepted)
        assert_equal 55, participation.reload.penalty
        get scoreboard_contest_path(contest)
        assert_response :success
        rows = css_select("tbody tr").map { |row| row.css("td").map { |cell| cell.text.strip } }
        assert_equal [ [ "1", @user.username, "1", "55" ],
                       [ "2", users(:two).username, "0", "0" ] ], rows
      end
    end
  end

  test "submission rejects unsupported languages and empty source" do
    [
      { language: "javascript", source_code: "console.log(1)" },
      { language: "python", source_code: " " }
    ].each do |attributes|
      assert_no_difference("Submission.count") do
        assert_no_enqueued_jobs(only: JudgeSubmissionJob) do
          post problem_submissions_path(@problem), params: attributes
        end
      end

      assert_redirected_to problem_path(@problem)
      follow_redirect!
      assert_response :success
      assert_match(/language|source/i, response.body)
    end
  end

  test "contest verdict from job polling broadcasts without a webhook" do
    contest = Contest.create!(title: "Polling Cup", starts_at: 30.minutes.ago,
                              ends_at: 1.hour.from_now, status: "running")
    ContestProblem.create!(contest: contest, problem: @problem, position: 1, letter: "A")
    ContestParticipation.create!(contest: contest, user: @user)

    with_judge0_transport(status_id: 3) do
      submission = submit_solution("python", "print(sum(map(int, input().split())))", contest: contest)
      messages = capture_broadcasts("#{contest.to_gid_param}:scoreboard") do
        perform_enqueued_jobs(only: JudgeSubmissionJob)
      end

      assert_equal "ac", submission.reload.status
      assert_equal 1, messages.size
      assert_includes messages.first, 'target="scoreboard_rows"'
      assert_includes messages.first, @user.username
    end
  end

  test "submission status is available only to its owner" do
    submission = @user.submissions.create!(
      problem: @problem,
      language: "python",
      source_code: "print(3)",
      status: "queued"
    )

    get status_submission_path(submission)
    assert_response :success
    assert_includes response.body, "Queued"

    delete destroy_user_session_path
    get status_submission_path(submission)
    assert_response :forbidden

    post user_session_path, params: {
      user: { email: users(:two).email, password: "password123" }
    }
    get status_submission_path(submission)
    assert_response :forbidden
  end

  test "upcoming contest does not accept submissions" do
    contest = Contest.create!(title: "Future Cup", starts_at: 1.hour.from_now,
                              ends_at: 2.hours.from_now, status: "upcoming")
    ContestProblem.create!(contest: contest, problem: @problem, position: 1, letter: "A")

    assert_no_difference("Submission.count") do
      assert_no_enqueued_jobs(only: JudgeSubmissionJob) do
        post problem_submissions_path(@problem), params: {
          contest_id: contest.id,
          language: "python",
          source_code: "print(3)"
        }
      end
    end

    assert_redirected_to contest_path(contest)
    assert_equal I18n.t("submissions.contest_closed"), flash[:alert]
  end

  private

  def submit_solution(language, source, contest: nil)
    assert_enqueued_with(job: JudgeSubmissionJob) do
      assert_difference("Submission.count", 1) do
        post problem_submissions_path(@problem), params: {
          language: language, source_code: source, contest_id: contest&.id
        }
      end
    end
    submission = @user.submissions.order(:id).last
    assert_redirected_to submission_path(submission)
    assert_equal "queued", submission.status
    if contest
      assert_equal contest.id, submission.contest_id
    else
      assert_nil submission.contest_id
    end
    submission
  end

  def start_callback_job(submission)
    # Leave polling idle to exercise the callback winning the race with the worker.
    job = JudgeSubmissionJob.new(submission.id)
    job.define_singleton_method(:poll_until_finished!) { |_submission| true }
    job.perform_now
    assert_equal "judging", submission.reload.status
    assert_equal [ "test-#{submission.id}-1", "test-#{submission.id}-2" ], JSON.parse(submission.judge0_token)
  end

  def deliver_callback(submission)
    assert_broadcasts("#{submission.contest.to_gid_param}:scoreboard", 1) do
      post judge0_webhook_path, params: { submission_id: submission.id }, as: :json,
           headers: { "X-Judge0-Secret" => ENV.fetch("JUDGE0_WEBHOOK_SECRET", "dev-judge0-webhook-secret") }
    end
    assert_response :ok
  end

  def assert_batch_payload(requests, submission, language_id)
    assert_equal 1, requests.size
    path, payload = requests.first
    assert_equal "/submissions/batch?base64_encoded=false", path
    assert_equal 2, payload[:submissions].size
    assert_equal [ "1 2\n", "4 5\n" ], payload[:submissions].map { |row| row[:stdin] }
    assert_equal [ "3\n", "9\n" ], payload[:submissions].map { |row| row[:expected_output] }
    payload[:submissions].each do |row|
      assert_equal submission.source_code, row[:source_code]
      assert_equal language_id, row[:language_id]
      assert_equal 1.0, row[:cpu_time_limit]
      assert_equal 2.0, row[:wall_time_limit]
      assert_equal 262144, row[:memory_limit]
      assert_equal true, row[:enable_per_process_and_thread_time_limit]
      assert_equal true, row[:enable_per_process_and_thread_memory_limit]
      assert_equal submission.id.to_s, Rack::Utils.parse_query(URI(row[:callback_url]).query)["submission_id"]
    end
  end

  def with_judge0_transport(status_id:)
    requests = []
    tokens = []
    client = Judge0Client.new
    client.define_singleton_method(:post_json) do |path, payload|
      requests << [ path, payload ]
      submission_id = URI.decode_www_form(URI(payload[:submissions].first[:callback_url]).query).to_h.fetch("submission_id")
      tokens.replace([ "test-#{submission_id}-1", "test-#{submission_id}-2" ])
      tokens.map { |token| { "token" => token } }
    end
    client.define_singleton_method(:get_json) do |path|
      query = URI.decode_www_form(URI(path).query).to_h
      raise "Unexpected judge tokens" unless query["tokens"] == tokens.join(",")

      { "submissions" => [ "3\n", "9\n" ].map do |stdout|
        { "status" => { "id" => status_id }, "stdout" => stdout, "time" => "0.02", "memory" => 2048 }
      end }
    end
    original = Judge0Client.method(:new)
    owner = Thread.current
    # Other test threads retain the real constructor while this flow uses its fake transport.
    Judge0Client.define_singleton_method(:new) do |*args, **kwargs|
      Thread.current == owner ? client : original.call(*args, **kwargs)
    end
    yield requests
  ensure
    Judge0Client.define_singleton_method(:new, original) if original
  end
end
