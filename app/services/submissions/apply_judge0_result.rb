# frozen_string_literal: true

module Submissions
  # Re-fetches Judge0 batch tokens and updates the submission when all tests finish.
  class ApplyJudge0Result
    def self.call(submission, client: Judge0Client.new)
      new(submission, client: client).call
    end

    def initialize(submission, client:)
      @submission = submission
      @client = client
    end

    def call
      tokens = parse_tokens(@submission.judge0_token)
      return @submission if tokens.empty?

      results = @client.fetch_batch(tokens)
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

      Submission.transaction do |transaction|
        contest = @submission.contest
        contest&.lock!
        @submission.lock!

        # Reload under the locks before checking a late callback's pending result.
        next if aggregate[:status] == "judging" && terminal_status?(@submission.status)

        @submission.update!(attrs.compact)
        if contest && terminal_status?(@submission.status) && Contests::Scoring.apply!(@submission)
          transaction.after_commit { Contests::ScoreboardBroadcaster.call(contest) }
        end
      end
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

    def terminal_status?(status)
      Submission::STATUSES.include?(status) && !%w[queued judging].include?(status)
    end
  end
end
