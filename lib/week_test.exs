defmodule Shared.WeekTest do
  alias Shared.Week

  use ExUnit.Case, async: true

  @eleventh_week_of_2016 %Week{year: 2016, week: 11}
  @third_week_of_2017 %Week{year: 2017, week: 3}
  @second_week_of_2018 %Week{year: 2018, week: 2}
  @third_week_of_2018 %Week{year: 2018, week: 3}
  @fourth_week_of_2018 %Week{year: 2018, week: 4}
  @second_week_of_2019 %Week{year: 2019, week: 2}
  @third_week_of_2019 %Week{year: 2019, week: 3}
  @fifth_week_of_2020 %Week{year: 2020, week: 5}

  import Week

  doctest Week

  describe "given the fifth week of 2020" do
    test "its string representation is 2020-05" do
      assert to_string(@fifth_week_of_2020) == "2020-W05"
    end
  end

  describe "given the eleventh week of 2016" do
    test "its string representation is 2016-11" do
      assert to_string(@eleventh_week_of_2016) == "2016-W11"
    end
  end
end
