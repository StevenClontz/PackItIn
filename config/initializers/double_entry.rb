require "double_entry"

# Family and pack money lives in a double-entry ledger (the double_entry gem). Every transfer writes two
# lines, so "outside the pack" is an account too: a deposit is a transfer from :external to an account
# and a withdrawal is a transfer from an account to :external. Balances may go negative (no
# positive_only), and all accounts, :external included, always sum to zero.
Money.default_currency = "USD"
Money.locale_backend = :i18n

DoubleEntry.configure do |config|
  config.json_metadata = true

  config.define_accounts do |accounts|
    # Compared by class name rather than constant so this initializer never holds a reloadable class.
    scoped_to = lambda do |model|
      lambda do |record|
        raise "not a #{model}" unless record.class.name == model
        record.id
      end
    end

    accounts.define(identifier: :family, scope_identifier: scoped_to.call("Family"))
    accounts.define(identifier: :fund, scope_identifier: scoped_to.call("Fund"))
    accounts.define(identifier: :external)
  end

  config.define_transfers do |transfers|
    %i[family fund].each do |account|
      transfers.define(from: :external, to: account, code: :deposit)
      transfers.define(from: account, to: :external, code: :withdrawal)

      %i[family fund].each { |other| transfers.define(from: account, to: other, code: :transfer) }
    end
  end
end
