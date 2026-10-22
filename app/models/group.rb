# frozen_string_literal: true

class Group < ApplicationRecord
  has_many :group_memberships, dependent: :destroy
  has_many :members, through: :group_memberships, source: :user

  validates :name, presence: true, length: { maximum: 80 }
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

  before_validation :assign_slug

  def to_param
    slug
  end

  private

  def assign_slug
    self.slug = slug.to_s.parameterize if slug.present?
    return if slug.present?

    base = name.to_s.parameterize
    base = "group" if base.blank?
    candidate = base
    n = 1
    while self.class.where.not(id: id).exists?(slug: candidate)
      n += 1
      candidate = "#{base}-#{n}"
    end
    self.slug = candidate
  end
end
