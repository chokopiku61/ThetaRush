# frozen_string_literal: true

# Receives Judge0 CE callbacks when a batch submission finishes a test case.
# Authenticity: shared secret via query param or X-Judge0-Secret header (local-dev grade).
class Judge0WebhookController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_webhook!

  def create
    submission = Submission.find_by(id: params[:submission_id])
    unless submission
      head :not_found
      return
    end

    Submissions::ApplyJudge0Result.call(submission)
    head :ok
  end

  private

  def authenticate_webhook!
    expected = ENV.fetch("JUDGE0_WEBHOOK_SECRET", "dev-judge0-webhook-secret")
    provided = params[:secret].presence || request.headers["X-Judge0-Secret"].presence

    if provided.present? &&
       ActiveSupport::SecurityUtils.secure_compare(
         Digest::SHA256.hexdigest(provided),
         Digest::SHA256.hexdigest(expected)
       )
      return
    end

    head :unauthorized
  end
end

