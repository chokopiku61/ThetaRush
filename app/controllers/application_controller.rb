class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  around_action :switch_locale

  private

  ALLOWED_LOCALES = %w[en ru].freeze

  def switch_locale(&action)
    I18n.with_locale(extract_locale, &action)
  end

  def extract_locale
    requested = cookies[:locale].presence || session[:locale].presence
    ALLOWED_LOCALES.include?(requested.to_s) ? requested.to_sym : I18n.default_locale
  end
end
