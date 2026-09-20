# A pack account (e.g. "General", "Campout Fund") that admins create as needed.
class Fund < ApplicationRecord
  include HasLedgerAccount

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
