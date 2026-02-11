defmodule Shared.Zeitraum.Ueberlagerung do
  @moduledoc """
  Ein Zeitraum zusammen mit allen Elementen, die diesen Zeitraum überlagern.

  Implementiert `Shared.ZeitraumProtokoll`, sodass Überlagerungen direkt mit
  `Zeitraum.differenz/2`, `Zeitraum.ueberschneidung/2`, etc. verwendet werden können.
  """

  @type t :: %__MODULE__{zeitraum: Timex.Interval.t(), elemente: [Shared.ZeitraumProtokoll.t()]}

  @enforce_keys [:zeitraum, :elemente]
  defstruct [:zeitraum, :elemente]

  defimpl Shared.ZeitraumProtokoll do
    def als_intervall(%{zeitraum: zeitraum}), do: zeitraum
  end
end
