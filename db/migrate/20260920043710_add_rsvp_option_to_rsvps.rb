class AddRsvpOptionToRsvps < ActiveRecord::Migration[8.1]
  def change
    # Nullable: events without options, "not attending" answers, and answers whose option was later deleted.
    add_reference :rsvps, :rsvp_option, null: true, foreign_key: { on_delete: :nullify }
  end
end
