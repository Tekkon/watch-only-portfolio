FactoryBot.define do
  factory :protocol_position do
    association :portfolio_snapshot
    sequence(:protocol_id) { |n| "protocol#{n}" }
    name { "Aave V3" }
    chain { "arb" }
    logo_url { "https://example.com/aave.png" }
    usd_value { BigDecimal("500") }
  end
end
