class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.string :label
      t.string :address, null: false
      t.integer :chain_family, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :addresses, :address
    # Balances are a property of (address, chain_family), so the fetch/cache layer
    # dedupes on this pair. user_id (a user's saved list) is added in the auth milestone.
    add_index :addresses, %i[address chain_family], unique: true
  end
end
