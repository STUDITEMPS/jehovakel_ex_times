defmodule Shared.Month do
  defmodule InvalidMonthIndex do
    defexception [:message]
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    @derive Jason.Encoder
  end

  @enforce_keys [:year, :month]
  defstruct [:year, :month]

  @type t :: %__MODULE__{
          year: integer,
          month: integer
        }

  @doc ~S"""
  ## Examples

    iex> Month.new(2019, 7)
    {:ok, %Month{year: 2019, month: 7}}

    iex> Month.new!(2019, 7)
    %Month{year: 2019, month: 7}

    iex> Month.new(2021, 13)
    {:error, :invalid_month_index}

    iex> Month.new(2023, 0)
    {:error, :invalid_month_index}

    iex> Month.new(2019, -5)
    {:error, :invalid_month_index}

  """
  def new(year, month)

  def new(year, month) when is_integer(year) and month in 1..12,
    do: {:ok, %__MODULE__{year: year, month: month}}

  def new(_, _), do: {:error, :invalid_month_index}

  @doc ~S"""
  ## Examples

    iex> Month.new!(2019, 7)
    %Month{year: 2019, month: 7}

    iex> Month.new!(2019, -7)
    ** (Shared.Month.InvalidMonthIndex) Month must be an integer between 1 and 12, but was -7

  """
  def new!(year, month) do
    case new(year, month) do
      {:ok, month} ->
        month

      {:error, :invalid_month_index} ->
        raise InvalidMonthIndex,
              "Month must be an integer between 1 and 12, but was " <> inspect(month)
    end
  end

  @doc ~S"""
  ## Examples:

    iex> Month.from_day(%Date{year: 2018, month: 5, day: 17})
    {:ok, ~m[2018-05]}

    iex> Month.from_day(%Date{year: 2018, month: 13, day: 17})
    {:error, :invalid_month_index}

    iex> Month.from_day(%Date{year: 2018, month: 0, day: 17})
    {:error, :invalid_month_index}

    iex> Month.from_day(%Date{year: 2018, month: -1, day: 17})
    {:error, :invalid_month_index}

  """
  def from_day(%Date{year: year, month: month}) do
    new(year, month)
  end

  @doc ~S"""
  ## Examples

    iex> Month.from_day!(%Date{year: 2018, month: 5, day: 17})
    %Month{year: 2018, month: 5}

    iex> Month.from_day!(%Date{year: 2018, month: 13, day: 17})
    ** (Shared.Month.InvalidMonthIndex) Month must be an integer between 1 and 12, but was 13

  """
  def from_day!(%Date{year: year, month: month}) do
    new!(year, month)
  end

  @doc ~S"""
  ## Examples:

    iex> Month.parse("2019-10")
    {:ok, %Month{year: 2019, month: 10}}

    iex> Month.parse("2019-1")
    {:ok, %Month{year: 2019, month: 1}}

    iex> Month.parse("2019-00")
    {:error, :invalid_month_index}

    iex> Month.parse("2019-13")
    {:error, :invalid_month_index}

    iex> Month.parse("foo")
    {:error, :invalid_month_format}
  """
  def parse(<<year::bytes-size(4)>> <> "-" <> <<month::bytes-size(2)>>) do
    new(String.to_integer(year), String.to_integer(month))
  end

  def parse(<<year::bytes-size(4)>> <> "-" <> <<month::bytes-size(1)>>) do
    new(String.to_integer(year), String.to_integer(month))
  end

  def parse(_str), do: {:error, :invalid_month_format}

  @doc ~S"""
  ## Examples

    iex> Month.name(@fifth_month_of_2020)
    "Mai"

  """
  def name(%__MODULE__{month: month}), do: Timex.month_name(month)

  @doc ~S"""
  ## Examples

    iex> Month.first_day(@third_month_of_2018)
    %Date{year: 2018, month: 3, day: 1}

  """
  def first_day(%__MODULE__{} = month) do
    {first_day, _} = to_dates(month)

    first_day
  end

  @doc ~S"""
  ## Examples

    iex> Month.last_day(@third_month_of_2018)
    %Date{year: 2018, month: 3, day: 31}

  """
  def last_day(%__MODULE__{} = month) do
    {_, last} = to_dates(month)
    last
  end

  @doc ~S"""
  ## Examples

    iex> Month.to_range(@third_month_of_2018)
    #DateRange<~D[2018-03-01], ~D[2018-03-31]>

  """
  def to_range(%__MODULE__{} = month) do
    {first_day, last_day} = to_dates(month)

    Date.range(first_day, last_day)
  end

  @doc ~S"""
  ## Examples

    iex> Month.to_dates(@third_month_of_2018)
    {~D[2018-03-01], ~D[2018-03-31]}

  """
  def to_dates(%__MODULE__{year: year, month: month}) do
    {:ok, first_day} = Date.new(year, month, 1)
    last_day = Timex.end_of_month(year, month)

    {first_day, last_day}
  end

  @doc ~S"""
  ## Examples

    iex> Month.add(@third_month_of_2018, 9)
    %Month{year: 2018, month: 12}

    iex> Month.add(@third_month_of_2018, 10)
    %Month{year: 2019, month: 1}

    iex> Month.add(@third_month_of_2018, 22)
    %Month{year: 2020, month: 1}

    iex> Month.add(@third_month_of_2018, -2)
    %Month{year: 2018, month: 1}

    iex> Month.add(@third_month_of_2018, -3)
    %Month{year: 2017, month: 12}

    iex> Month.add(@third_month_of_2018, -15)
    %Month{year: 2016, month: 12}

    iex> Month.add(@third_month_of_2018, 0)
    %Month{year: 2018, month: 3}

  """
  def add(%__MODULE__{year: year, month: month}, months_to_add) when is_integer(months_to_add) do
    zero_based_month_index = month - 1
    amount_of_months_since_anno_domini = year * 12 + zero_based_month_index + months_to_add
    {amount_of_years, amount_of_months} = divmod(amount_of_months_since_anno_domini, 12)
    %__MODULE__{year: amount_of_years, month: amount_of_months + 1}
  end

  defp divmod(dividend, divisor) do
    {div(dividend, divisor), mod(dividend, divisor)}
  end

  defp mod(x, y) when x > 0, do: rem(x, y)
  defp mod(x, y) when x < 0, do: rem(x, y) + y
  defp mod(0, _y), do: 0

  @doc ~S"""
  ## Examples:

    iex> @third_month_of_2018 |> Month.earlier_than?(@third_month_of_2019)
    true

    iex> @third_month_of_2018 |> Month.earlier_than?(@third_month_of_2017)
    false

    iex> @third_month_of_2018 |> Month.earlier_than?(@fourth_month_of_2018)
    true

    iex> @third_month_of_2018 |> Month.earlier_than?(@second_month_of_2019)
    true

    iex> @third_month_of_2018 |> Month.earlier_than?(@third_month_of_2018)
    false

    iex> @third_month_of_2018 |> Month.earlier_than?(@second_month_of_2018)
    false

  """
  def earlier_than?(%__MODULE__{year: year, month: month}, %__MODULE__{
        year: other_year,
        month: other_month
      }) do
    year < other_year || (year == other_year && month < other_month)
  end

  @doc ~S"""
  ## Examples:

    iex> @third_month_of_2018 |> Month.equal_or_earlier_than?(@third_month_of_2019)
    true

    iex> @third_month_of_2018 |> Month.equal_or_earlier_than?(@third_month_of_2017)
    false

    iex> @third_month_of_2018 |> Month.equal_or_earlier_than?(@fourth_month_of_2018)
    true

    iex> @third_month_of_2018 |> Month.equal_or_earlier_than?(@second_month_of_2019)
    true

    iex> @third_month_of_2018 |> Month.equal_or_earlier_than?(@third_month_of_2018)
    true

    iex> @third_month_of_2018 |> Month.equal_or_earlier_than?(@second_month_of_2018)
    false

  """
  def equal_or_earlier_than?(%__MODULE__{} = month, %__MODULE__{} = other_month) do
    month == other_month || earlier_than?(month, other_month)
  end

  @doc ~S"""
  ## Examples:

    iex> @third_month_of_2018 |> Month.compare(@third_month_of_2018)
    :eq

    iex> @second_month_of_2018 |> Month.compare(@third_month_of_2018)
    :lt

    iex> @fifth_month_of_2020 |> Month.compare(@third_month_of_2018)
    :gt
  """
  def compare(%__MODULE__{year: year, month: month}, %__MODULE__{
        year: year,
        month: month
      }),
      do: :eq

  def compare(%__MODULE__{} = first, %__MODULE__{} = second) do
    if first |> earlier_than?(second) do
      :lt
    else
      :gt
    end
  end

  def compare(%Date{} = first, %__MODULE__{} = second) do
    first |> from_day!() |> compare(second)
  end

  def compare(%__MODULE__{} = first, %Date{} = second) do
    compare(first, from_day!(second))
  end

  @doc ~S"""
  ## Examples

    iex> ~m[2018-05]
    %Month{year: 2018, month: 5}

  """
  def sigil_m(string, []) do
    with {:ok, month} <- parse(string) do
      month
    else
      _ -> raise "Invalid month"
    end
  end

  defimpl String.Chars, for: Shared.Month do
    alias Shared.Month

    def to_string(%Month{year: year, month: month}) do
      "#{year}-#{format_month(month)}"
    end

    defp format_month(month) do
      month
      |> Integer.to_string()
      |> String.pad_leading(2, "0")
    end
  end

  defimpl Inspect, for: Shared.Month do
    alias Shared.Month

    def inspect(%Month{year: year, month: month} = month_struct, _)
        when is_integer(year) and is_integer(month) do
      "~m[" <> to_string(month_struct) <> "]"
    end

    def inspect(%Month{year: year, month: month}, _) do
      "#Month" <>
        "<year: " <>
        Inspect.inspect(year, %Inspect.Opts{}) <>
        ", month: " <> Inspect.inspect(month, %Inspect.Opts{}) <> ">"
    end
  end

  defimpl Shared.Zeitvergleich, for: Shared.Month do
    alias Shared.Month

    def frueher_als?(%Month{} = self, %Month{} = other) do
      Month.compare(self, other) == :lt
    end

    def zeitgleich?(%Month{} = self, %Month{} = other) do
      Month.compare(self, other) == :eq
    end

    def frueher_als_oder_zeitgleich?(%Month{} = self, %Month{} = other) do
      self |> frueher_als?(other) || self |> zeitgleich?(other)
    end
  end
end
