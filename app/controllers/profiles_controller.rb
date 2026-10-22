class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @rating_histories = current_user.rating_histories.includes(:contest).order(created_at: :desc).limit(10)
    @recent_submissions = current_user.submissions.includes(:problem).order(submitted_at: :desc).limit(10)
    @contests_played = current_user.contest_participations.count
    @problems_solved = current_user.submissions.where(status: "ac").distinct.count(:problem_id)
  end
end
