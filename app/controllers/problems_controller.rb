# frozen_string_literal: true

class ProblemsController < ApplicationController
  def index
    @problems = Problem.order(:id)
    @problems = @problems.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    if params[:rating_min].present?
      @problems = @problems.where("rating >= ?", params[:rating_min].to_i)
    end
    if params[:rating_max].present?
      @problems = @problems.where("rating <= ?", params[:rating_max].to_i)
    end
    if params[:tag].present?
      @problems = @problems.where("? = ANY(tags)", params[:tag])
    end

    solved_counts = Submission.where(status: "ac").group(:problem_id).distinct.count(:user_id)
    @solved_counts = solved_counts
    @all_tags = Problem.reorder(nil).pluck(:tags).flatten.uniq.sort
    @favorite_ids = user_signed_in? ? current_user.favorites.where(favoritable_type: "Problem").pluck(:favoritable_id) : []
    @favorite_map = user_signed_in? ? current_user.favorites.where(favoritable_type: "Problem").index_by(&:favoritable_id) : {}
  end

  def show
    @problem = Problem.find(params[:id])
    load_contest_context
    return if performed?

    @solved_count = @problem.submissions.where(status: "ac").select(:user_id).distinct.count
    @languages = [
      [ "Python 3", "python" ],
      [ "C++17", "cpp" ]
    ]
    @favorite = user_signed_in? ? current_user.favorites.find_by(favoritable: @problem) : nil
    @recent_submissions = recent_submissions_for(@problem, @contest)
  rescue ActiveRecord::RecordNotFound
    redirect_to problems_path, alert: t("problems.not_found")
  end

  private

  def load_contest_context
    return if params[:contest_id].blank?

    @contest = Contest
      .joins(:contest_problems)
      .find_by(id: params[:contest_id], contest_problems: { problem_id: @problem.id })

    unless @contest
      redirect_to problem_path(@problem), alert: t("problems.not_in_contest")
      return
    end

    @contest_problems = @contest.contest_problems.includes(:problem)
    @contest_problem = @contest_problems.find { |entry| entry.problem_id == @problem.id }
    index = @contest_problems.index(@contest_problem)
    @previous_contest_problem = index&.positive? ? @contest_problems[index - 1] : nil
    @next_contest_problem = index ? @contest_problems[index + 1] : nil

    if user_signed_in? && %w[upcoming running].include?(@contest.status)
      @contest_participation = current_user.contest_participations.find_or_create_by!(contest: @contest)
    else
      @contest_participation = current_user&.contest_participations&.find_by(contest: @contest)
    end

    @contest_accepting_submissions =
      @contest.status == "running" && Time.current.between?(@contest.starts_at, @contest.ends_at)
  end

  def recent_submissions_for(problem, contest)
    return [] unless user_signed_in?

    scope = current_user.submissions.where(problem: problem)
    scope = contest ? scope.where(contest_id: contest.id) : scope.where(contest_id: nil)
    scope.order(submitted_at: :desc, id: :desc).to_a
  end
end
