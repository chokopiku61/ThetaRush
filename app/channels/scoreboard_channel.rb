# frozen_string_literal: true

class ScoreboardChannel < Turbo::StreamsChannel
  def subscribed
    return reject unless current_user
    return reject unless Contest.exists?(id: params[:contest_id])

    super
  end
end
