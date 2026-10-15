# frozen_string_literal: true

class ContestProblem < ApplicationRecord
  LETTER_FORMAT = /\A[A-Z]\z/

  belongs_to :contest, inverse_of: :contest_problems
  belongs_to :problem, inverse_of: :contest_problems

  validates :position,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 },
            uniqueness: { scope: :contest_id }
  validates :letter,
            presence: true,
            format: { with: LETTER_FORMAT, message: "must be a single uppercase letter" },
            uniqueness: { scope: :contest_id }
  validates :problem_id, uniqueness: { scope: :contest_id }

  before_validation :normalize_letter

  private

  def normalize_letter
    self.letter = letter.to_s.strip.upcase
  end
end
