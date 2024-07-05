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

defimpl Shared.ZeitraumProtokoll, for: Shared.Week do
  def als_intervall(week) do
    {beginns_at, ends_at} = Shared.Week.to_dates(week)
    Shared.Zeitperiode.new(beginns_at, ends_at)
  end
end

defimpl Shared.ZeitraumProtokoll, for: Date do
  def als_intervall(date), do: Shared.Zeitperiode.new(date, date)
end

defimpl Shared.ZeitraumProtokoll, for: Date.Range do
  @doc """
  `t:Date.Range.t()` werden als durchgehender Zeitraum von `first` zu `last` betrachtet.
  d.h. step wird nicht weiter in betracht gezogen.

  Wenn die step size relevant ist muss die Range vorher in eine Liste von Dates
  konvertiert werden.
  """
  def als_intervall(date_range) do
    if Enum.empty?(date_range) do
      raise ArgumentError, "Empty Date.Range given"
    else
      Shared.Zeitperiode.new(date_range.first, date_range.last)
    end
  end
end

defimpl Shared.ZeitraumProtokoll, for: Timex.Interval do
  def als_intervall(interval), do: interval
end
