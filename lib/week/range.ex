defmodule Shared.Week.Range do
  @moduledoc false
  alias Shared.Week

  @type direction :: :forward | :backward
  @type t :: %__MODULE__{
          start: Week.t(),
          size: non_neg_integer(),
          direction: direction()
        }

  defstruct [:start, :size, :direction]

  @doc """
  Creates a Week Range with the given start Week and end Week or size.

  ## Examples

    iex> Week.Range.forward(~v[2024-01], ~v[2024-03])
    %Week.Range{start: ~v[2024-01], size: 3, direction: :forward}

    iex> Week.Range.forward(~v[2024-01], 2)
    %Week.Range{start: ~v[2024-01], size: 2, direction: :forward}
  """
  @spec forward(Week.t(), Week.t() | (size :: pos_integer())) :: t()
  def forward(start, size_or_end), do: new(start, size_or_end, :forward)

  @doc """
  Creates a Week Range with the given start week and end week or size.

  ## Examples

    iex> Week.Range.backward(~v[2024-04], ~v[2024-02])
    %Week.Range{start: ~v[2024-04], size: 3, direction: :backward}

    iex> Week.Range.backward(~v[2024-05], 2)
    %Week.Range{start: ~v[2024-05], size: 2, direction: :backward}
  """
  @spec backward(Week.t(), Week.t() | (size :: pos_integer())) :: t()
  def backward(start, size_or_end), do: new(start, size_or_end, :backward)

  @doc """
  Creates a Week Range with the given start Week and end Week or size.

  ## Examples

    iex> Week.Range.forward(~v[2024-01], ~v[2024-03])
    %Week.Range{start: ~v[2024-01], size: 3, direction: :forward}

    iex> Week.Range.forward(~v[2024-03], ~v[2024-01])
    %Week.Range{start: ~v[2024-03], size: 0, direction: :forward}

    iex> Week.Range.forward(~v[2024-03], 2)
    %Week.Range{start: ~v[2024-03], size: 2, direction: :forward}
  """
  @spec new(Week.t(), Week.t() | pos_integer()) :: t()
  def new(%Week{} = start, %Week{} = stop) do
    diff = Week.diff(start, stop) * -1
    direction = if diff < 0, do: :backward, else: :forward
    %__MODULE__{start: start, size: abs(diff) + 1, direction: direction}
  end

  def new(%Week{} = start, size), do: new(start, size, :forward)

  @spec new(Week.t(), pos_integer(), direction()) :: t()
  def new(_, _, direction) when direction not in [:forward, :backward],
    do: raise(ArgumentError, "Invalid direction: #{inspect(direction)}")

  def new(%Week{} = start, %Week{} = stop, :forward) do
    size = max(Week.diff(start, stop) * -1 + 1, 0)
    %__MODULE__{start: start, size: size, direction: :forward}
  end

  def new(%Week{} = start, %Week{} = stop, :backward) do
    size = max(Week.diff(stop, start) * -1 + 1, 0)
    %__MODULE__{start: start, size: size, direction: :backward}
  end

  def new(_, size, _) when not is_integer(size) or size < 0,
    do: raise(ArgumentError, "Invalid size: #{inspect(size)}")

  def new(%Week{} = start, size, direction),
    do: %__MODULE__{start: start, size: size, direction: direction}

  @doc """
  Returns the earliest Week of the range.

  Returns `nil` for empty ranges.

  ## Examples

    iex> Week.Range.earliest(Week.Range.forward(~v[2024-01], ~v[2024-03]))
    ~v[2024-01]

    iex> Week.Range.earliest(Week.Range.backward(~v[2024-03], ~v[2024-02]))
    ~v[2024-02]

    iex> Week.Range.earliest(Week.Range.backward(~v[2024-01], ~v[2024-02]))
    nil
  """
  def earliest(%__MODULE__{size: 0}), do: nil
  def earliest(%__MODULE__{start: start, direction: :forward}), do: start

  def earliest(%__MODULE__{start: start, direction: :backward, size: size}),
    do: Week.shift(start, (size - 1) * -1)

  @doc """
  Returns the latest week of the range.

  Returns `nil` for empty ranges.

  ## Examples

  iex> Week.Range.latest(Week.Range.forward(~v[2024-01], ~v[2024-03]))
  ~v[2024-03]

  iex> Week.Range.latest(Week.Range.backward(~v[2024-04], ~v[2024-02]))
  ~v[2024-04]

  iex> Week.Range.latest(Week.Range.backward(~v[2024-01], ~v[2024-02]))
  nil
  """
  def latest(%__MODULE__{size: 0}), do: nil
  def latest(%__MODULE__{start: start, direction: :backward}), do: start

  def latest(%__MODULE__{start: start, direction: :forward, size: size}),
    do: Week.shift(start, size - 1)

  @doc """
  Converts Month Range to an end-inclusive Date.Range from earliest to latest Week.

  The resulting date range will always be built with a step size of 1, but the
  range might be empty.

  ## Example

      iex> Shared.Week.Range.forward(~v[2024-01], ~v[2024-03]) |> Shared.Week.Range.to_date_range()
      Date.range(~D[2024-01-01], ~D[2024-01-21], 1)

      iex> Shared.Week.Range.backward(~v[2024-01], ~v[2024-03]) |> Shared.Week.Range.to_date_range()
      Date.range(~D[2024-01-01], ~D[2023-12-31], 1)
  """
  @spec to_date_range(t()) :: Date.Range.t()
  def to_date_range(%__MODULE__{size: 0, start: start}),
    do: Date.range(Week.first_day(start), Date.add(Week.first_day(start), -1), 1)

  def to_date_range(%__MODULE__{} = month_range) do
    first = month_range |> earliest() |> Week.first_day()
    last = month_range |> latest() |> Week.last_day()
    Date.range(first, last)
  end

  defimpl Enumerable do
    alias Shared.Week

    def count(%Week.Range{size: size}), do: {:ok, size}

    def member?(%Week.Range{size: 0}, _), do: {:ok, false}
    def member?(%Week.Range{start: week, size: 1}, %Week{} = week), do: {:ok, true}

    def member?(%Week.Range{} = range, %Week{} = week) do
      earliest = Week.Range.earliest(range)
      latest = Week.Range.latest(range)

      {:ok,
       Week.compare(week, earliest) in [:eq, :gt] and
         Week.compare(week, latest) in [:eq, :lt]}
    end

    def reduce(%Week.Range{start: start, size: size, direction: direction}, acc, fun) do
      step =
        case direction do
          :forward -> 1
          :backward -> -1
        end

      start
      |> Stream.iterate(&Week.shift(&1, step))
      |> Enum.take(size)
      |> Enumerable.reduce(acc, fun)
    end

    def slice(%Week.Range{start: start, size: size, direction: direction}) do
      {:ok, size,
       fn start_at, amount, step ->
         step =
           case direction do
             :forward -> step
             :backward -> step * -1
           end

         start_at =
           case direction do
             :forward -> start_at
             :backward -> start_at * -1
           end

         start
         |> Week.shift(start_at)
         |> Stream.iterate(&Week.shift(&1, step))
         |> Enum.take(amount)
       end}
    end
  end
end
