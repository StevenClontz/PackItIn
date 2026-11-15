class AddNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :email_opt_out, :boolean, default: false, null: false

    add_column :events, :announced_at, :datetime
    add_column :events, :rsvp_reminder_sent_at, :datetime
    add_column :events, :payment_reminder_sent_at, :datetime
  end
end
