# frozen_string_literal: true

class JudgeSubmissionJob < ApplicationJob
  queue_as :default

  POLL_ATTEMPTS = 45
  POLL_INTERVAL = 1

  def perform(submission_id)
    submission = Submission.find_by(id: submission_id)
    return unless submission
    return unless submission.status == "queued"

    submission.update!(status: "judging")

    client = Judge0Client.new
    tokens = client.create_batch(submission)
    submission.update!(judge0_token: tokens.to_json)

    # Webhook is preferred; poll as a local fallback when callbacks cannot reach Rails
    # (common with Docker Desktop networking).
    poll_until_finished!(submission)
  rescue Judge0Client::Error => e
    Rails.logger.error("[JudgeSubmissionJob] submission=#{submission_id} #{e.class}: #{e.message}")
    submission&.update!(status: "ie", stderr: e.message.to_s.truncate(2000))
  end

  private

  def poll_until_finished!(submission)
    POLL_ATTEMPTS.times do
      submission.reload
      return unless %w[queued judging].include?(submission.status)

      Submissions::ApplyJudge0Result.call(submission)
      submission.reload
      return unless %w[queued judging].include?(submission.status)

      sleep POLL_INTERVAL
    end
  end
end
