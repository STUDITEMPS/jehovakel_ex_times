defmodule Shared.ZeitraumTest do
  use ExUnit.Case

  import Shared.Week, only: [sigil_v: 2]
  import Shared.Month, only: [sigil_m: 2]

  alias Shared.Zeitraum

  doctest Zeitraum, import: true

  test "differenz/2" do
    assert [] == Zeitraum.differenz(~D[2025-01-01], ~D[2025-01-01])
    assert [] == Zeitraum.differenz(~D[2025-01-01], ~m[2025-01])

    assert [Zeitraum.als_intervall(Date.range(~D[2025-01-02], ~D[2025-01-31]))] ==
             Zeitraum.differenz(~m[2025-01], ~D[2025-01-01])

    assert [
             Zeitraum.als_intervall(Date.range(~D[2024-12-30], ~D[2024-12-31])),
             Zeitraum.als_intervall(Date.range(~D[2025-01-02], ~D[2025-01-05])),
             Zeitraum.als_intervall(Date.range(~D[2025-01-14], ~D[2025-01-19]))
           ] ==
             Zeitraum.differenz([~v[2025-01], ~v[2025-03]], [
               ~D[2025-01-01],
               ~D[2025-01-08],
               ~D[2025-01-13]
             ])

    assert [] == Zeitraum.differenz([~D[2025-01-01], ~D[2025-01-13]], [~v[2025-01], ~v[2025-03]])
  end
end
