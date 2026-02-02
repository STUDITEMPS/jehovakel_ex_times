defmodule Shared.MonthTest do
  alias Shared.Month

  use ExUnit.Case, async: true

  @eleventh_month_of_2016 %Month{year: 2016, month: 11}
  @third_month_of_2017 %Month{year: 2017, month: 3}
  @second_month_of_2018 %Month{year: 2018, month: 2}
  @third_month_of_2018 %Month{year: 2018, month: 3}
  @fourth_month_of_2018 %Month{year: 2018, month: 4}
  @second_month_of_2019 %Month{year: 2019, month: 2}
  @third_month_of_2019 %Month{year: 2019, month: 3}
  @fifth_month_of_2020 %Month{year: 2020, month: 5}

  import Month

  doctest Month

  describe "sigil_m" do
    test "can be used in matches" do
      assert ~m[2020-05] = %Month{year: 2020, month: 5}
    end
  end

  describe "given the fifth month of 2020" do
    test "its string representation is 2020-05" do
      assert to_string(@fifth_month_of_2020) == "2020-05"
    end
  end

  describe "given the eleventh month of 2016" do
    test "its string representation is 2016-11" do
      assert to_string(@eleventh_month_of_2016) == "2016-11"
    end
  end

  test "compare/2" do
    # Monat ist größer, Jahr größer, kleiner, gleich
    assert @third_month_of_2019 |> Month.compare(@second_month_of_2018) == :gt
    assert @third_month_of_2018 |> Month.compare(@second_month_of_2019) == :lt
    assert @third_month_of_2019 |> Month.compare(@second_month_of_2019) == :gt

    # Monat ist kleiner, Jahr größer, kleiner, gleich
    assert @second_month_of_2019 |> Month.compare(@third_month_of_2018) == :gt
    assert @second_month_of_2018 |> Month.compare(@third_month_of_2019) == :lt
    assert @second_month_of_2018 |> Month.compare(@third_month_of_2018) == :lt

    # Monat ist gleich, Jahr größer, kleiner, gleich
    assert @second_month_of_2019 |> Month.compare(@second_month_of_2018) == :gt
    assert @second_month_of_2018 |> Month.compare(@second_month_of_2019) == :lt
    assert @second_month_of_2019 |> Month.compare(@second_month_of_2019) == :eq
  end

  describe "frueher_als?/2" do
    test "Month" do
      assert ~m[2021-01] |> Shared.Zeitvergleich.frueher_als?(~m[2021-03])
      refute ~m[2021-01] |> Shared.Zeitvergleich.frueher_als?(~m[2020-03])
      refute ~m[2021-01] |> Shared.Zeitvergleich.frueher_als?(~m[2021-01])
    end
  end

  describe "zeitgleich?/2" do
    test "Month" do
      refute ~m[2021-01] |> Shared.Zeitvergleich.zeitgleich?(~m[2021-03])
      refute ~m[2021-01] |> Shared.Zeitvergleich.zeitgleich?(~m[2020-03])
      assert ~m[2021-01] |> Shared.Zeitvergleich.zeitgleich?(~m[2021-01])
    end
  end

  describe "frueher_als_oder_zeitgleich?/2" do
    test "Month" do
      assert ~m[2021-01] |> Shared.Zeitvergleich.frueher_als_oder_zeitgleich?(~m[2021-03])
      refute ~m[2021-01] |> Shared.Zeitvergleich.frueher_als_oder_zeitgleich?(~m[2020-03])
      assert ~m[2021-01] |> Shared.Zeitvergleich.frueher_als_oder_zeitgleich?(~m[2021-01])
    end
  end

  describe "diff/2" do
    test "to_month is after from_month" do
      from_month = ~m[2025-01]
      to_month = Month.shift(from_month, 3)
      assert 3 = Month.diff(to_month, from_month)
    end

    test "to_month is before from_month" do
      from_month = ~m[2025-05]
      to_month = Month.shift(from_month, -4)
      assert -4 = Month.diff(to_month, from_month)
    end

    test "to_month and from_month are identical" do
      month = ~m[2025-01]
      assert 0 = Month.diff(month, month)
    end

    test "to_month is in previous year" do
      from_month = ~m[2025-01]
      to_month = ~m[2024-12]

      assert -1 = Month.diff(to_month, from_month)
    end

    test "to_month is in next year" do
      from_month = ~m[2025-01]
      to_month = Month.shift(from_month, 16)

      assert 16 = Month.diff(to_month, from_month)
    end

    test "months are years apart" do
      from_month = ~m[1993-03]
      to_month = ~m[2025-04]

      assert 32 * 12 + 1 == Month.diff(to_month, from_month)
    end
  end
end
