# frozen_string_literal: true

module Contests
  class ScoreboardBroadcaster
    def self.call(contest)
      rows = contest.contest_participations.includes(:user).order(:rank, :registered_at, :id)

      Turbo::StreamsChannel.broadcast_replace_to(
        contest, :scoreboard,
        target: "scoreboard_rows",
        partial: "contests/scoreboard_rows",
        locals: { rows: rows }
      )
    rescue StandardError => error
      Rails.logger.error("[ScoreboardBroadcaster] contest=#{contest.id} #{error.class}: #{error.message}")
    end
  end
end
