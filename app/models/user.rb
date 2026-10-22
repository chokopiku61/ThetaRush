# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  USERNAME_FORMAT = /\A[a-zA-Z0-9_]+\z/

  has_many :submissions, dependent: :restrict_with_exception
  has_many :contest_participations, dependent: :restrict_with_exception
  has_many :contests, through: :contest_participations
  has_many :rating_histories, dependent: :restrict_with_exception
  has_many :favorites, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships

  has_many :favorite_problems,
           through: :favorites,
           source: :favoritable,
           source_type: "Problem"
  has_many :favorite_contests,
           through: :favorites,
           source: :favoritable,
           source_type: "Contest"

  validates :username,
            presence: true,
            uniqueness: { case_sensitive: false },
            length: { minimum: 3, maximum: 20 },
            format: { with: USERNAME_FORMAT, message: "only allows letters, numbers, and underscores" }
  validates :rating, :max_rating,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :normalize_username
  before_validation :assign_username_from_email, on: :create

  private

  def normalize_username
    self.username = username.to_s.strip
  end

  # Keeps Devise registration working until a username field is added to the form.
  def assign_username_from_email
    return if username.present? || email.blank?

    base = email.split("@").first.to_s.gsub(/[^a-zA-Z0-9_]/, "")
    base = "user" if base.length < 3
    base = base[0, 16]
    candidate = base
    n = 0
    while self.class.exists?(username: candidate)
      n += 1
      suffix = n.to_s
      candidate = "#{base[0, 20 - suffix.length]}#{suffix}"
    end
    self.username = candidate
  end
end
