# frozen_string_literal: true

class RatingHistory < ApplicationRecord
  belongs_to :user, inverse_of: :rating_histories
  belongs_to :contest, inverse_of: :rating_histories

  validates :user_id, uniqueness: { scope: :contest_id }
  validates :old_rating, :new_rating,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rank,
            numericality: { only_integer: true, greater_than: 0 },
            allow_nil: true
end
