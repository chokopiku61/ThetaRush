# frozen_string_literal: true

class LocalesController < ApplicationController
  ALLOWED = %w[en ru].freeze

  def update
    locale = params[:locale].to_s
    if ALLOWED.include?(locale)
      cookies.permanent[:locale] = locale
      session[:locale] = locale
    end

    redirect_back fallback_location: root_path
  end
end
