FactoryBot.define do
  factory :address do
    sequence(:address) { |n| "0x#{n.to_s(16).rjust(40, '0')}" }
    chain_family { :evm }
    active { true }

    trait :bitcoin do
      chain_family { :bitcoin }
      address { "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa" }
    end

    # An address with a latest snapshot already stamped, so query objects and
    # the public viewer have something cached to read.
    trait :synced do
      last_synced_at { Time.current }

      after(:create) do |address|
        create(:portfolio_snapshot, address: address, fetched_at: address.last_synced_at)
      end
    end
  end
end
