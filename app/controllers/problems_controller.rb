# frozen_string_literal: true

class ProblemsController < ApplicationController
  def index
    @problems = Problem.order(:id)
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
  rescue ActiveRecord::RecordNotFound
    redirect_to problems_path, alert: "Problem not found."
  end

  private

  def load_contest_context
    return if params[:contest_id].blank?

    @contest = Contest
      .joins(:contest_problems)
      .find_by(id: params[:contest_id], contest_problems: { problem_id: @problem.id })

    unless @contest
      redirect_to problem_path(@problem), alert: "This problem is not part of that contest."
      return
    end

    @contest_participation = current_user&.contest_participations&.find_by(contest: @contest)
    @contest_accepting_submissions =
      @contest.status == "running" && Time.current.between?(@contest.starts_at, @contest.ends_at)
  end
end
