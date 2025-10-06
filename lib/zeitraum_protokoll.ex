defprotocol Shared.ZeitraumProtokoll do
  @spec als_intervall(t) :: Timex.Interval.t()
  def als_intervall(zeitraum)
end

defimpl Shared.ZeitraumProtokoll, for: Shared.Month do
  def als_intervall(monat) do
    {start, ende} = Shared.Month.to_dates(monat)
    Shared.Zeitperiode.new(start, ende)
  end
end

defimpl Shared.ZeitraumProtokoll, for: Shared.Month.Range do
  def als_intervall(%@for{} = month_range),
    do: @protocol.als_intervall(@for.to_date_range(month_range))
end

defimpl Shared.ZeitraumProtokoll, for: Shared.Week do
  def als_intervall(week) do
    {beginns_at, ends_at} = Shared.Week.to_dates(week)
    Shared.Zeitperiode.new(beginns_at, ends_at)
  end
end

defimpl Shared.ZeitraumProtokoll, for: Shared.Week.Range do
  def als_intervall(%@for{} = week_range),
    do: @protocol.als_intervall(@for.to_date_range(week_range))
end

defimpl Shared.ZeitraumProtokoll, for: Date do
  def als_intervall(date), do: Shared.Zeitperiode.new(date, date)
end

defimpl Shared.ZeitraumProtokoll, for: Date.Range do
  def als_intervall(%{step: 1} = date_range),
    do: Shared.Zeitperiode.new(date_range.first, date_range.last)

  def als_intervall(_date_range) do
    raise ArgumentError, "Date Ranges with steps sizes other than 1 are not supported"
  end
end

defimpl Shared.ZeitraumProtokoll, for: Timex.Interval do
  def als_intervall(interval), do: interval
end
