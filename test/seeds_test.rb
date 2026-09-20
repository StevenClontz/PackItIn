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
    @people = Person.order(:first_name).pluck(:first_name, :last_name, :position)
    @event_titles = Event.order(:title).pluck(:title)
    @rsvps = Rsvp.joins(:event, :person).order("events.title", "people.first_name").pluck("events.title", "people.first_name", :status)
    Rsvp.delete_all
    Event.delete_all
    Person.delete_all
    Family.delete_all
  end

  test "seeds recreate the fixture families and people" do
    run_dev_seeds

    assert_equal @family_usernames, Family.order(:username).pluck(:username)
    assert_equal @people, Person.order(:first_name).pluck(:first_name, :last_name, :position)
    assert_equal %w[adminfamily], Family.where(admin: true).pluck(:username)
    assert_equal %w[Lily Sam], Family.find_by!(username: "examplefamily").people.pluck(:first_name).sort
  end

  test "seeds recreate the fixture events and RSVPs" do
    run_dev_seeds

    assert_equal @event_titles, Event.order(:title).pluck(:title)
    assert_equal @rsvps, Rsvp.joins(:event, :person).order("events.title", "people.first_name").pluck("events.title", "people.first_name", :status)
    assert Event.find_by!(title: "Fall Campout").rsvp_deadline_at
    assert Event.find_by!(title: "Pack Meeting").starts_at.future?
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
    other.people.create!(first_name: "Kit", last_name: "Else", position: :youth)

    assert_no_difference [ "Family.count", "Person.count", "Event.count", "Rsvp.count" ] do
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
  end
end
