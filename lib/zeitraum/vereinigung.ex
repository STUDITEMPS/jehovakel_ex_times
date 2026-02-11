defmodule Shared.Zeitraum.Vereinigung do
  @moduledoc false

  alias Shared.Zeitraum

  defguardp ueberlappt(a, b) when elem(b, 0) <= elem(a, 1)
  defguardp endet_vor(a, b) when elem(a, 1) < elem(b, 1)
  defguardp beginnt_nach(a, b) when elem(a, 0) > elem(b, 0)

  @spec aus_zeitraeumen([Zeitraum.t()]) :: [Timex.Interval.t()]
  def aus_zeitraeumen(zeitraeume) do
    zeitraeume
    |> Enum.map(&als_tupel/1)
    |> Enum.sort()
    |> vereinige()
  end

  defp vereinige([]), do: []
  defp vereinige([a, b | rest]) when ueberlappt(a, b), do: vereinige([vereinige(a, b) | rest])
  defp vereinige([eigenstaendig | rest]), do: [intervall(eigenstaendig) | vereinige(rest)]
  defp vereinige(a, b) when endet_vor(a, b), do: {elem(a, 0), elem(b, 1), elem(a, 2), elem(b, 3)}
  defp vereinige(a, _b) when is_tuple(a), do: a

  defp als_tupel(zeitraum) do
    intervall = Zeitraum.als_intervall(zeitraum)
    {sort_key(intervall.from), sort_key(intervall.until), intervall.from, intervall.until}
  end

  defp intervall({_, _, from, until}) do
    %Timex.Interval{
      from: from,
      until: until,
      step: [seconds: 1],
      left_open: false,
      right_open: true
    }
  end

  defp sort_key(%NaiveDateTime{
         year: y,
         month: m,
         day: d,
         hour: h,
         minute: min,
         second: s,
         microsecond: {us, _}
       }) do
    {y, m, d, h, min, s, us}
  end
end
