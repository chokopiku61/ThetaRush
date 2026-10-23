# frozen_string_literal: true

require "cgi"
require "net/http"
require "json"
require "uri"

# HTTP client for Judge0 CE: batch create and fetch by tokens.
class Judge0Client
  class Error < StandardError; end
  class UnsupportedLanguage < Error; end

  # Judge0 CE language ids (community edition defaults).
  LANGUAGE_IDS = {
    "python" => 71, # Python 3.8.1
    "cpp" => 54     # C++ (GCC 9.2.0) C++17
  }.freeze

  # Judge0 status_id -> ThetaRush submission status
  STATUS_MAP = {
    3 => "ac",
    4 => "wa",
    5 => "tle",
    6 => "ce",
    7 => "re",
    8 => "re",
    9 => "re",
    10 => "re",
    11 => "re",
    12 => "re",
    13 => "ie",
    14 => "re"
  }.freeze

  PENDING_STATUS_IDS = [ 1, 2 ].freeze # In Queue, Processing

  def initialize(base_url: ENV.fetch("JUDGE0_URL", "http://localhost:2358"))
    @base_url = base_url.to_s.sub(%r{/\z}, "")
  end

  def language_id_for!(language)
    LANGUAGE_IDS.fetch(language) do
      raise UnsupportedLanguage, "unsupported language: #{language}"
    end
  end

  # Single interactive run (IDE / sample play). No expected_output, no webhook.
  # Uses wait=true so the HTTP response includes the finished result.
  def create_run(language:, source_code:, stdin:, time_limit_ms:, memory_limit_mb:)
    language_id = language_id_for!(language)
    cpu_seconds = [ time_limit_ms.to_f / 1000.0, 0.1 ].max
    memory_kb = memory_limit_mb.to_i * 1024

    payload = {
      source_code: source_code.to_s,
      language_id: language_id,
      stdin: stdin.to_s,
      cpu_time_limit: cpu_seconds,
      wall_time_limit: cpu_seconds + 1,
      memory_limit: memory_kb,
      enable_per_process_and_thread_time_limit: true,
      enable_per_process_and_thread_memory_limit: true
    }

    body = post_json("/submissions?base64_encoded=false&wait=true", payload)
    status_id = body.is_a?(Hash) ? (body.dig("status", "id") || body["status_id"]) : nil
    description = body.is_a?(Hash) ? body.dig("status", "description") : nil

    {
      status: self.class.map_status_id(status_id, status_description: description),
      stdout: body.is_a?(Hash) ? body["stdout"] : nil,
      stderr: body.is_a?(Hash) ? body["stderr"] : nil,
      compile_output: body.is_a?(Hash) ? body["compile_output"] : nil,
      time_ms: body.is_a?(Hash) && body["time"].present? ? (body["time"].to_f * 1000).round : nil,
      memory_kb: body.is_a?(Hash) ? body["memory"].presence&.to_i : nil
    }
  end

  # Creates one Judge0 submission per test case. Returns an array of tokens.
  def create_batch(submission)
    problem = submission.problem
    language_id = language_id_for!(submission.language)
    callback_url = webhook_callback_url(submission.id)
    cpu_seconds = [ problem.time_limit_ms.to_f / 1000.0, 0.1 ].max
    memory_kb = problem.memory_limit_mb * 1024

    payloads = problem.test_cases.map do |tc|
      {
        source_code: submission.source_code,
        language_id: language_id,
        stdin: tc.stdin_content.to_s,
        expected_output: tc.expected_output_content.to_s,
        cpu_time_limit: cpu_seconds,
        wall_time_limit: cpu_seconds + 1,
        memory_limit: memory_kb,
        # Avoid isolate --cg (broken on Docker Desktop cgroup v2); keep isolate + setrlimit.
        enable_per_process_and_thread_time_limit: true,
        enable_per_process_and_thread_memory_limit: true,
        callback_url: callback_url
      }
    end

    raise Error, "problem has no test cases" if payloads.empty?

    body = post_json("/submissions/batch?base64_encoded=false", { submissions: payloads })
    tokens = Array(body).map { |row| row.is_a?(Hash) ? row["token"] : nil }.compact
    raise Error, "Judge0 batch returned no tokens: #{body.inspect}" if tokens.empty?

    tokens
  end

  def fetch_batch(tokens)
    return [] if tokens.blank?

    query = URI.encode_www_form(
      tokens: tokens.join(","),
      base64_encoded: "false",
      fields: "token,status_id,status,stdout,stderr,compile_output,time,memory,message"
    )
    get_json("/submissions/batch?#{query}")
  end

  def self.map_status_id(status_id, status_description: nil)
    desc = status_description.to_s.downcase
    return "mle" if desc.include?("memory limit")

    STATUS_MAP.fetch(status_id.to_i, "ie")
  end

  def self.pending?(status_id)
    PENDING_STATUS_IDS.include?(status_id.to_i)
  end

  # Aggregate many Judge0 results into one app status (first non-AC wins).
  def self.aggregate_results(results)
    results = Array(results)
    return { status: "ie", stdout: nil, stderr: "empty judge results", time_ms: nil, memory_kb: nil, compile_output: nil } if results.empty?

    if results.any? { |r| pending?(r.dig("status", "id") || r["status_id"]) }
      return { status: "judging", stdout: nil, stderr: nil, time_ms: nil, memory_kb: nil, compile_output: nil }
    end

    mapped = results.map do |r|
      status_id = r.dig("status", "id") || r["status_id"]
      description = r.dig("status", "description")
      {
        status: map_status_id(status_id, status_description: description),
        stdout: r["stdout"],
        stderr: r["stderr"],
        compile_output: r["compile_output"],
        time_ms: (r["time"].to_f * 1000).round,
        memory_kb: r["memory"].presence&.to_i
      }
    end

    failed = mapped.find { |m| m[:status] != "ac" }
    chosen = failed || mapped.last
    max_time = mapped.map { |m| m[:time_ms] }.compact.max
    max_mem = mapped.map { |m| m[:memory_kb] }.compact.max

    chosen.merge(time_ms: max_time, memory_kb: max_mem)
  end

  private

  def webhook_callback_url(submission_id)
    base = ENV.fetch("JUDGE0_CALLBACK_BASE_URL", "http://host.docker.internal:3000")
    secret = ENV.fetch("JUDGE0_WEBHOOK_SECRET", "dev-judge0-webhook-secret")
    "#{base.sub(%r{/\z}, "")}/judge0/webhook?submission_id=#{submission_id}&secret=#{CGI.escape(secret)}"
  end

  def get_json(path)
    uri = URI("#{@base_url}#{path}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 30) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    parse_response!(response)
  end

  def post_json(path, payload)
    uri = URI("#{@base_url}#{path}")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request.body = JSON.generate(payload)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 60) do |http|
      http.request(request)
    end
    parse_response!(response)
  end

  def parse_response!(response)
    body = response.body.to_s
    parsed = body.present? ? JSON.parse(body) : nil
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Judge0 HTTP #{response.code}: #{body.truncate(500)}"
    end

    parsed
  rescue JSON::ParserError => e
    raise Error, "Judge0 invalid JSON: #{e.message}"
  end
end
