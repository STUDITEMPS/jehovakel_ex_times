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
    {abschnitte, [], _} =
      zeitraeume
      |> Stream.flat_map(&zu_grenzen/1)
      |> Enum.sort(&grenze_vor?/2)
      |> Enum.reduce({[], [], nil}, fn
        # Neuer Zeitpunkt ohne aktive Elemente: keinen Abschnitt emittieren
        {zeit, :start, el}, {abschnitte, [], _prev_zeit} ->
          {abschnitte, [el], zeit}

        # Gleicher Zeitpunkt: keinen Abschnitt emittieren
        {zeit, :start, el}, {abschnitte, aktiv, zeit} ->
          {abschnitte, [el | aktiv], zeit}

        {zeit, :end, el}, {abschnitte, aktiv, zeit} ->
          {abschnitte, List.delete(aktiv, el), zeit}

        # Neuer Zeitpunkt mit aktiven Elementen: Abschnitt emittieren
        {zeit, :start, el}, {abschnitte, [_ | _] = aktiv, prev_zeit} ->
          {[ueberlagerung(prev_zeit, zeit, aktiv) | abschnitte], [el | aktiv], zeit}

        {zeit, :end, el}, {abschnitte, [_ | _] = aktiv, prev_zeit} ->
          {[ueberlagerung(prev_zeit, zeit, aktiv) | abschnitte], List.delete(aktiv, el), zeit}
      end)

    Enum.reverse(abschnitte)
  end

  defp ueberlagerung(von, bis, aktive) do
    %__MODULE__{
      zeitraum: Timex.Interval.new(from: von, until: bis, step: [seconds: 1]),
      elemente: aktive
    }
  end

  defp zu_grenzen(zeitraum) do
    intervall = Zeitraum.als_intervall(zeitraum)
    [{intervall.from, :start, zeitraum}, {intervall.until, :end, zeitraum}]
  end

  defp grenze_vor?({zeit1, event1, _}, {zeit2, event2, _}) do
    case NaiveDateTime.compare(zeit1, zeit2) do
      :lt -> true
      :gt -> false
      :eq -> event1 <= event2
    end
  end

  defimpl Shared.ZeitraumProtokoll do
    def als_intervall(%{zeitraum: zeitraum}), do: zeitraum
  end
end
