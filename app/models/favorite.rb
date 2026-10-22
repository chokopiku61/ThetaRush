# frozen_string_literal: true

class Favorite < ApplicationRecord
  FAVORITABLE_TYPES = %w[Problem Contest].freeze

  belongs_to :user
  belongs_to :favoritable, polymorphic: true

  validates :favoritable_type, inclusion: { in: FAVORITABLE_TYPES }
  validates :favoritable_id, uniqueness: { scope: %i[user_id favoritable_type] }
end
