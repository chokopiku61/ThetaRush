# frozen_string_literal: true

class PinnedContestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contest

  def create
    current_user.update!(pinned_contest: @contest)
    respond_to_pin_change(notice: t("contests.pin.pinned"))
  end

  def destroy
    if current_user.pinned_contest_id == @contest.id
      current_user.update!(pinned_contest: nil)
    end
    respond_to_pin_change(notice: t("contests.pin.unpinned"))
  end

  private

  def set_contest
    @contest = Contest.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to contests_path, alert: t("contests.not_found")
  end

  def respond_to_pin_change(notice:)
    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_back fallback_location: contest_path(@contest),
                      notice: notice,
                      status: :see_other
      end
    end
  end
end
