FactoryBot.define do
  factory :asset_balance do
    association :portfolio_snapshot
    symbol { "ETH" }
    chain { "eth" }
    amount { BigDecimal("1") }
    usd_value { BigDecimal("1000") }
  end
end
