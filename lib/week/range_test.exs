defmodule Shared.Week.RangeTest do
  @moduledoc false
  use ExUnit.Case
  alias Shared.Week

  import Week, only: [sigil_v: 2]

  doctest(Week.Range)

  describe "is enumerable" do
    test "can be countet" do
      assert 2778 = Enum.count(Week.Range.forward(~v[2024-01], ~v[2077-12]))
    end

    test "can be converted to a list" do
      assert [~v[2024-01], ~v[2024-02]] ==
               Enum.to_list(Week.Range.forward(~v[2024-01], ~v[2024-02]))
    end

    test "can be sliced" do
      assert [~v[2024-05], ~v[2024-06]] ==
               Enum.slice(Week.Range.forward(~v[2024-01], ~v[2024-12]), 4, 2)
    end
  end

  describe "is supported by ZeitraumProtokoll" do
    alias Shared.Zeitraum

    test "can be converted to intervall" do
      assert %{from: ~N[2024-01-01 00:00:00], until: ~N[2054-01-05 00:00:00]} =
               Zeitraum.als_intervall(Week.Range.forward(~v[2024-01], ~v[2054-01]))
    end
  end
end
