class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders do |t|
      t.string :customer_email, null: false
      t.decimal :total_amount, null: false, precision: 10, scale: 2
      t.string :status, null: false, default: "confirmed"

      t.timestamps
    end

    add_index :orders, :customer_email
    add_index :orders, :status
  end
end
