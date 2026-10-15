# frozen_string_literal: true

class ContestParticipation < ApplicationRecord
  belongs_to :user, inverse_of: :contest_participations
  belongs_to :contest, inverse_of: :contest_participations

  validates :user_id, uniqueness: { scope: :contest_id }
  validates :solved_count, :penalty,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rank,
            numericality: { only_integer: true, greater_than: 0 },
            allow_nil: true
  validates :registered_at, presence: true

  before_validation :set_registered_at, on: :create

  private

  def set_registered_at
    self.registered_at ||= Time.current
  end
end
