class CreateTickets < ActiveRecord::Migration[7.2]
  def change
    create_table :tickets do |t|
      t.references :order, null: false, foreign_key: true
      t.references :ticket_type, null: false, foreign_key: true
      t.decimal :unit_price, null: false, precision: 10, scale: 2

      t.timestamps
    end
  end
end
