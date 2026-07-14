class CreateAssetBalances < ActiveRecord::Migration[8.0]
  def change
    create_table :asset_balances do |t|
      t.references :portfolio_snapshot, null: false, foreign_key: true
      t.string :symbol, null: false # BTC, ETH, SOL, USDC…
      t.string :chain
      t.decimal :amount, precision: 40, scale: 18, null: false, default: 0
      t.decimal :usd_value, precision: 30, scale: 8, null: false, default: 0

      t.timestamps
    end
  end
end
