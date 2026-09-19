# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

if Rails.env.development?
  # Devise downcases usernames on save, so look up via find_for_authentication
  # (which does the same) to keep this idempotent.
  Family.find_for_authentication(username: "ExampleFamily") ||
    Family.create!(username: "ExampleFamily", password: "password123")

  # Re-running the seed also restores the admin flag if it was removed.
  admin = Family.find_for_authentication(username: "AdminFamily") ||
    Family.new(username: "AdminFamily", password: "password123")
  admin.update!(admin: true)
end
