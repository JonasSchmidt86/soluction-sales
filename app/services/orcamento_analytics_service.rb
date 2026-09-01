# frozen_string_literal: true

class OrcamentoAnalyticsService
  def self.record_view(orcamento, duration_seconds: 0)
    now = Time.current
    orcamento.update_columns(
      views_count: orcamento.views_count.to_i + 1,
      first_viewed_at: orcamento.first_viewed_at || now,
      last_viewed_at: now,
      total_view_seconds: orcamento.total_view_seconds.to_i + duration_seconds.to_i
    )
  end

  def self.record_duration(orcamento, duration_seconds:)
    return if duration_seconds.to_i <= 0

    orcamento.update_columns(
      total_view_seconds: orcamento.total_view_seconds.to_i + duration_seconds.to_i,
      last_viewed_at: Time.current
    )
  end

  def self.format_duration(seconds)
    return '—' if seconds.nil? || seconds <= 0

    minutes = seconds / 60
    remaining_seconds = seconds % 60

    if minutes > 0
      "#{minutes}m #{remaining_seconds}s"
    else
      "#{remaining_seconds}s"
    end
  end
end
