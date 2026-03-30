class CreateTicketTypes < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_types do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :price, null: false, precision: 10, scale: 2
      t.integer :quantity, null: false, default: 0

      t.timestamps
    end

    add_index :ticket_types, [ :event_id, :name ], unique: true
  end
end
