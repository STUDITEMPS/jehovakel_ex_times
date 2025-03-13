defmodule Shared.Week do
  defmodule InvalidWeekIndexError do
    defexception [:message]
  end

  defmodule InvalidWeekdayError do
    defexception [:message]
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    @derive Jason.Encoder
  end

  @enforce_keys [:year, :week]
  defstruct [:year, :week]

  @type t :: %__MODULE__{
          year: integer,
          week: integer
        }
  @type year :: Timex.Types.year()
  @type month :: Timex.Types.month()
  @type day_of_month :: Timex.Types.day()
  @type week_number :: Timex.Types.weeknum()
  @type weekday_number :: Timex.Types.weekday()
  @type weekday_name :: Timex.Types.weekday_name()

  @weekday_names [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  @doc ~S"""
  ## Examples

    iex> Week.new(2019, 7)
    {:ok, %Week{year: 2019, week: 7}}

    iex> Week.new!(2019, 7)
    %Week{year: 2019, week: 7}

    iex> Week.new(2021, 54)
    {:error, :invalid_week_index}

    iex> Week.new(2023, 0)
    {:error, :invalid_week_index}

    iex> Week.new(2019, -5)
    {:error, :invalid_week_index}

  """
  @spec new(year(), week_number()) :: {:ok, Shared.Week.t()} | {:error, :invalid_week_index}
  def new(year, week)
  def new(year, week) when week in 1..53, do: {:ok, %__MODULE__{year: year, week: week}}
  def new(_, _), do: {:error, :invalid_week_index}

  @doc ~S"""
  ## Examples

    iex> Week.new!(2019, 7)
    %Week{year: 2019, week: 7}

    iex> Week.new!(2019, -7)
    ** (Shared.Week.InvalidWeekIndexError) Week must be an integer between 1 and 53, but was -7

  """
  @spec new!(year(), week_number()) :: t() | no_return()
  def new!(year, week) do
    case new(year, week) do
      {:ok, week} ->
        week

      {:error, :invalid_week_index} ->
        raise InvalidWeekIndexError,
              "Week must be an integer between 1 and 53, but was " <> inspect(week)
    end
  end

  @doc """
  Returns the current week based on utc time.

  To get the week of a given date see `from_day!/1`
  """
  @spec utc_current :: t()
  def utc_current, do: from_day!(Date.utc_today())

  @doc """
  Returns the last week based on utc time
  """
  @spec utc_last :: t()
  def utc_last, do: previous(Date.utc_today())

  @doc """
  Returns the next week based on utc time
  """
  @spec utc_next :: t()
  def utc_next, do: next(Date.utc_today())

  @doc """
  Returns the current week based on local time

  To get the week of a given date see `from_day!/1`
  """
  @spec current :: t()
  def current, do: from_day!(Timex.local())

  @doc """
  Returns the previous week based on local time
  """
  @spec last :: t()
  def last, do: previous(Timex.local())

  @doc """
  Returns the previous week based on the given date datetime or week.

  ## Examples

      iex> Week.previous(~v[2018-20])
      ~v[2018-19]

      iex> Week.previous(~U[2024-01-06T00:00:00.000Z])
      ~v[2023-52]

      iex> Week.previous(~N[2024-01-08T23:59:59])
      ~v[2024-01]

      iex> Week.previous(DateTime.new!(~D[2024-01-08], ~T[00:30:00], "Europe/Berlin"))
      ~v[2024-01]
  """
  @spec previous :: t()
  @spec previous(Date.t() | DateTime.t() | NaiveDateTime.t() | t()) :: t()
  def previous(date \\ Timex.local())
  def previous(%__MODULE__{} = week), do: shift(week, -1)
  def previous(date), do: date |> Timex.shift(weeks: -1) |> from_day!()

  @doc """
  Returns the next week based on the given date datetime or week.
  ## Examples

      iex> Week.next(~v[2018-20])
      ~v[2018-21]

      iex> Week.next(~U[2024-01-06T00:00:00.000Z])
      ~v[2024-02]

      iex> Week.next(~N[2024-01-07T23:59:59])
      ~v[2024-02]

      iex> Week.next(DateTime.new!(~D[2024-01-08], ~T[00:30:00], "Europe/Berlin"))
      ~v[2024-03]
  """
  @spec next :: t()
  @spec next(Date.t() | DateTime.t() | NaiveDateTime.t() | t()) :: t()
  def next(date \\ Timex.local())
  def next(%__MODULE__{} = week), do: shift(week, 1)
  def next(date), do: date |> Timex.shift(weeks: 1) |> from_day!()

  @doc ~S"""
  ## Examples:

    iex> Week.from_day(%Date{year: 2018, month: 5, day: 17})
    {:ok, ~v[2018-20]}

    iex> Week.from_day(%Date{year: 2018, month: 13, day: 17})
    {:error, :invalid_week_index}

    iex> Week.from_day(%Date{year: 2018, month: 0, day: 17})
    {:error, :invalid_week_index}

    iex> Week.from_day(%Date{year: 2018, month: -1, day: 17})
    {:error, :invalid_week_index}

  """
  @spec from_day(Date.t() | DateTime.t() | NaiveDateTime.t()) :: {:ok, Shared.Week.t()}
  def from_day(date) do
    {year, week} = Timex.iso_week(date)
    new(year, week)
  end

  @spec from_day!(Date.t() | DateTime.t() | NaiveDateTime.t()) :: Shared.Week.t()
  def from_day!(date) do
    {year, week} = Timex.iso_week(date)
    new!(year, week)
  end

  @doc ~S"""
  ## Examples:

    iex> Week.parse("2019-W10")
    {:ok, %Week{year: 2019, week: 10}}

    iex> Week.parse("2019-W1")
    {:ok, %Week{year: 2019, week: 1}}

    iex> Week.parse("2019-W01")
    {:ok, %Week{year: 2019, week: 1}}

    iex> Week.parse("2019-W00")
    {:error, :invalid_week_index}

    iex> Week.parse("2019-W54")
    {:error, :invalid_week_index}

  """
  def parse(<<year::bytes-size(4)>> <> "-W" <> <<week::bytes-size(2)>>) do
    new(String.to_integer(year), String.to_integer(week))
  end

  def parse(<<year::bytes-size(4)>> <> "-W" <> <<week::bytes-size(1)>>) do
    new(String.to_integer(year), String.to_integer(week))
  end

  @doc ~S"""
  Same as &Week.weekday(&1, :monday)

  ## Examples

    iex> Week.first_day(@third_week_of_2018)
    %Date{year: 2018, month: 1, day: 15}

  """
  @spec first_day(Shared.Week.t()) :: Date.t()
  def first_day(%__MODULE__{year: year, week: week}) do
    Timex.from_iso_triplet({year, week, 1})
  end

  @doc ~S"""
  Returns the Date of a week's weekday.

  ## Examples

    iex> Week.weekday(@third_week_of_2018, 7)
    %Date{year: 2018, month: 1, day: 21}

    iex> Week.weekday(@third_week_of_2018, 1)
    %Date{year: 2018, month: 1, day: 15}

    iex> Week.weekday(@third_week_of_2018, :monday)
    %Date{year: 2018, month: 1, day: 15}

  """
  @spec weekday(Shared.Week.t(), weekday_number() | weekday_name()) :: Date.t() | {:error, any()}
  def weekday(%__MODULE__{year: year, week: week}, weekday_number)
      when is_integer(weekday_number) do
    Timex.from_iso_triplet({year, week, weekday_number})
  end

  def weekday(%__MODULE__{} = week, weekday_name) when weekday_name in @weekday_names do
    weekday_number = Timex.day_to_num(weekday_name)
    weekday(week, weekday_number)
  end

  def weekday(%__MODULE__{}, weekday) do
    raise InvalidWeekdayError,
          "Weekday must be an integer of range 1..7 or a valid weekday name of type atom, but was " <>
            inspect(weekday)
  end

  @doc ~S"""
  Returns a DateRange spanning the week. Date.Range is always end-inclusive.

  ## Examples

    iex> Shared.Week.to_range(@third_week_of_2018)
    Date.range(~D[2018-01-15], ~D[2018-01-21])

  """
  @spec to_range(Shared.Week.t()) :: DateRange.t()
  def to_range(%__MODULE__{} = week) do
    {first_day, last_day} = to_dates(week)

    Date.range(first_day, last_day)
  end

  @doc ~S"""
  Returns an end-exclusive Datetime Interval spanning the whole week.
  ## Examples

    iex> Shared.Week.to_datetime_interval(@third_week_of_2018)
    %Timex.Interval{
      from: ~N[2018-01-15 00:00:00],
      left_open: false,
      right_open: true,
      step: [seconds: 1],
      until: ~N[2018-01-22 00:00:00]
    }

  """
  @spec to_datetime_interval(Shared.Week.t()) :: Shared.Zeitperiode.t()
  def to_datetime_interval(%__MODULE__{} = week) do
    {first_day, last_day} = to_dates(week)

    {:ok, from} = NaiveDateTime.new(first_day, ~T[00:00:00])
    {:ok, until} = NaiveDateTime.new(Date.add(last_day, 1), ~T[00:00:00])

    Shared.Zeitperiode.new(from, until)
  end

  @doc ~S"""
  Returns first and last day of the week as a Date Tuple.

  ## Examples

    iex> Shared.Week.to_dates(@third_week_of_2018)
    {~D[2018-01-15], ~D[2018-01-21]}

  """
  @spec to_dates(Shared.Week.t()) :: {Date.t(), Date.t()}
  def to_dates(%__MODULE__{year: year, week: week}) do
    first_day = Timex.from_iso_triplet({year, week, 1})
    last_day = Timex.from_iso_triplet({year, week, 7})

    {first_day, last_day}
  end

  @doc ~S"""
  ## Examples:

    iex> @third_week_of_2018 |> Week.earlier_than?(@third_week_of_2019)
    true

    iex> @third_week_of_2018 |> Week.earlier_than?(@third_week_of_2017)
    false

    iex> @third_week_of_2018 |> Week.earlier_than?(@fourth_week_of_2018)
    true

    iex> @third_week_of_2018 |> Week.earlier_than?(@second_week_of_2019)
    true

    iex> @third_week_of_2018 |> Week.earlier_than?(@third_week_of_2018)
    false

    iex> @third_week_of_2018 |> Week.earlier_than?(@second_week_of_2018)
    false

  """
  @spec earlier_than?(Shared.Week.t(), Shared.Week.t()) :: boolean()
  def earlier_than?(%__MODULE__{} = week, %__MODULE__{} = other_week) do
    week |> Shared.Zeitvergleich.frueher_als?(other_week)
  end

  @doc ~S"""
  Returns true if the week `week` is before the week `other_week`.
  """
  @spec before?(Shared.Week.t(), Shared.Week.t()) :: boolean()
  defdelegate before?(week, other_week), to: Shared.Zeitvergleich, as: :frueher_alz?

  @doc ~S"""
  Returns true if the week `week` is after the week `other_week`.

  ## Examples:

    iex> ~v[2025-03] |> Week.after?(~v[2025-01])
    true

    iex> ~v[2024-52] |> Week.after?(~v[2025-01])
    false
  """
  @spec after?(Shared.Week.t(), Shared.Week.t()) :: boolean()
  def after?(%__MODULE__{} = week, %__MODULE__{} = other_week),
    do: not Shared.Zeitvergleich.frueher_als_oder_zeitgleich?(week, other_week)

  @doc ~S"""
  ## Examples:

    iex> @third_week_of_2018 |> Week.equal_or_earlier_than?(@third_week_of_2019)
    true

    iex> @third_week_of_2018 |> Week.equal_or_earlier_than?(@third_week_of_2017)
    false

    iex> @third_week_of_2018 |> Week.equal_or_earlier_than?(@fourth_week_of_2018)
    true

    iex> @third_week_of_2018 |> Week.equal_or_earlier_than?(@second_week_of_2019)
    true

    iex> @third_week_of_2018 |> Week.equal_or_earlier_than?(@third_week_of_2018)
    true

    iex> @third_week_of_2018 |> Week.equal_or_earlier_than?(@second_week_of_2018)
    false

  """
  @spec equal_or_earlier_than?(Shared.Week.t(), Shared.Week.t()) :: boolean()
  def equal_or_earlier_than?(%__MODULE__{} = week, %__MODULE__{} = other_week) do
    week |> Shared.Zeitvergleich.frueher_als_oder_zeitgleich?(other_week)
  end

  @doc ~S"""
  Returns the week advanced by the provided number of weeks from the starting week.

  ## Examples

    iex> Week.shift(~v[2020-05], 2)
    %Week{year: 2020, week: 7}

    iex> Week.shift(~v[2021-05], -5)
    %Week{year: 2020, week: 53}

  """
  @spec shift(Shared.Week.t(), integer()) :: Shared.Week.t()
  def shift(%__MODULE__{} = week, amount_of_weeks) when is_integer(amount_of_weeks) do
    week |> first_day() |> Timex.shift(weeks: amount_of_weeks) |> from_day!()
  end

  @doc ~S"""
  Returns the number of weeks from `from_week` to `to_week`.

  ## Examples

    iex> Week.diff(~v[2025-02], ~v[2025-01])
    1

    iex> Week.diff(~v[2025-01], ~v[2025-01])
    0

    iex> Week.diff(~v[2025-01], ~v[2025-02])
    -1

    iex> Week.diff(~v[2025-01], ~v[2024-01])
    52
  """
  @spec diff(to_week :: Shared.Week.t(), from_week :: Shared.Week.t()) :: integer()
  def diff(%__MODULE__{} = to_week, %__MODULE__{} = from_week) do
    Integer.floor_div(Date.diff(first_day(to_week), first_day(from_week)), 7)
  end

  @doc ~S"""
  Returns the Week of the year or Date if a weekday is specified as well

  ## Examples

    iex> ~v[2018-05]
    %Week{year: 2018, week: 5}

    iex> ~v[2018-5]
    %Week{year: 2018, week: 5}

    iex> ~v[2018-W05-1]
    ~D[2018-01-29]

  """

  # ~w geht nicht, v sieht so ähnlich aus und wir müssen nur nach Skandinavien auswandern
  @spec sigil_v(binary(), keyword()) :: t() | Date.t()
  def sigil_v(string, opts)

  def sigil_v(
        <<year::bytes-size(4)>> <>
          "-W" <>
          <<week::bytes-size(2)>> <>
          "-" <> <<weekday::bytes-size(1)>>,
        []
      ) do
    with {:ok, week} <- new(String.to_integer(year), String.to_integer(week)),
         %Date{} = date <- weekday(week, String.to_integer(weekday)) do
      date
    else
      _ -> raise "Invalid week date"
    end
  end

  def sigil_v(string, []) do
    string = string |> String.split("-") |> Enum.join("-W")

    with {:ok, week} <- parse(string) do
      week
    else
      _ -> raise "Invalid week"
    end
  end

  @doc ~S"""
  ## Examples

    iex> ~v[2018-05] |> Week.compare(~v[2018-08])
    :lt

    iex> ~v[2018-05] |> Week.compare(~v[2017-42])
    :gt

    iex> ~v[2018-42] |> Week.compare(~v[2018-42])
    :eq

  """
  @spec compare(Shared.Week.t(), Shared.Week.t()) :: :lt | :gt | :eq
  def compare(%__MODULE__{year: year, week: week}, %__MODULE__{year: other_year, week: other_week}) do
    cond do
      year == other_year && week == other_week -> :eq
      year < other_year || (year == other_year && week < other_week) -> :lt
      year > other_year || (year == other_year && week > other_week) -> :gt
    end
  end

  defimpl String.Chars, for: Shared.Week do
    alias Shared.Week

    def to_string(%Week{year: year, week: week}) do
      "#{year}-W#{format_week(week)}"
    end

    defp format_week(week) do
      week
      |> Integer.to_string()
      |> String.pad_leading(2, "0")
    end
  end

  defimpl Inspect, for: Shared.Week do
    alias Shared.Week

    def inspect(%Week{year: year, week: week} = week_struct, _)
        when is_integer(year) and is_integer(week) do
      "~v[" <> to_string(week_struct) <> "]"
    end

    def inspect(%Week{year: year, week: week}, _) do
      "#Week" <>
        "<year: " <>
        Inspect.inspect(year, %Inspect.Opts{}) <>
        ", week: " <> Inspect.inspect(week, %Inspect.Opts{}) <> ">"
    end
  end
end
