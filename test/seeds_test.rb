require "test_helper"

# The development seeds load the test fixtures, so this also guards that the fixtures stay loadable as seeds.
class SeedsTest < ActiveSupport::TestCase
  def run_dev_seeds
    original_env = Rails.env.to_s
    Rails.env = "development"
    load Rails.root.join("db/seeds.rb")
  ensure
    Rails.env = original_env
  end

  setup do
    @family_usernames = Family.order(:username).pluck(:username)
    @people = Person.order(:first_name).pluck(:first_name, :last_name, :den)
    @event_titles = Event.order(:title).pluck(:title)
    @rsvps = Rsvp.joins(:event, :person).order("events.title", "people.first_name").pluck("events.title", "people.first_name", :status)
    @fund_names = Fund.order(:name).pluck(:name)
    DoubleEntry::Line.delete_all
    DoubleEntry::AccountBalance.delete_all
    Fund.delete_all
    @rsvp_options = RsvpOption.joins(:event).order("events.title", :name).pluck("events.title", :name)
    Rsvp.delete_all
    RsvpOption.delete_all
    Event.delete_all
    Person.delete_all
    Family.delete_all
  end

  test "seeds recreate the fixture families and people" do
    run_dev_seeds

    assert_equal @family_usernames, Family.order(:username).pluck(:username)
    assert_equal @people, Person.order(:first_name).pluck(:first_name, :last_name, :den)
    assert_equal %w[adminfamily], Family.where(admin: true).pluck(:username)
    assert_equal %w[Lily Sam], Family.find_by!(username: "examplefamily").people.pluck(:first_name).sort
  end

  test "seeds recreate the fixture events and RSVPs" do
    run_dev_seeds

    assert_equal @event_titles, Event.order(:title).pluck(:title)
    assert_equal @rsvp_options, RsvpOption.joins(:event).order("events.title", :name).pluck("events.title", :name)
    ben_on_the_trip = Rsvp.joins(:event).find_by!(person: Person.find_by!(first_name: "Ben"), events: { title: "Weekend Trip" })
    assert_equal "Day trip only", ben_on_the_trip.rsvp_option.name
    assert_equal [ [ 2500, nil ], [ 6000, 3000 ] ], RsvpOption.joins(:event).where(events: { title: "Weekend Trip" }).order(:cost_cents).pluck(:cost_cents, :youth_cost_cents)
    assert_equal @rsvps, Rsvp.joins(:event, :person).order("events.title", "people.first_name").pluck("events.title", "people.first_name", :status)
    assert Event.find_by!(title: "Fall Campout").rsvp_deadline_at
    assert Event.find_by!(title: "Pack Meeting").starts_at.future?
  end

  test "seeds recreate the fixture funds and record sample money once" do
    run_dev_seeds

    assert_equal @fund_names, Fund.order(:name).pluck(:name)
    assert_equal 10, DoubleEntry::Line.count, "5 transactions, 2 lines each"
    assert_equal Money.new(40_00), Family.find_by!(username: "examplefamily").balance
    assert_equal Money.new(-15_00), Family.find_by!(username: "joneses").balance
    assert_equal Money.new(520_00), Fund.find_by!(name: "General").balance
    assert_equal Money.new(545_00), Ledger.total_held
  end

  test "sample families can sign in with password123" do
    run_dev_seeds

    %w[examplefamily adminfamily joneses].each do |username|
      assert Family.find_by!(username: username).valid_password?("password123"), username
    end
  end

  test "seeds are idempotent and leave other families alone" do
    run_dev_seeds
    other = Family.create!(username: "someoneelse", password: "password123", **profile_params)
    other.people.create!(first_name: "Kit", last_name: "Else", den: :other_youth)

    assert_no_difference [ "Family.count", "Person.count", "Event.count", "Rsvp.count", "Fund.count", "DoubleEntry::Line.count" ] do
      run_dev_seeds
    end
    assert Family.exists?(other.id)
    assert_equal 1, other.people.count
  end

  test "re-seeding restores a changed password and admin flag" do
    run_dev_seeds
    Family.find_by!(username: "adminfamily").update!(admin: false, password: "changed-password")

    run_dev_seeds

    admin = Family.find_by!(username: "adminfamily")
    assert admin.admin?
    assert admin.valid_password?("password123")
  end

  test "seeds do nothing outside development" do
    load Rails.root.join("db/seeds.rb")

    assert_equal 0, Family.count
    assert_equal 0, Person.count
    assert_equal 0, Event.count
    assert_equal 0, Rsvp.count
    assert_equal 0, Fund.count
    assert_equal 0, DoubleEntry::Line.count
  end
end
