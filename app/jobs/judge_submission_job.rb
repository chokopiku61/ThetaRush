# frozen_string_literal: true

class JudgeSubmissionJob < ApplicationJob
  queue_as :default

  POLL_ATTEMPTS = 45
  POLL_INTERVAL = 1

  def perform(submission_id)
    submission = Submission.find_by(id: submission_id)
    return unless submission
    return unless %w[queued judging].include?(submission.status)

    submission.update!(status: "judging") if submission.status == "queued"

    client = Judge0Client.new
    if submission.judge0_token.blank?
      tokens = client.create_batch(submission)
      submission.update!(judge0_token: tokens.to_json)
    end

    # Webhook is preferred; poll as a local fallback when callbacks cannot reach Rails
    # (common with Docker Desktop networking).
    return if poll_until_finished!(submission)

    fail_submission(submission, "Judge0 did not finish within #{POLL_ATTEMPTS} polling attempts")
  rescue StandardError => e
    Rails.logger.error("[JudgeSubmissionJob] submission=#{submission_id} #{e.class}: #{e.message}")
    fail_submission(submission, e.message)
  end

  private

  def poll_until_finished!(submission)
    POLL_ATTEMPTS.times do
      submission.reload
      return true unless %w[queued judging].include?(submission.status)

      Submissions::ApplyJudge0Result.call(submission)
      submission.reload
      return true unless %w[queued judging].include?(submission.status)

      sleep POLL_INTERVAL
    end

    false
  end

  def fail_submission(submission, message)
    submission&.update!(status: "ie", stderr: message.to_s.truncate(2000))
  end
end
