class AddYouthCostToRsvpOptions < ActiveRecord::Migration[8.1]
  def change
    # Per person, in cents, for anyone who isn't an adult. Nil means "same as cost".
    add_column :rsvp_options, :youth_cost_cents, :bigint
  end
end
