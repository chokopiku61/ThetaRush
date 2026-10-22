# frozen_string_literal: true

class SubmissionsController < ApplicationController
  before_action :authenticate_user!, only: :create

  def index
    unless user_signed_in?
      @guest = true
      return
    end

    @submissions = current_user.submissions.includes(:problem).order(submitted_at: :desc)
    @submissions = @submissions.where(status: params[:verdict]) if params[:verdict].present?
    @submissions = @submissions.where(language: params[:language]) if params[:language].present?
    @submissions = @submissions.where(problem_id: params[:problem_id]) if params[:problem_id].present?
    @problems = Problem.where(id: current_user.submissions.select(:problem_id).distinct).order(:title)
  end


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
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "submission-status",
            partial: "submissions/workspace_panel",
            locals: { submissions: recent_submissions_for(problem, contest) }
          )
        end
        format.html { redirect_to submission_path(submission), notice: t("submissions.queued") }
      end
    else
      redirect_to problem_path(problem, contest_id: contest&.id),
                  alert: submission.errors.full_messages.to_sentence.presence || t("submissions.create_failed")
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to problems_path, alert: t("problems.not_found")
  end

  def show
    @submission = Submission.find(params[:id])
    @problem = @submission.problem
  rescue ActiveRecord::RecordNotFound
    redirect_to problems_path, alert: t("submissions.not_found")
  end

  def status
    @submission = Submission.find(params[:id])
    unless user_signed_in? && @submission.user_id == current_user.id
      head :forbidden
      return
    end

    render partial: "submissions/workspace_panel",
           locals: { submissions: recent_submissions_for(@submission.problem, @submission.contest) },
           layout: false
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def recent_submissions_for(problem, contest)
    scope = current_user.submissions.where(problem: problem)
    scope = contest ? scope.where(contest_id: contest.id) : scope.where(contest_id: nil)
    scope.order(submitted_at: :desc, id: :desc).to_a
  end

  def contest_for_submission(problem)
    return nil if params[:contest_id].blank?

    contest = Contest.find(params[:contest_id])
    unless contest.contest_problems.exists?(problem_id: problem.id)
      redirect_to contest_path(contest), alert: t("submissions.problem_not_in_contest")
      return
    end

    unless current_user.contest_participations.exists?(contest: contest)
      unless %w[upcoming running].include?(contest.status)
        redirect_to contest_path(contest), alert: t("submissions.register_first")
        return
      end

      current_user.contest_participations.find_or_create_by!(contest: contest)
    end

    unless contest.status == "running" && Time.current.between?(contest.starts_at, contest.ends_at)
      redirect_to contest_path(contest), alert: t("submissions.contest_closed")
      return
    end

    contest
  end
end
