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
  people = fixture_rows.call("people").transform_values do |attrs|
    family = families.fetch(attrs.fetch("family"))
    attrs = attrs.except("family")
    Person.find_or_initialize_by(family: family, first_name: attrs["first_name"], last_name: attrs["last_name"]).tap { |person| person.update!(attrs) }
  end

  # Event times in events.yml are relative to when the seeds run, so re-seeding moves them forward.
  events = fixture_rows.call("events").transform_values do |attrs|
    Event.find_or_initialize_by(title: attrs.fetch("title")).tap { |event| event.update!(attrs) }
  end

  # Ways to attend an event, matched on event + name.
  rsvp_options = fixture_rows.call("rsvp_options").transform_values do |attrs|
    event = events.fetch(attrs.fetch("event"))
    RsvpOption.find_or_initialize_by(event: event, name: attrs.fetch("name")).tap { |option| option.update!(attrs.except("event")) }
  end

  # `event: pack_meeting` / `person: smith_dad` / `rsvp_option: day_trip` in rsvps.yml are fixture labels too.
  fixture_rows.call("rsvps").each_value do |attrs|
    rsvp = Rsvp.find_or_initialize_by(event: events.fetch(attrs.fetch("event")), person: people.fetch(attrs.fetch("person")))
    rsvp.update!(status: attrs.fetch("status"), rsvp_option: rsvp_options[attrs["rsvp_option"]])
  end

  # Pack funds are fixtures too, matched on their name.
  funds = fixture_rows.call("funds").transform_values do |attrs|
    Fund.find_or_initialize_by(name: attrs.fetch("name")).tap { |fund| fund.update!(attrs) }
  end

  # Ledger lines can't be fixtures (each carries a running balance), so sample money is recorded through
  # LedgerTransaction instead - and only into an empty ledger, so re-seeding never double-counts it.
  if DoubleEntry::Line.none?
    ref = ->(account) { account == :outside ? "outside" : "#{account.class.name.underscore}:#{account.id}" }
    [
      [ :outside, families.fetch("one"), "60.00", "Popcorn sale proceeds" ],
      [ :outside, families.fetch("two"), "25.00", "Annual dues" ],
      [ :outside, funds.fetch("general"), "500.00", "Fundraiser" ],
      [ families.fetch("one"), funds.fetch("general"), "20.00", "Pack t-shirt" ],
      [ families.fetch("two"), :outside, "40.00", "Uniform purchase" ]
    ].each do |from, to, amount, memo|
      LedgerTransaction.new(from: ref.call(from), to: ref.call(to), amount: amount, memo: memo, admin: families.fetch("admin")).save || raise("couldn't seed #{memo}")
    end
  end
end
