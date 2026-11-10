defmodule Shared.Datumsbereich.Ueberlagerung do
  @moduledoc """
  Ein Datumsbereich zusammen mit allen Elementen, die diesen Datumsbereich
  überlagern. Ergebnis von `Shared.Datumsbereich.ueberlagere/1`.

  ## Beispiel

      iex> [ueberlagerung | _] =
      ...>   Shared.Datumsbereich.ueberlagere([
      ...>     Date.range(~D[2025-01-01], ~D[2025-01-05]),
      ...>     Date.range(~D[2025-01-03], ~D[2025-01-08])
      ...>   ])
      iex> Shared.Datumsbereich.Ueberlagerung.to_date_range(ueberlagerung)
      Date.range(~D[2025-01-01], ~D[2025-01-02])
  """

  @behaviour Shared.Datumsbereich

  @type t :: %__MODULE__{datumsbereich: Date.Range.t(), elemente: [Date.Range.t()]}

  @enforce_keys [:datumsbereich, :elemente]
  defstruct [:datumsbereich, :elemente]

  @impl Shared.Datumsbereich
  def to_date_range(%__MODULE__{datumsbereich: datumsbereich}), do: datumsbereich
end
