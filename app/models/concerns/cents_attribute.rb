# Money stored as integer cents in `<name>_cents` but entered and shown as dollars. `cents_attribute :cost`
# adds `cost` (Money, or nil), `cost_dollars` / `cost_dollars=` for forms, and the validations for them.
module CentsAttribute
  extend ActiveSupport::Concern

  MAX_CENTS = 10_000_000 # $100,000

  class_methods do
    def cents_attribute(name, max_cents: MAX_CENTS)
      cents = :"#{name}_cents"
      dollars = :"#{name}_dollars"
      typed = :"@#{dollars}_typed"

      define_method(name) { Money.new(self[cents]) if self[cents] }

      # What was typed, so a rejected form shows it again; otherwise the stored amount, e.g. "25.50".
      define_method(dollars) { instance_variable_get(typed) || (self[cents] && format("%d.%02d", *self[cents].divmod(100))) }

      define_method(:"#{dollars}=") do |input|
        instance_variable_set(typed, input)
        self[cents] = Ledger.parse_dollars(input)&.fractional
      end

      validate do
        input = instance_variable_get(typed)
        if input.present? && Ledger.parse_dollars(input).nil?
          errors.add(dollars, "must be a dollar amount such as 25 or 25.50")
        elsif self[cents] && !self[cents].between?(0, max_cents)
          errors.add(dollars, "must be between $0 and #{Money.new(max_cents).format(no_cents_if_whole: true)}")
        end
      end
    end
  end
end
