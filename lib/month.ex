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

    iex> Month.from_day(~U[2024-01-06T00:00:00.000Z])
    {:ok, ~m[2024-01]}

    iex> Month.from_day(~N[2024-01-31T23:59:59])
    {:ok, ~m[2024-01]}

    iex> Month.from_day(DateTime.new!(~D[2024-02-01], ~T[00:30:00], "Europe/Berlin"))
    {:ok, ~m[2024-02]}

    iex> Month.from_day(%Date{year: 2018, month: 5, day: 17})
    {:ok, ~m[2018-05]}

    iex> Month.from_day(%Date{year: 2018, month: 13, day: 17})
    {:error, :invalid_month_index}

    iex> Month.from_day(%Date{year: 2018, month: 0, day: 17})
    {:error, :invalid_month_index}

    iex> Month.from_day(%Date{year: 2018, month: -1, day: 17})
    {:error, :invalid_month_index}

  """
  @spec from_day(Date.t() | DateTime.t() | NaiveDateTime.t()) ::
          {:ok, t()} | {:error, :invalid_month_index}
  def from_day(%{year: year, month: month}), do: new(year, month)

  @doc ~S"""
  ## Examples

    iex> Month.from_day!(~U[2024-01-06T00:00:00.000Z])
    ~m[2024-01]

    iex> Month.from_day!(~N[2024-01-31T23:59:59])
    ~m[2024-01]

    iex> Month.from_day!(DateTime.new!(~D[2024-02-01], ~T[00:30:00], "Europe/Berlin"))
    ~m[2024-02]

    iex> Month.from_day!(%Date{year: 2018, month: 5, day: 17})
    %Month{year: 2018, month: 5}

    iex> Month.from_day!(%Date{year: 2018, month: 13, day: 17})
    ** (Shared.Month.InvalidMonthIndex) Month must be an integer between 1 and 12, but was 13

  """
  @spec from_day!(Date.t() | DateTime.t() | NaiveDateTime.t()) :: t()
  def from_day!(%{year: year, month: month}), do: new!(year, month)

  @doc """
  Returns the current month based on utc time.

  To get the month of a given date see `from_day!/1`
  """
  @spec utc_current :: t()
  def utc_current, do: from_day!(Date.utc_today())

  @doc """
  Returns the last month based on utc time
  """
  @spec utc_last :: t()
  def utc_last, do: previous(Date.utc_today())

  @doc """
  Returns the next month based on utc time
  """
  @spec utc_next :: t()
  def utc_next, do: next(Date.utc_today())

  @doc """
  Returns the current month based on local time

  To get the month of a given date see `from_day!/1`
  """
  @spec current :: t()
  def current, do: from_day!(Timex.local())

  @doc """
  Returns the previous month based on local time
  """
  @spec last :: t()
  def last, do: previous(Timex.local())

  @doc """
  Returns the previous month based on the given date datetime or month.

  ## Examples

      iex> Month.previous(~m[2018-10])
      ~m[2018-09]

      iex> Month.previous(~U[2024-01-06T00:00:00.000Z])
      ~m[2023-12]

      iex> Month.previous(~N[2024-01-31T23:59:59])
      ~m[2023-12]

      iex> Month.previous(DateTime.new!(~D[2024-02-01], ~T[00:30:00], "Europe/Berlin"))
      ~m[2024-01]
  """
  @spec previous :: t()
  @spec previous(Date.t() | DateTime.t() | NaiveDateTime.t() | t()) :: t()
  def previous(date \\ Timex.local())
  def previous(%__MODULE__{} = month), do: add(month, -1)
  def previous(date), do: date |> from_day!() |> add(-1)

  @doc """
  Returns the next month based on the given date datetime or month.

  ## Examples

      iex> Month.next(~m[2018-10])
      ~m[2018-11]

      iex> Month.next(~U[2024-01-06T00:00:00.000Z])
      ~m[2024-02]

      iex> Month.next(~N[2024-01-31T23:59:59])
      ~m[2024-02]

      iex> Month.next(DateTime.new!(~D[2024-02-01], ~T[00:30:00], "Europe/Berlin"))
      ~m[2024-03]
  """
  @spec next :: t()
  @spec next(Date.t() | DateTime.t() | NaiveDateTime.t() | t()) :: t()
  def next(date \\ Timex.local())
  def next(%__MODULE__{} = month), do: add(month, 1)
  def next(date), do: date |> from_day!() |> add(1)

  @doc """
  Returns the first month of the year the given struct belongs to.

  ## Example

    iex> Month.beginning_of_year(~m[2018-10])
    ~m[2018-01]

    iex> Month.beginning_of_year(~U[2024-01-06T00:00:00.000Z])
    ~m[2024-01]

    iex> Month.beginning_of_year(~N[2024-03-31T23:59:59])
    ~m[2024-01]

    iex> Month.beginning_of_year(~D[2024-02-01])
    ~m[2024-01]
  """
  @spec beginning_of_year(t() | DateTime.t() | NaiveDateTime.t() | Date.t()) :: t()
  def beginning_of_year(%{year: year}), do: new!(year, 1)

  @doc """
  Returns the first month of the year the given struct belongs to.

  ## Example

    iex> Month.end_of_year(~m[2018-10])
    ~m[2018-12]

    iex> Month.end_of_year(~U[2024-01-06T00:00:00.000Z])
    ~m[2024-12]

    iex> Month.end_of_year(~N[2024-03-31T23:59:59])
    ~m[2024-12]

    iex> Month.end_of_year(~D[2024-02-01])
    ~m[2024-12]
  """
  @spec end_of_year(t() | DateTime.t() | NaiveDateTime.t() | Date.t()) :: t()
  def end_of_year(%{year: year}), do: new!(year, 12)

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
  def first_day(%__MODULE__{} = month), do: to_date!(month, 1)

  @doc ~S"""
  ## Examples

    iex> Month.last_day(@third_month_of_2018)
    %Date{year: 2018, month: 3, day: 31}

  """
  def last_day(%__MODULE__{year: year, month: month}), do: Timex.end_of_month(year, month)

  @doc ~S"""
  ## Examples

    iex> Month.to_range(@third_month_of_2018)
    Date.range(~D[2018-03-01], ~D[2018-03-31])

  """
  def to_range(%__MODULE__{} = month), do: Date.range(first_day(month), last_day(month))

  @doc ~S"""
  ## Examples

    iex> Month.to_dates(@third_month_of_2018)
    {~D[2018-03-01], ~D[2018-03-31]}

  """
  def to_dates(%__MODULE__{} = month), do: {first_day(month), last_day(month)}

  @doc ~S"""
  ## Examples

    iex> Month.to_date(@third_month_of_2018, 1)
    {:ok, ~D[2018-03-01]}

    iex> Month.to_date(@third_month_of_2018, 32)
    {:error, :invalid_date}

  """
  def to_date(%__MODULE__{year: year, month: month}, day) when is_integer(day),
    do: Date.new(year, month, day)

  @doc ~S"""
  ## Examples

    iex> Month.to_date!(@third_month_of_2018, 1)
    ~D[2018-03-01]
  """
  def to_date!(%__MODULE__{year: year, month: month}, day) when is_integer(day),
    do: Date.new!(year, month, day)

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
  @spec add(t(), integer()) :: t()
  def add(%__MODULE__{} = month, 0), do: month

  def add(%__MODULE__{year: year, month: month}, months_to_add) when is_integer(months_to_add) do
    new_year = year + div(months_to_add, 12)
    new_month = month + rem(months_to_add, 12)

    cond do
      new_month > 12 -> new!(new_year + 1, new_month - 12)
      new_month < 1 -> new!(new_year - 1, new_month + 12)
      :otherwise -> new!(new_year, new_month)
    end
  end

  @doc """
  Returns the number of months you need to add to first_month to arrive at second_month.
  """
  @spec diff(first_month :: t(), second_month :: t()) :: integer()
  def diff(%__MODULE__{year: first_year, month: first_month}, %__MODULE__{
        year: second_year,
        month: second_month
      }) do
    12 * (second_year - first_year) + second_month - first_month
  end

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
  def compare(%__MODULE__{} = month, month), do: :eq

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

  @doc """
  Creates a range of months from start to stop.

  ## Example

      iex> Month.range(@third_month_of_2018, @third_month_of_2019)
      %Shared.Month.Range{direction: :forward, size: 13, start: ~m[2018-03]}
  """
  @spec range(t(), t()) :: Month.Range.t()
  defdelegate range(start, stop), to: Shared.Month.Range, as: :new

  @doc """
  Creates a range of months from start to stop in the given direction.

  ## Example

      iex> Month.range(@third_month_of_2019, @third_month_of_2018, :backward)
      %Shared.Month.Range{direction: :backward, size: 13, start: ~m[2019-03]}
  """
  @spec range(t(), t(), Shared.Month.Range.direction()) :: Shared.Month.Range.t()
  defdelegate range(start, stop, direction), to: Shared.Month.Range, as: :new

  @doc ~S"""
  ## Examples

    iex> ~m[2018-05]
    %Month{year: 2018, month: 5}

  """
  defmacro sigil_m(month_string, opts)

  defmacro sigil_m({:<<>>, _, [string]}, []) do
    with {:ok, month} <- parse(string) do
      Macro.escape(month)
    else
      _ -> raise "Invalid month"
    end
  end

  defmacro sigil_m(string, []) do
    quote do
      with {:ok, month} <- parse(unquote(string)) do
        month
      else
        _ -> raise "Invalid month"
      end
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
