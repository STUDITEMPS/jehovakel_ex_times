defmodule Shared.ZeitraumProtokollTest do
  use ExUnit.Case, async: true

  alias Shared.ZeitraumProtokoll

  describe "derive with default options (start and ende keys)" do
    defmodule DefaultKeys do
      @derive ZeitraumProtokoll
      defstruct [:start, :ende]
    end

    test "converts struct with default start/ende keys to interval" do
      start_date = ~D[2024-01-01]
      end_date = ~D[2024-01-31]

      struct = %DefaultKeys{start: start_date, ende: end_date}
      interval = ZeitraumProtokoll.als_intervall(struct)

      assert interval.from == ~N[2024-01-01 00:00:00]
      assert interval.until == ~N[2024-02-01 00:00:00]
    end
  end

  describe "derive with both custom start and ende keys" do
    defmodule CustomKeys do
      @derive {ZeitraumProtokoll, start: :from_date, ende: :to_date}
      defstruct [:from_date, :to_date]
    end

    test "converts struct with both custom keys to interval" do
      start_date = ~D[2024-04-01]
      end_date = ~D[2024-04-30]

      struct = %CustomKeys{from_date: start_date, to_date: end_date}
      interval = ZeitraumProtokoll.als_intervall(struct)

      assert interval.from == ~N[2024-04-01 00:00:00]
      assert interval.until == ~N[2024-05-01 00:00:00]
    end
  end

  describe "derive with zeitraum option" do
    defmodule WithZeitraumKey do
      @derive {ZeitraumProtokoll, zeitraum: :interval}
      defstruct [:interval, :other_field]
    end

    test "fetches interval directly from zeitraum key" do
      interval = Shared.Zeitperiode.new(~D[2024-05-01], ~D[2024-05-31])
      struct = %WithZeitraumKey{interval: interval, other_field: "test"}

      result = ZeitraumProtokoll.als_intervall(struct)

      assert result == interval
      assert result.from == ~N[2024-05-01 00:00:00]
      assert result.until == ~N[2024-06-01 00:00:00]
    end

    test "returns interval as-is without creating a new one" do
      interval = Shared.Zeitperiode.new(~D[2024-06-01], ~D[2024-06-30])
      struct = %WithZeitraumKey{interval: interval, other_field: "test"}

      result = ZeitraumProtokoll.als_intervall(struct)

      # Should be the exact same interval, not a new one
      assert result == interval
    end
  end

  describe "error handling" do
    defmodule MissingDefaultKeys do
      @derive ZeitraumProtokoll
      defstruct [:other_field]
    end

    test "raises when required default keys are missing" do
      struct = %MissingDefaultKeys{other_field: "value"}

      assert_raise KeyError, fn ->
        ZeitraumProtokoll.als_intervall(struct)
      end
    end

    defmodule MissingCustomKeys do
      @derive {ZeitraumProtokoll, start: :custom_start}
      defstruct [:other_field]
    end

    test "raises when required custom keys are missing" do
      struct = %MissingCustomKeys{other_field: "value"}

      assert_raise KeyError, fn ->
        ZeitraumProtokoll.als_intervall(struct)
      end
    end

    defmodule MissingZeitraumKey do
      @derive {ZeitraumProtokoll, zeitraum: :missing_key}
      defstruct [:other_field]
    end

    test "raises when zeitraum key is missing" do
      struct = %MissingZeitraumKey{other_field: "value"}

      assert_raise KeyError, fn ->
        ZeitraumProtokoll.als_intervall(struct)
      end
    end
  end
end
