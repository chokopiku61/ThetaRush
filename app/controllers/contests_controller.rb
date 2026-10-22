class ContestsController < ApplicationController
  before_action :authenticate_user!, only: %i[register finalize]
  before_action :require_admin!, only: :finalize
  before_action :set_contest, only: %i[show scoreboard register finalize]

  def index
    @contests = Contest
      .left_joins(:contest_problems, :contest_participations)
      .select(
        "contests.*",
        "COUNT(DISTINCT contest_problems.id) AS problem_count",
        "COUNT(DISTINCT contest_participations.id) AS registered_count"
      )
      .group("contests.id")
      .order(starts_at: :desc)
  end

  def show
    @contest_problems = @contest.contest_problems.includes(:problem)
    @participation = current_user&.contest_participations&.find_by(contest: @contest)
  end

  def scoreboard
    @rows = @contest.contest_participations
      .includes(:user)
      .order(:rank, :registered_at, :id)
  end

  def register
    unless %w[upcoming running].include?(@contest.status)
      redirect_to contest_path(@contest), alert: "Registration is closed for this contest."
      return
    end

    participation = current_user.contest_participations.find_or_create_by!(contest: @contest)
    Contests::Scoring.recompute_contest!(@contest) if participation.previously_new_record?

    message = participation.previously_new_record? ? "Registered for #{@contest.title}." : "You are already registered."
    redirect_to contest_path(@contest), notice: message
  end

  def finalize
    FinalizeContestJob.perform_now(@contest.id)
    redirect_to contest_path(@contest), notice: "Contest finalized and ratings updated."
  rescue ArgumentError => error
    redirect_to contest_path(@contest), alert: error.message
  end

  private

  def require_admin!
    head :forbidden unless current_user.admin?
  end

  def set_contest
    @contest = Contest.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to contests_path, alert: "Contest not found."
  end
end
