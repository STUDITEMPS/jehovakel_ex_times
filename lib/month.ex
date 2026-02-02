defmodule Shared.Month do
  defmodule InvalidMonthIndexError do
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
    ** (Shared.Month.InvalidMonthIndexError) Month must be an integer between 1 and 12, but was -7

  """
  def new!(year, month) do
    case new(year, month) do
      {:ok, month} ->
        month

      {:error, :invalid_month_index} ->
        raise InvalidMonthIndexError,
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
    ** (Shared.Month.InvalidMonthIndexError) Month must be an integer between 1 and 12, but was 13

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

    iex> Month.parse!("2019-10")
    %Month{year: 2019, month: 10}

    iex> Month.parse!("2019-13")
    ** (Shared.Month.InvalidMonthIndexError) Invalid month index: 2019-13

    iex> Month.parse!("foo")
    ** (Shared.Month.InvalidMonthIndexError) Invalid month format: foo

  """
  def parse!(string) do
    case parse(string) do
      {:ok, month} ->
        month

      {:error, :invalid_month_index} ->
        raise InvalidMonthIndexError, "Invalid month index: #{string}"

      {:error, :invalid_month_format} ->
        raise InvalidMonthIndexError, "Invalid month format: #{string}"
    end
  end

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
  Returns an end-exclusive Datetime Interval spanning the whole month.

  ## Examples

    iex> Shared.Month.to_datetime_interval(@third_month_of_2018)
    %Timex.Interval{
      from: ~N[2018-03-01 00:00:00],
      left_open: false,
      right_open: true,
      step: [seconds: 1],
      until: ~N[2018-04-01 00:00:00]
    }

  """
  @spec to_datetime_interval(t()) :: Shared.Zeitperiode.t()
  def to_datetime_interval(%__MODULE__{} = month) do
    {first_day, last_day} = to_dates(month)

    {:ok, from} = NaiveDateTime.new(first_day, ~T[00:00:00])
    {:ok, until} = NaiveDateTime.new(Date.add(last_day, 1), ~T[00:00:00])

    Shared.Zeitperiode.new(from, until)
  end

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
  Returns the month advanced by the provided number of months from the starting month.

  ## Examples

    iex> Month.shift(~m[2020-05], 2)
    %Month{year: 2020, month: 7}

    iex> Month.shift(~m[2020-05], -5)
    %Month{year: 2019, month: 12}

    iex> Month.shift(~m[2018-03], 9)
    %Month{year: 2018, month: 12}

    iex> Month.shift(~m[2018-03], 10)
    %Month{year: 2019, month: 1}

    iex> Month.shift(~m[2018-03], 0)
    %Month{year: 2018, month: 3}

  """
  @spec shift(t(), integer()) :: t()
  def shift(%__MODULE__{} = month, 0), do: month

  def shift(%__MODULE__{year: year, month: month}, amount_of_months) when is_integer(amount_of_months) do
    new_year = year + div(amount_of_months, 12)
    new_month = month + rem(amount_of_months, 12)

    cond do
      new_month > 12 -> new!(new_year + 1, new_month - 12)
      new_month < 1 -> new!(new_year - 1, new_month + 12)
      :otherwise -> new!(new_year, new_month)
    end
  end

  @doc ~S"""
  Deprecated: Use `shift/2` instead.
  """
  @deprecated "Use shift/2 instead"
  @spec add(t(), integer()) :: t()
  def add(month, amount), do: shift(month, amount)

  @doc ~S"""
  Returns the number of months from `from_month` to `to_month`.

  ## Examples

    iex> Month.diff(~m[2025-02], ~m[2025-01])
    1

    iex> Month.diff(~m[2025-01], ~m[2025-01])
    0

    iex> Month.diff(~m[2025-01], ~m[2025-02])
    -1

    iex> Month.diff(~m[2025-01], ~m[2024-01])
    12

  """
  @spec diff(to_month :: t(), from_month :: t()) :: integer()
  def diff(%__MODULE__{year: to_year, month: to_month}, %__MODULE__{
        year: from_year,
        month: from_month
      }) do
    12 * (to_year - from_year) + to_month - from_month
  end

  @doc ~S"""
  Returns true if the first month is before the second month.

  ## Examples:

    iex> Month.before?(~m[2018-03], ~m[2019-03])
    true

    iex> Month.before?(~m[2018-03], ~m[2017-03])
    false

    iex> Month.before?(~m[2018-03], ~m[2018-04])
    true

    iex> Month.before?(~m[2018-03], ~m[2018-03])
    false

  """
  @spec before?(t(), t()) :: boolean()
  def before?(%__MODULE__{year: year, month: month}, %__MODULE__{
        year: other_year,
        month: other_month
      }) do
    year < other_year || (year == other_year && month < other_month)
  end

  @doc ~S"""
  Deprecated: Use `before?/2` instead.
  """
  @deprecated "Use before?/2 instead"
  def earlier_than?(month, other_month), do: before?(month, other_month)

  @doc ~S"""
  Returns true if the month `month` is after the month `other_month`.

  ## Examples:

    iex> ~m[2025-03] |> Month.after?(~m[2025-01])
    true

    iex> ~m[2024-12] |> Month.after?(~m[2025-01])
    false

    iex> ~m[2025-01] |> Month.after?(~m[2025-01])
    false

  """
  @spec after?(t(), t()) :: boolean()
  def after?(%__MODULE__{} = month, %__MODULE__{} = other_month) do
    not equal_or_earlier_than?(month, other_month)
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
    month == other_month || before?(month, other_month)
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
    if before?(first, second) do
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
  @spec range(t(), t() | pos_integer()) :: Month.Range.t()
  defdelegate range(start, stop_or_size), to: Shared.Month.Range, as: :new

  @doc """
  Creates a range of months from start to stop in the given direction.

  ## Example

      iex> Month.range(@third_month_of_2019, @third_month_of_2018, :backward)
      %Shared.Month.Range{direction: :backward, size: 13, start: ~m[2019-03]}
  """
  @spec range(t(), t() | pos_integer(), Shared.Month.Range.direction()) :: Shared.Month.Range.t()
  defdelegate range(start, stop_or_size, direction), to: Shared.Month.Range, as: :new

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
