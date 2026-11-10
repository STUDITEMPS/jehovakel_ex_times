defmodule Shared.ZeitraumProtokollTest do
  use ExUnit.Case, async: true

  alias Shared.ZeitraumProtokoll

  describe "derive with default options (start and ende keys)" do
    defmodule DefaultKeys do
      @derive ZeitraumProtokoll
      defstruct [:start, :ende]
    end

    test "converts struct with default start/ende keys to date range" do
      start_date = ~D[2024-01-01]
      end_date = ~D[2024-01-31]

      struct = %DefaultKeys{start: start_date, ende: end_date}

      assert Date.range(~D[2024-01-01], ~D[2024-01-31]) == ZeitraumProtokoll.zeitraum(struct)
    end
  end

  describe "derive with both custom start and ende keys" do
    defmodule CustomKeys do
      @derive {ZeitraumProtokoll, beginn: :from_date, ende: :to_date}
      defstruct [:from_date, :to_date]
    end

    test "converts struct with both custom keys to date range" do
      start_date = ~D[2024-04-01]
      end_date = ~D[2024-04-30]

      struct = %CustomKeys{from_date: start_date, to_date: end_date}

      assert Date.range(~D[2024-04-01], ~D[2024-04-30]) == ZeitraumProtokoll.zeitraum(struct)
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

      result = ZeitraumProtokoll.zeitraum(struct)

      assert result == interval
      assert result.from == ~N[2024-05-01 00:00:00]
      assert result.until == ~N[2024-06-01 00:00:00]
    end

    test "returns interval as-is without creating a new one" do
      interval = Shared.Zeitperiode.new(~D[2024-06-01], ~D[2024-06-30])
      struct = %WithZeitraumKey{interval: interval, other_field: "test"}

      result = ZeitraumProtokoll.zeitraum(struct)

      # Should be the exact same interval, not a new one
      assert result == interval
    end
  end

  describe "error handling" do
    test "raises when required default keys are missing" do
      assert_raise ArgumentError, ~r/^:beginn is not a key/, fn ->
        defmodule MissingDefaultKeys do
          @derive ZeitraumProtokoll
          defstruct [:other_field]
        end
      end
    end

    test "raises when required custom keys are missing" do
      assert_raise ArgumentError, ~r/^:custom_start is not a key/, fn ->
        defmodule MissingCustomKeys do
          @derive {ZeitraumProtokoll, beginn: :custom_start}
          defstruct [:other_field]
        end
      end
    end

    test "raises when zeitraum key is missing" do
      assert_raise ArgumentError, ~r/^:missing_key is not a key/, fn ->
        defmodule MissingZeitraumKey do
          @derive {ZeitraumProtokoll, zeitraum: :missing_key}
          defstruct [:other_field]
        end
      end
    end
  end
end
