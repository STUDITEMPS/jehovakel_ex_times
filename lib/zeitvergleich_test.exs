defmodule Shared.ZeitvergleichTest do
  use ExUnit.Case, async: true
  import Shared.Zeit.Sigil, only: [sigil_G: 2]

  alias Shared.Zeitvergleich

  describe "frueher_als?/2" do
    test "Zeit" do
      assert ~G[2021-01-01 12:00:00] |> Zeitvergleich.frueher_als?(~G[2021-01-01 12:01:00])
      refute ~G[2021-01-01 12:00:00] |> Zeitvergleich.frueher_als?(~G[2021-01-01 11:01:00])
      refute ~G[2021-01-01 12:00:00] |> Zeitvergleich.frueher_als?(~G[2021-01-01 12:00:00])
    end

    test "NaiveDateTime" do
      assert ~N[2021-01-01 12:00:00] |> Zeitvergleich.frueher_als?(~N[2021-01-01 12:01:00])
      refute ~N[2021-01-01 12:00:00] |> Zeitvergleich.frueher_als?(~N[2021-01-01 11:01:00])
      refute ~N[2021-01-01 12:00:00] |> Zeitvergleich.frueher_als?(~N[2021-01-01 12:00:00])
    end

    test "DateTime" do
      assert ~U[2021-01-01 12:00:00+00]
             |> Zeitvergleich.frueher_als?(~U[2021-01-01 12:01:00+00])

      refute ~U[2021-01-01 12:00:00+00]
             |> Zeitvergleich.frueher_als?(~U[2021-01-01 11:01:00+00])

      refute ~U[2021-01-01 12:00:00+00]
             |> Zeitvergleich.frueher_als?(~U[2021-01-01 12:00:00+00])
    end

    test "Time" do
      assert ~T[12:00:00] |> Zeitvergleich.frueher_als?(~T[12:01:00])
      refute ~T[12:00:00] |> Zeitvergleich.frueher_als?(~T[11:01:00])
      refute ~T[12:00:00] |> Zeitvergleich.frueher_als?(~T[12:00:00])
    end

    test "Date" do
      assert ~D[2021-06-18] |> Zeitvergleich.frueher_als?(~D[2021-06-19])
      refute ~D[2021-06-18] |> Zeitvergleich.frueher_als?(~D[2021-06-18])
      refute ~D[2021-06-18] |> Zeitvergleich.frueher_als?(~D[2021-06-17])
    end
  end

  describe "zeitgleich?/2" do
    test "Zeit" do
      refute ~G[2021-01-01 12:00:00] |> Zeitvergleich.zeitgleich?(~G[2021-01-01 12:01:00])

      refute ~G[2021-01-01 12:00:00] |> Zeitvergleich.zeitgleich?(~G[2021-01-01 11:01:00])

      assert ~G[2021-01-01 12:00:00] |> Zeitvergleich.zeitgleich?(~G[2021-01-01 12:00:00])
    end

    test "NaiveDateTime" do
      refute ~N[2021-01-01 12:00:00] |> Zeitvergleich.zeitgleich?(~N[2021-01-01 12:01:00])

      refute ~N[2021-01-01 12:00:00] |> Zeitvergleich.zeitgleich?(~N[2021-01-01 11:01:00])

      assert ~N[2021-01-01 12:00:00] |> Zeitvergleich.zeitgleich?(~N[2021-01-01 12:00:00])
    end

    test "DateTime" do
      refute ~U[2021-01-01 12:00:00+00] |> Zeitvergleich.zeitgleich?(~U[2021-01-01 12:01:00+00])

      refute ~U[2021-01-01 12:00:00+00] |> Zeitvergleich.zeitgleich?(~U[2021-01-01 11:01:00+00])

      assert ~U[2021-01-01 12:00:00+00] |> Zeitvergleich.zeitgleich?(~U[2021-01-01 12:00:00+00])
    end

    test "Time" do
      refute ~T[12:00:00] |> Zeitvergleich.zeitgleich?(~T[12:01:00])
      refute ~T[12:00:00] |> Zeitvergleich.zeitgleich?(~T[11:01:00])
      assert ~T[12:00:00] |> Zeitvergleich.zeitgleich?(~T[12:00:00])
    end

    test "Date" do
      refute ~D[2021-06-18] |> Zeitvergleich.zeitgleich?(~D[2021-06-19])
      refute ~D[2021-06-18] |> Zeitvergleich.zeitgleich?(~D[2021-06-17])
      assert ~D[2021-06-18] |> Zeitvergleich.zeitgleich?(~D[2021-06-18])
    end
  end

  describe "frueher_als_oder_zeitgleich?/2" do
    test "Zeit" do
      assert ~G[2021-01-01 12:00:00]
             |> Zeitvergleich.frueher_als_oder_zeitgleich?(~G[2021-01-01 12:01:00])

      refute ~G[2021-01-01 12:00:00]
             |> Zeitvergleich.frueher_als_oder_zeitgleich?(~G[2021-01-01 11:01:00])

      assert ~G[2021-01-01 12:00:00]
             |> Zeitvergleich.frueher_als_oder_zeitgleich?(~G[2021-01-01 12:00:00])
    end

    test "NaiveDateTime" do
      assert ~N[2021-01-01 12:00:00]
             |> Zeitvergleich.frueher_als_oder_zeitgleich?(~N[2021-01-01 12:01:00])

      refute ~N[2021-01-01 12:00:00]
             |> Zeitvergleich.frueher_als_oder_zeitgleich?(~N[2021-01-01 11:01:00])

      assert ~N[2021-01-01 12:00:00]
             |> Zeitvergleich.frueher_als_oder_zeitgleich?(~N[2021-01-01 12:00:00])
    end

    test "DateTime" do
      assert ~U[2021-01-01 12:00:00+00]
             |> Zeitvergleich.frueher_als_oder_zeitgleich?(~U[2021-01-01 12:01:00+00])

      refute ~U[2021-01-01 12:00:00+00]
             |> Zeitvergleich.frueher_als_oder_zeitgleich?(~U[2021-01-01 11:01:00+00])

      assert ~U[2021-01-01 12:00:00+00]
             |> Zeitvergleich.frueher_als_oder_zeitgleich?(~U[2021-01-01 12:00:00+00])
    end

    test "Time" do
      assert ~T[12:00:00] |> Zeitvergleich.frueher_als_oder_zeitgleich?(~T[12:01:00])
      refute ~T[12:00:00] |> Zeitvergleich.frueher_als_oder_zeitgleich?(~T[11:01:00])
      assert ~T[12:00:00] |> Zeitvergleich.frueher_als_oder_zeitgleich?(~T[12:00:00])
    end

    test "Date" do
      assert ~D[2021-06-18] |> Zeitvergleich.frueher_als_oder_zeitgleich?(~D[2021-06-19])
      refute ~D[2021-06-18] |> Zeitvergleich.frueher_als_oder_zeitgleich?(~D[2021-06-17])
      assert ~D[2021-06-18] |> Zeitvergleich.frueher_als_oder_zeitgleich?(~D[2021-06-18])
    end
  end
end
