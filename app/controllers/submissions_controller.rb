# frozen_string_literal: true

class SubmissionsController < ApplicationController
  before_action :authenticate_user!, only: :create

  def create
    problem = Problem.find(params[:problem_id])
    contest = contest_for_submission(problem)
    return if performed?

    submission = current_user.submissions.build(
      problem: problem,
      contest: contest,
      language: params[:language].to_s,
      source_code: params[:source_code].to_s,
      status: "queued"
    )

    if submission.save
      JudgeSubmissionJob.perform_later(submission.id)
      redirect_to submission_path(submission), notice: "Submission queued for judging."
    else
      redirect_to problem_path(problem, contest_id: contest&.id),
                  alert: submission.errors.full_messages.to_sentence.presence || "Could not create submission."
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

  private

  def contest_for_submission(problem)
    return nil if params[:contest_id].blank?

    contest = Contest.find(params[:contest_id])
    unless contest.contest_problems.exists?(problem_id: problem.id)
      redirect_to contest_path(contest), alert: "This problem is not part of the contest."
      return
    end

    unless current_user.contest_participations.exists?(contest: contest)
      redirect_to contest_path(contest), alert: "Register for the contest before submitting."
      return
    end

    unless contest.status == "running" && Time.current.between?(contest.starts_at, contest.ends_at)
      redirect_to contest_path(contest), alert: "Contest submissions are closed."
      return
    end

    contest
  end
end
