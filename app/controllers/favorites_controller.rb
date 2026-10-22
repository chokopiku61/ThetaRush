# frozen_string_literal: true

class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def index
    @tab = params[:tab].presence_in(%w[problems contests]) || "problems"
    @favorite_problems = current_user.favorite_problems.order(:id)
    @favorite_contests = current_user.favorite_contests.order(starts_at: :desc)
  end

  def create
    record = find_favoritable
    return unless record

    current_user.favorites.find_or_create_by!(favoritable: record)
    redirect_back fallback_location: favorites_path, notice: t("favorites.added")
  end

  def destroy
    favorite = current_user.favorites.find_by(id: params[:id])
    favorite&.destroy
    redirect_back fallback_location: favorites_path, notice: t("favorites.removed")
  end

  private

  def find_favoritable
    type = params[:favoritable_type].to_s
    id = params[:favoritable_id]

    case type
    when "Problem"
      Problem.find(id)
    when "Contest"
      Contest.find(id)
    else
      redirect_back fallback_location: favorites_path, alert: t("favorites.invalid")
      nil
    end
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: favorites_path, alert: t("favorites.not_found")
    nil
  end
end
