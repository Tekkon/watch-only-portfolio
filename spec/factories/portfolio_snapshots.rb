FactoryBot.define do
  factory :portfolio_snapshot do
    association :address
    total_usd { BigDecimal("1000") }
    fetched_at { Time.current }
  end
end
