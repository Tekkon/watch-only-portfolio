class CreatePortfolioSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :portfolio_snapshots do |t|
      t.references :address, null: false, foreign_key: true
      t.decimal :total_usd, precision: 30, scale: 8, null: false, default: 0
      t.datetime :fetched_at, null: false
      t.jsonb :raw_payload # raw provider response, kept for debugging

      t.timestamps
    end

    # "Latest snapshot per address" reads hit this hot path constantly.
    add_index :portfolio_snapshots, [ :address_id, :fetched_at ]
  end
end
