defmodule Shared.Zeitraum.Ueberlagerung do
  @moduledoc """
  Ein Zeitraum zusammen mit allen Elementen, die diesen Zeitraum überlagern.

  Implementiert `Shared.ZeitraumProtokoll`, sodass Überlagerungen direkt mit
  `Zeitraum.differenz/2`, `Zeitraum.ueberschneidung/2`, etc. verwendet werden können.
  """

  alias Shared.Zeitraum

  @type t :: %__MODULE__{zeitraum: Timex.Interval.t(), elemente: [Shared.ZeitraumProtokoll.t()]}

  @enforce_keys [:zeitraum, :elemente]
  defstruct [:zeitraum, :elemente]

  @doc false
  def aus_zeitraeumen([]), do: []

  def aus_zeitraeumen([_] = zeitraeume) do
    [
      %__MODULE__{
        zeitraum: Zeitraum.als_intervall(hd(zeitraeume)),
        elemente: zeitraeume
      }
    ]
  end

  def aus_zeitraeumen(zeitraeume) do
    # Events: {sort_key, :end/:start, ndt, element}
    # :end < :start alphabetisch → :end wird bei gleichem Zeitpunkt zuerst verarbeitet
    # Akkumulator: {abschnitte, aktive, {prev_sort_key, prev_ndt} | nil}
    {abschnitte, [], _} =
      zeitraeume
      |> Enum.flat_map(&zu_grenzen/1)
      |> Enum.sort()
      |> Enum.reduce({[], [], nil}, fn
        # Neuer Zeitpunkt ohne aktive Elemente
        {key, :start, ndt, el}, {abschnitte, [], _} ->
          {abschnitte, [el], {key, ndt}}

        # Gleicher Zeitpunkt
        {key, :start, _, el}, {abschnitte, aktiv, {key, _} = prev} ->
          {abschnitte, [el | aktiv], prev}

        {key, :end, _, el}, {abschnitte, aktiv, {key, _} = prev} ->
          {abschnitte, List.delete(aktiv, el), prev}

        # Neuer Zeitpunkt mit aktiven Elementen → Abschnitt emittieren
        {key, :start, ndt, el}, {abschnitte, [_ | _] = aktiv, {_, prev_ndt}} ->
          {[abschnitt(prev_ndt, ndt, aktiv) | abschnitte], [el | aktiv], {key, ndt}}

        {key, :end, ndt, el}, {abschnitte, [_ | _] = aktiv, {_, prev_ndt}} ->
          {[abschnitt(prev_ndt, ndt, aktiv) | abschnitte], List.delete(aktiv, el), {key, ndt}}
      end)

    Enum.reverse(abschnitte)
  end

  defp abschnitt(von, bis, aktive) do
    %__MODULE__{
      zeitraum: %Timex.Interval{from: von, until: bis, step: [seconds: 1], left_open: false, right_open: true},
      elemente: aktive
    }
  end

  defp zu_grenzen(zeitraum) do
    intervall = Zeitraum.als_intervall(zeitraum)

    [
      {sort_key(intervall.from), :start, intervall.from, zeitraum},
      {sort_key(intervall.until), :end, intervall.until, zeitraum}
    ]
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

  defimpl Shared.ZeitraumProtokoll do
    def als_intervall(%{zeitraum: zeitraum}), do: zeitraum
  end
end
