# frozen_string_literal: true

class ProblemsController < ApplicationController
  def index
    @problems = Problem.order(:id)
  end

  def show
    @problem = Problem.find(params[:id])
    @solved_count = @problem.submissions.where(status: "ac").select(:user_id).distinct.count
    @languages = [
      [ "Python 3", "python" ],
      [ "C++17", "cpp" ]
    ]
  rescue ActiveRecord::RecordNotFound
    redirect_to problems_path, alert: "Problem not found."
  end
end
