# frozen_string_literal: true

class Contest < ApplicationRecord
  STATUSES = %w[upcoming running finished finalized].freeze

  has_many :contest_problems, -> { order(:position) }, dependent: :destroy, inverse_of: :contest
  has_many :problems, through: :contest_problems
  has_many :contest_participations, dependent: :restrict_with_exception, inverse_of: :contest
  has_many :participants, through: :contest_participations, source: :user
  has_many :submissions, dependent: :restrict_with_exception, inverse_of: :contest
  has_many :rating_histories, dependent: :restrict_with_exception, inverse_of: :contest

  validates :title, :starts_at, :ends_at, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :ends_after_starts

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, "must be after starts_at")
  end
end
