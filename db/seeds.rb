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
  # Development sample data is the test fixtures (test/fixtures/*.yml), so the two never drift apart:
  # log in as ExampleFamily or AdminFamily with password123.
  #
  # Unlike `bin/rails db:fixtures:load` this doesn't wipe the tables: records are matched on their natural
  # key and updated in place, so running it again just restores the sample data (including passwords
  # and the admin flag) and leaves any other families you created alone.
  fixture_rows = lambda do |name|
    yaml = ERB.new(File.read(Rails.root.join("test/fixtures/#{name}.yml"))).result
    YAML.safe_load(yaml, aliases: true) || {}
  end

  # Fixture rows skip validations too (they carry an encrypted_password, not a password).
  families = fixture_rows.call("families").transform_values do |attrs|
    Family.find_or_initialize_by(username: attrs.fetch("username")).tap do |family|
      family.assign_attributes(attrs)
      family.save!(validate: false)
    end
  end

  # `family: one` in people.yml is a fixture label; resolve it to the family seeded above.
  fixture_rows.call("people").each_value do |attrs|
    family = families.fetch(attrs.fetch("family"))
    attrs = attrs.except("family")
    Person.find_or_initialize_by(family: family, first_name: attrs["first_name"], last_name: attrs["last_name"]).update!(attrs)
  end
end
