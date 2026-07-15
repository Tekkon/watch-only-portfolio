module ApplicationHelper
  # USD formatting shared by every portfolio view. Large totals read better
  # without cents; keep cents for smaller values.
  def usd(amount)
    value = amount || 0
    precision = value.abs >= 1000 ? 0 : 2
    number_to_currency(value, precision: precision)
  end

  # Short, human label for a chain family (used in headers/badges).
  def chain_family_label(chain_family)
    { "evm" => "EVM", "bitcoin" => "Bitcoin", "solana" => "Solana" }
      .fetch(chain_family.to_s, chain_family.to_s.titleize)
  end

  # Truncate a long chain address for display while keeping both ends.
  def short_address(address, head: 6, tail: 4)
    str = address.to_s
    return str if str.length <= head + tail + 1

    "#{str[0, head]}…#{str[-tail, tail]}"
  end
end
