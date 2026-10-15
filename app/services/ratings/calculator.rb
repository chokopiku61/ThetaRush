# frozen_string_literal: true

module Ratings
  # Codeforces-inspired Elo rating updates (pure Ruby, no DB writes).
  #
  # Pairwise model for a finished contest:
  # - expected score of A vs B: 1 / (1 + 10^((R_b - R_a) / 400))
  # - actual score: 1 if A ranked higher (lower rank number), 0 if lower, 0.5 on tie
  # - delta_a = K * sum_over_opponents(actual - expected)
  # - new_rating = max(0, round(old_rating + delta))
  #
  # Single-participant contests leave rating unchanged. Input order is preserved
  # in the output. Callers persist user.rating / RatingHistory themselves.
  class Calculator
    DEFAULT_K = 32
    RATING_SCALE = 400.0

    Contestant = Struct.new(:id, :rating, :rank, keyword_init: true)
    Result = Struct.new(:id, :old_rating, :new_rating, :rank, :delta, keyword_init: true)

    class << self
      # participants: enumerable of hashes/objects with :id (optional), :rating, :rank
      # Returns an Array of Result in the same order.
      def calculate(participants, k: DEFAULT_K)
        new(k: k).calculate(participants)
      end

      # Attributes suitable for RatingHistory.create! (does not persist).
      def history_attributes(user:, contest:, old_rating:, new_rating:, rank: nil)
        {
          user_id: user.id,
          contest_id: contest.id,
          old_rating: old_rating,
          new_rating: new_rating,
          rank: rank
        }
      end
    end

    def initialize(k: DEFAULT_K)
      @k = k
    end

    def calculate(participants)
      rows = normalize(participants)
      return rows.map { |row| unchanged_result(row) } if rows.size <= 1

      rows.map do |row|
        delta = rating_delta(row, rows)
        new_rating = [ 0, (row.rating + delta).round ].max
        Result.new(
          id: row.id,
          old_rating: row.rating,
          new_rating: new_rating,
          rank: row.rank,
          delta: new_rating - row.rating
        )
      end
    end

    private

    def normalize(participants)
      participants.map do |participant|
        rating = value(participant, :rating)
        rank = value(participant, :rank)
        raise ArgumentError, "rating is required" if rating.nil?
        raise ArgumentError, "rank is required" if rank.nil?
        raise ArgumentError, "rank must be positive" if rank.to_i < 1

        Contestant.new(
          id: value(participant, :id),
          rating: rating.to_i,
          rank: rank.to_i
        )
      end
    end

    def value(object, key)
      if object.respond_to?(key)
        object.public_send(key)
      elsif object.respond_to?(:[])
        object[key] || object[key.to_s]
      end
    end

    def rating_delta(row, all_rows)
      opponents = all_rows.reject { |other| other.equal?(row) }
      return 0.0 if opponents.empty?

      total = opponents.sum { |other| actual_score(row.rank, other.rank) - expected_score(row.rating, other.rating) }
      @k * total
    end

    def expected_score(rating_a, rating_b)
      1.0 / (1.0 + (10 ** ((rating_b - rating_a) / RATING_SCALE)))
    end

    def actual_score(rank_a, rank_b)
      if rank_a < rank_b
        1.0
      elsif rank_a > rank_b
        0.0
      else
        0.5
      end
    end

    def unchanged_result(row)
      Result.new(
        id: row.id,
        old_rating: row.rating,
        new_rating: row.rating,
        rank: row.rank,
        delta: 0
      )
    end
  end
end
