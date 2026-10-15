class ProblemsController < ApplicationController
  include PlaceholderData

  def index
    @problems = placeholder_problems
  end

  def show
    @problem = find_placeholder_problem(params[:id])
    return redirect_to problems_path, alert: "Problem not found." unless @problem

    @languages = [
      ["Python 3", "python"],
      ["C++17", "cpp"]
    ]
  end
end
