# frozen_string_literal: true

class UpdateRatingsJob < ApplicationJob
  queue_as :default

  def perform(contest_id)
    Contest.transaction do
      contest = Contest.lock.find(contest_id)
      next if contest.status == "finalized"

      participations = contest.contest_participations.order(:id).to_a
      users = User.where(id: participations.map(&:user_id)).lock.index_by(&:id)
      results = Ratings::Calculator.calculate(
        participations.map do |participation|
          user = users.fetch(participation.user_id)
          { id: user.id, rating: user.rating, rank: participation.rank }
        end
      )

      results.each do |result|
        user = users.fetch(result.id)
        RatingHistory.create!(
          Ratings::Calculator.history_attributes(
            user: user,
            contest: contest,
            old_rating: result.old_rating,
            new_rating: result.new_rating,
            rank: result.rank
          )
        )
        user.update!(
          rating: result.new_rating,
          max_rating: [ user.max_rating, result.new_rating ].max
        )
      end

      contest.update!(status: "finalized")
    end
  end
end
