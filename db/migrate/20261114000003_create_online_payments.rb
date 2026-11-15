class CreateOnlinePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :online_payments do |t|
      t.references :family, null: false, foreign_key: true
      t.bigint :amount_cents, null: false # credited to the Scout Account
      t.bigint :fee_cents, null: false, default: 0 # added on top to cover card processing
      t.integer :status, null: false, default: 0
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.datetime :completed_at
      t.timestamps
    end
    add_index :online_payments, :stripe_checkout_session_id, unique: true
  end
end
