ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Tests run inside a transaction; tell double_entry so its own locking transaction is allowed to nest in it.
DoubleEntry::Locking.configuration.running_inside_transactional_fixtures = true

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # "family:12" / "fund:3" / "outside", as the transaction form submits accounts.
    def ledger_ref(account)
      return account if account.is_a?(String)

      account == :outside ? "outside" : "#{account.class.name.underscore}:#{account.id}"
    end

    # Records a ledger transaction directly, e.g. transact(from: :outside, to: families(:one), dollars: 50).
    def transact(from:, to:, dollars:, memo: nil, admin: nil)
      transaction = LedgerTransaction.new(from: ledger_ref(from), to: ledger_ref(to), amount: dollars.to_s, memo: memo, admin: admin)
      raise "couldn't record: #{transaction.errors.full_messages.to_sentence}" unless transaction.save

      transaction
    end

    # The profile attributes every Family requires, for building or posting valid families.
    def profile_params(**overrides)
      { name: "The New Family", street_address: "1 Test Rd", city: "Springfield", state: "il", zip: "62701" }.merge(overrides)
    end
  end
end
