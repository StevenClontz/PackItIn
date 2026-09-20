class AddCostToRsvpOptions < ActiveRecord::Migration[8.1]
  def change
    # Per person, in cents. Nil means the option is free (no cost set).
    add_column :rsvp_options, :cost_cents, :bigint
  end
end
