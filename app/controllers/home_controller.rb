# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @problems_count = Problem.count
    @contests_count = Contest.where(status: %w[upcoming running]).count
    @users_count = User.count
  end
end
