# frozen_string_literal: true

module Submissions
  # Re-fetches Judge0 batch tokens and updates the submission when all tests finish.
  class ApplyJudge0Result
    def self.call(submission)
      new(submission).call
    end

    def initialize(submission)
      @submission = submission
    end

    def call
      tokens = parse_tokens(@submission.judge0_token)
      return @submission if tokens.empty?

      results = Judge0Client.new.fetch_batch(tokens)
      # Judge0 may return a bare array or { "submissions" => [...] }.
      rows = results.is_a?(Hash) ? Array(results["submissions"]) : Array(results)
      aggregate = Judge0Client.aggregate_results(rows.compact)

      attrs = {
        status: aggregate[:status],
        stdout: aggregate[:stdout],
        stderr: aggregate[:stderr],
        compile_output: aggregate[:compile_output],
        time_ms: aggregate[:time_ms],
        memory_kb: aggregate[:memory_kb]
      }

      # Do not overwrite a finished verdict with judging from a late callback race.
      if aggregate[:status] == "judging" && Submission::STATUSES.include?(@submission.status) &&
         !%w[queued judging].include?(@submission.status)
        return @submission
      end

      @submission.update!(attrs.compact)
      @submission
    end

    private

    def parse_tokens(raw)
      return [] if raw.blank?

      parsed = JSON.parse(raw)
      Array(parsed).map(&:to_s)
    rescue JSON::ParserError
      raw.to_s.split(",").map(&:strip).reject(&:blank?)
    end
  end
end
