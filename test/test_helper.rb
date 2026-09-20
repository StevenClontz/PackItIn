ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # The profile attributes every Family requires, for building or posting valid families.
    def profile_params(**overrides)
      { name: "The New Family", street_address: "1 Test Rd", city: "Springfield", state: "il", zip: "62701" }.merge(overrides)
    end
  end
end
