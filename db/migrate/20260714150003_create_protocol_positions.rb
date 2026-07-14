class CreateProtocolPositions < ActiveRecord::Migration[8.0]
  def change
    create_table :protocol_positions do |t|
      t.references :portfolio_snapshot, null: false, foreign_key: true
      t.string :protocol_id, null: false # provider protocol id
      t.string :name
      t.string :chain
      t.string :logo_url
      t.decimal :usd_value, precision: 30, scale: 8, null: false, default: 0

      t.timestamps
    end
  end
end
