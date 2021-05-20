defmodule Shared.TimeComparisonTest do
  use ExUnit.Case, async: true
  import Shared.Month, only: [sigil_m: 2]
  import Shared.Zeit.Sigil, only: [sigil_G: 2]

  alias Shared.TimeComparison

  describe "earlier_than?/2" do
    test "Month" do
      assert ~m[2021-01] |> TimeComparison.earlier_than?(~m[2021-03])
      refute ~m[2021-01] |> TimeComparison.earlier_than?(~m[2020-03])
      refute ~m[2021-01] |> TimeComparison.earlier_than?(~m[2021-01])
    end

    test "Zeit" do
      assert ~G[2021-01-01 12:00:00] |> TimeComparison.earlier_than?(~G[2021-01-01 12:01:00])
      refute ~G[2021-01-01 12:00:00] |> TimeComparison.earlier_than?(~G[2021-01-01 11:01:00])
      refute ~G[2021-01-01 12:00:00] |> TimeComparison.earlier_than?(~G[2021-01-01 12:00:00])
    end

    test "NaiveDateTime" do
      assert ~N[2021-01-01 12:00:00] |> TimeComparison.earlier_than?(~N[2021-01-01 12:01:00])
      refute ~N[2021-01-01 12:00:00] |> TimeComparison.earlier_than?(~N[2021-01-01 11:01:00])
      refute ~N[2021-01-01 12:00:00] |> TimeComparison.earlier_than?(~N[2021-01-01 12:00:00])
    end

    test "DateTime" do
      assert ~U[2021-01-01 12:00:00+00]
             |> TimeComparison.earlier_than?(~U[2021-01-01 12:01:00+00])

      refute ~U[2021-01-01 12:00:00+00]
             |> TimeComparison.earlier_than?(~U[2021-01-01 11:01:00+00])

      refute ~U[2021-01-01 12:00:00+00]
             |> TimeComparison.earlier_than?(~U[2021-01-01 12:00:00+00])
    end

    test "Time" do
      assert ~T[12:00:00] |> TimeComparison.earlier_than?(~T[12:01:00])
      refute ~T[12:00:00] |> TimeComparison.earlier_than?(~T[11:01:00])
      refute ~T[12:00:00] |> TimeComparison.earlier_than?(~T[12:00:00])
    end
  end

  describe "equal_to?/2" do
    test "Month" do
      refute ~m[2021-01] |> TimeComparison.equal_to?(~m[2021-03])
      refute ~m[2021-01] |> TimeComparison.equal_to?(~m[2020-03])
      assert ~m[2021-01] |> TimeComparison.equal_to?(~m[2021-01])
    end

    test "Zeit" do
      refute ~G[2021-01-01 12:00:00] |> TimeComparison.equal_to?(~G[2021-01-01 12:01:00])

      refute ~G[2021-01-01 12:00:00] |> TimeComparison.equal_to?(~G[2021-01-01 11:01:00])

      assert ~G[2021-01-01 12:00:00] |> TimeComparison.equal_to?(~G[2021-01-01 12:00:00])
    end

    test "NaiveDateTime" do
      refute ~N[2021-01-01 12:00:00] |> TimeComparison.equal_to?(~N[2021-01-01 12:01:00])

      refute ~N[2021-01-01 12:00:00] |> TimeComparison.equal_to?(~N[2021-01-01 11:01:00])

      assert ~N[2021-01-01 12:00:00] |> TimeComparison.equal_to?(~N[2021-01-01 12:00:00])
    end

    test "DateTime" do
      refute ~U[2021-01-01 12:00:00+00] |> TimeComparison.equal_to?(~U[2021-01-01 12:01:00+00])

      refute ~U[2021-01-01 12:00:00+00] |> TimeComparison.equal_to?(~U[2021-01-01 11:01:00+00])

      assert ~U[2021-01-01 12:00:00+00] |> TimeComparison.equal_to?(~U[2021-01-01 12:00:00+00])
    end

    test "Time" do
      refute ~T[12:00:00] |> TimeComparison.equal_to?(~T[12:01:00])
      refute ~T[12:00:00] |> TimeComparison.equal_to?(~T[11:01:00])
      assert ~T[12:00:00] |> TimeComparison.equal_to?(~T[12:00:00])
    end
  end

  describe "earlier_than_or_equal_to?/2" do
    test "Month" do
      assert ~m[2021-01] |> TimeComparison.earlier_than_or_equal_to?(~m[2021-03])
      refute ~m[2021-01] |> TimeComparison.earlier_than_or_equal_to?(~m[2020-03])
      assert ~m[2021-01] |> TimeComparison.earlier_than_or_equal_to?(~m[2021-01])
    end

    test "Zeit" do
      assert ~G[2021-01-01 12:00:00]
             |> TimeComparison.earlier_than_or_equal_to?(~G[2021-01-01 12:01:00])

      refute ~G[2021-01-01 12:00:00]
             |> TimeComparison.earlier_than_or_equal_to?(~G[2021-01-01 11:01:00])

      assert ~G[2021-01-01 12:00:00]
             |> TimeComparison.earlier_than_or_equal_to?(~G[2021-01-01 12:00:00])
    end

    test "NaiveDateTime" do
      assert ~N[2021-01-01 12:00:00]
             |> TimeComparison.earlier_than_or_equal_to?(~N[2021-01-01 12:01:00])

      refute ~N[2021-01-01 12:00:00]
             |> TimeComparison.earlier_than_or_equal_to?(~N[2021-01-01 11:01:00])

      assert ~N[2021-01-01 12:00:00]
             |> TimeComparison.earlier_than_or_equal_to?(~N[2021-01-01 12:00:00])
    end

    test "DateTime" do
      assert ~U[2021-01-01 12:00:00+00]
             |> TimeComparison.earlier_than_or_equal_to?(~U[2021-01-01 12:01:00+00])

      refute ~U[2021-01-01 12:00:00+00]
             |> TimeComparison.earlier_than_or_equal_to?(~U[2021-01-01 11:01:00+00])

      assert ~U[2021-01-01 12:00:00+00]
             |> TimeComparison.earlier_than_or_equal_to?(~U[2021-01-01 12:00:00+00])
    end

    test "Time" do
      assert ~T[12:00:00] |> TimeComparison.earlier_than_or_equal_to?(~T[12:01:00])
      refute ~T[12:00:00] |> TimeComparison.earlier_than_or_equal_to?(~T[11:01:00])
      assert ~T[12:00:00] |> TimeComparison.earlier_than_or_equal_to?(~T[12:00:00])
    end
  end
end
