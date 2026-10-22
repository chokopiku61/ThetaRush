# frozen_string_literal: true

class GroupMembership < ApplicationRecord
  ROLES = %w[owner member].freeze

  belongs_to :group
  belongs_to :user

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :group_id }
end
