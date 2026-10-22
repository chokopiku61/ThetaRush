# frozen_string_literal: true

class ContestsController < ApplicationController
  before_action :authenticate_user!, only: %i[register finalize]
  before_action :require_admin!, only: :finalize
  before_action :set_contest, only: %i[show scoreboard register finalize]

  def index
    @tab = params[:tab].presence_in(%w[upcoming running finished]) || default_tab
    scope = Contest
      .left_joins(:contest_problems, :contest_participations)
      .select(
        "contests.*",
        "COUNT(DISTINCT contest_problems.id) AS problem_count",
        "COUNT(DISTINCT contest_participations.id) AS registered_count"
      )
      .group("contests.id")
      .order(starts_at: :desc)

    @contests =
      case @tab
      when "upcoming" then scope.where(status: "upcoming")
      when "running" then scope.where(status: "running")
      else scope.where(status: %w[finished finalized])
      end

    @favorite_map = user_signed_in? ? current_user.favorites.where(favoritable_type: "Contest").index_by(&:favoritable_id) : {}
  end

  def show
    @contest_problems = @contest.contest_problems.includes(:problem)
    @participation = current_user&.contest_participations&.find_by(contest: @contest)
    @favorite = user_signed_in? ? current_user.favorites.find_by(favoritable: @contest) : nil
  end

  def scoreboard
    @rows = @contest.contest_participations
      .includes(:user)
      .order(:rank, :registered_at, :id)
  end

  def register
    unless %w[upcoming running].include?(@contest.status)
      redirect_to contest_path(@contest), alert: t("contests.registration_closed")
      return
    end

    participation = current_user.contest_participations.find_or_create_by!(contest: @contest)
    Contests::Scoring.recompute_contest!(@contest) if participation.previously_new_record?

    message = participation.previously_new_record? ? t("contests.registered", title: @contest.title) : t("contests.already_registered")
    redirect_to contest_path(@contest), notice: message
  end

  def finalize
    FinalizeContestJob.perform_now(@contest.id)
    redirect_to contest_path(@contest), notice: t("contests.finalized")
  rescue ArgumentError => error
    redirect_to contest_path(@contest), alert: error.message
  end

  private

  def default_tab
    return "running" if Contest.exists?(status: "running")
    return "upcoming" if Contest.exists?(status: "upcoming")

    "finished"
  end

  def require_admin!
    head :forbidden unless current_user.admin?
  end

  def set_contest
    @contest = Contest.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to contests_path, alert: t("contests.not_found")
  end
end
