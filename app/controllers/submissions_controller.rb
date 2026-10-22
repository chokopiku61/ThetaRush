# frozen_string_literal: true

class SubmissionsController < ApplicationController
  before_action :authenticate_user!, only: :create

  def create
    problem = Problem.find(params[:problem_id])
    submission = current_user.submissions.build(
      problem: problem,
      language: params[:language].to_s,
      source_code: params[:source_code].to_s,
      status: "queued"
    )

    if submission.save
      JudgeSubmissionJob.perform_later(submission.id)
      redirect_to submission_path(submission), notice: "Submission queued for judging."
    else
      redirect_to problem_path(problem), alert: submission.errors.full_messages.to_sentence.presence || "Could not create submission."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to problems_path, alert: "Problem not found."
  end

  def show
    @submission = Submission.find(params[:id])
    @problem = @submission.problem
  rescue ActiveRecord::RecordNotFound
    redirect_to problems_path, alert: "Submission not found."
  end
end
