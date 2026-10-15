class SubmissionsController < ApplicationController
  include PlaceholderData

  before_action :authenticate_user!, only: :create

  def create
    problem = find_placeholder_problem(params[:problem_id])
    unless problem
      redirect_to problems_path, alert: "Problem not found."
      return
    end

    # M3 placeholder: no judging backend yet.
    flash[:notice] = "Submission received (placeholder). Judging is not implemented yet."
    redirect_to submission_path(1, problem_id: problem.id)
  end

  def show
    @submission = placeholder_submission(params[:id])
    @problem = find_placeholder_problem(params[:problem_id].presence || @submission.problem_id)
  end
end
