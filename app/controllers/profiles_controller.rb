class ProfilesController < ApplicationController
  include PlaceholderData

  before_action :authenticate_user!

  def show
    @profile = placeholder_profile(current_user)
  end
end
