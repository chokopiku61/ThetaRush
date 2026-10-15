# frozen_string_literal: true

class Submission < ApplicationRecord
  LANGUAGES = %w[python cpp].freeze
  STATUSES = %w[queued judging ac wa tle mle re ce ie].freeze

  belongs_to :user, inverse_of: :submissions
  belongs_to :problem, inverse_of: :submissions
  belongs_to :contest, optional: true, inverse_of: :submissions

  validates :language, presence: true, inclusion: { in: LANGUAGES }
  validates :source_code, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :judge0_token, uniqueness: true, allow_nil: true
  validates :time_ms, :memory_kb,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :submitted_at, presence: true
  validate :contest_includes_problem, if: -> { contest.present? }

  before_validation :set_submitted_at, on: :create

  private

  def set_submitted_at
    self.submitted_at ||= Time.current
  end

  def contest_includes_problem
    return if contest.contest_problems.exists?(problem_id: problem_id)

    errors.add(:problem, "is not part of the contest")
  end
end
