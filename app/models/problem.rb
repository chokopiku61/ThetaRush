# frozen_string_literal: true

class Problem < ApplicationRecord
  has_many :test_cases, -> { order(:position) }, dependent: :destroy, inverse_of: :problem
  has_many :contest_problems, dependent: :restrict_with_exception, inverse_of: :problem
  has_many :contests, through: :contest_problems
  has_many :submissions, dependent: :restrict_with_exception, inverse_of: :problem
  has_many :favorites, as: :favoritable, dependent: :destroy

  validates :title, :slug, :statement, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :time_limit_ms, :memory_limit_mb, :rating,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  validates :tags, presence: true

  before_validation :normalize_slug, :normalize_tags

  private

  def normalize_slug
    self.slug = slug.to_s.strip.downcase
  end

  def normalize_tags
    self.tags = tags.split(",").map(&:strip).reject(&:blank?) if tags.is_a?(String)
  end
end
