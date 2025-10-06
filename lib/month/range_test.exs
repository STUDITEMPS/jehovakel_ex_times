defmodule Shared.Month.RangeTest do
  @moduledoc false
  use ExUnit.Case
  alias Shared.Month

  import Month, only: [sigil_m: 2]

  doctest(Month.Range)

  describe "is enumerable" do
    test "can be countet" do
      assert 648 = Enum.count(Month.Range.forward(~m[2024-01], ~m[2077-12]))
    end

    test "can be converted to a list" do
      assert [~m[2024-01], ~m[2024-02]] ==
               Enum.to_list(Month.Range.forward(~m[2024-01], ~m[2024-02]))
    end

    test "can be sliced" do
      assert [~m[2024-05], ~m[2024-06]] ==
               Enum.slice(Month.Range.forward(~m[2024-01], ~m[2024-12]), 4, 2)
    end
  end

  describe "is supported by ZeitraumProtokoll" do
    alias Shared.Zeitraum

    test "can be converted to intervall" do
      assert %{from: ~N[2024-01-01 00:00:00], until: ~N[2078-01-01 00:00:00]} =
               Zeitraum.als_intervall(Month.Range.forward(~m[2024-01], ~m[2077-12]))
    end
  end
end
