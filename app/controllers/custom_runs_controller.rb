# frozen_string_literal: true

class CustomRunsController < ApplicationController
  before_action :authenticate_user!

  def create
    problem = Problem.find(params[:problem_id])
    language = params[:language].to_s
    source_code = params[:source_code].to_s
    stdin = params[:stdin].to_s

    unless Submission::LANGUAGES.include?(language)
      return render json: { error: "unsupported language" }, status: :unprocessable_entity
    end

    if source_code.blank?
      return render json: { error: "source_code required" }, status: :unprocessable_entity
    end

    client = judge0_client
    result = client.create_run(
      language: language,
      source_code: source_code,
      stdin: stdin,
      time_limit_ms: problem.time_limit_ms,
      memory_limit_mb: problem.memory_limit_mb
    )

    render json: result
  rescue ActiveRecord::RecordNotFound
    render json: { error: t("problems.not_found") }, status: :not_found
  rescue Judge0Client::UnsupportedLanguage => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue Judge0Client::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end

  class << self
    attr_accessor :stub_client
  end

  private

  # Overridable in tests via CustomRunsController.stub_client.
  def judge0_client
    self.class.stub_client || Judge0Client.new
  end
end

