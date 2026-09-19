class Family < ApplicationRecord
  # No :validatable (requires an email column) and no email-based modules
  # (:recoverable, :confirmable); validations are declared below.
  devise :database_authenticatable, :registerable, :rememberable

  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { in: 3..30 },
                       format: { with: /\A[a-z0-9_.-]+\z/i, message: "may only contain letters, numbers, underscores, periods and hyphens" }
  validates :password, presence: true, confirmation: true, length: { in: Devise.password_length }, if: :password_required?

  private

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end
end
