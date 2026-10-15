class ContestsController < ApplicationController
  include PlaceholderData

  before_action :authenticate_user!, only: :register

  def index
    @contests = placeholder_contests
  end

  def show
    @contest = find_placeholder_contest(params[:id])
    return redirect_to contests_path, alert: "Contest not found." unless @contest

    @contest_problems = placeholder_contest_problems(@contest)
  end

  def scoreboard
    @contest = find_placeholder_contest(params[:id])
    return redirect_to contests_path, alert: "Contest not found." unless @contest

    @rows = placeholder_scoreboard_rows
    @letters = @rows.first&.cells&.map(&:letter) || %w[A B C]
  end

  def register
    contest = find_placeholder_contest(params[:id])
    unless contest
      redirect_to contests_path, alert: "Contest not found."
      return
    end

    flash[:notice] = "Registered for #{contest.title} (placeholder). Real registration comes later."
    redirect_to contest_path(contest.id)
  end
end
