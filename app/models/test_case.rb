# frozen_string_literal: true

class TestCase < ApplicationRecord
  belongs_to :problem, inverse_of: :test_cases

  has_one_attached :stdin_file
  has_one_attached :expected_output_file

  validates :position,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 },
            uniqueness: { scope: :problem_id }
  validate :stdin_present
  validate :expected_output_present

  def stdin_content
    return stdin if stdin.present?
    return stdin_file.download.force_encoding(Encoding::UTF_8) if stdin_file.attached?

    nil
  end

  def expected_output_content
    return expected_output if expected_output.present?
    return expected_output_file.download.force_encoding(Encoding::UTF_8) if expected_output_file.attached?

    nil
  end

  private

  def stdin_present
    return if stdin.present? || stdin_file.attached?

    errors.add(:base, "stdin text or stdin_file attachment is required")
  end

  def expected_output_present
    return if expected_output.present? || expected_output_file.attached?

    errors.add(:base, "expected_output text or expected_output_file attachment is required")
  end
end
