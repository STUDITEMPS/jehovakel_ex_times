defmodule Shared.Month.Range do
  @moduledoc false
  alias Shared.Month

  @type direction :: :forward | :backward
  @type t :: %__MODULE__{
          start: Month.t(),
          size: non_neg_integer(),
          direction: direction()
        }

  defstruct [:start, :size, :direction]

  @doc """
  Creates a Month Range with the given start month and end month or size.

  ## Examples

    iex> Month.Range.forward(~m[2024-01], ~m[2024-03])
    %Month.Range{start: ~m[2024-01], size: 3, direction: :forward}

    iex> Month.Range.forward(~m[2024-01], 2)
    %Month.Range{start: ~m[2024-01], size: 2, direction: :forward}
  """
  @spec forward(Month.t(), Month.t() | (size :: pos_integer())) :: t()
  def forward(start, size_or_end), do: new(start, size_or_end, :forward)

  @doc """
  Creates a Month Range with the given start month and end month or size.

  ## Examples

    iex> Month.Range.backward(~m[2024-04], ~m[2024-02])
    %Month.Range{start: ~m[2024-04], size: 3, direction: :backward}

    iex> Month.Range.backward(~m[2024-05], 2)
    %Month.Range{start: ~m[2024-05], size: 2, direction: :backward}
  """
  @spec backward(Month.t(), Month.t() | (size :: pos_integer())) :: t()
  def backward(start, size_or_end), do: new(start, size_or_end, :backward)

  @doc """
  Creates a Month Range with the given start month and end month or size.

  ## Examples

    iex> Month.Range.forward(~m[2024-01], ~m[2024-03])
    %Month.Range{start: ~m[2024-01], size: 3, direction: :forward}

    iex> Month.Range.forward(~m[2024-03], ~m[2024-01])
    %Month.Range{start: ~m[2024-03], size: 0, direction: :forward}

    iex> Month.Range.forward(~m[2024-03], 2)
    %Month.Range{start: ~m[2024-03], size: 2, direction: :forward}
  """
  @spec new(Month.t(), Month.t() | pos_integer()) :: t()
  def new(%Month{} = start, %Month{} = stop) do
    diff = Month.diff(start, stop)
    direction = if diff < 0, do: :backward, else: :forward
    %__MODULE__{start: start, size: abs(diff) + 1, direction: direction}
  end

  def new(%Month{} = start, size), do: new(start, size, :forward)

  @spec new(Month.t(), Month.t() | pos_integer(), direction()) :: t()
  def new(_, _, direction) when direction not in [:forward, :backward],
    do: raise(ArgumentError, "Invalid direction: #{inspect(direction)}")

  def new(%Month{} = start, %Month{} = stop, :forward) do
    size = max(Month.diff(start, stop) + 1, 0)
    %__MODULE__{start: start, size: size, direction: :forward}
  end

  def new(%Month{} = start, %Month{} = stop, :backward) do
    size = max(Month.diff(stop, start) + 1, 0)
    %__MODULE__{start: start, size: size, direction: :backward}
  end

  def new(_, size, _) when not is_integer(size) or size < 0,
    do: raise(ArgumentError, "Invalid size: #{inspect(size)}")

  def new(%Month{} = start, size, direction),
    do: %__MODULE__{start: start, size: size, direction: direction}

  @doc """
  Returns the earliest month of the range.

  Returns `nil` for empty ranges.

  ## Examples

    iex> Month.Range.earliest(Month.Range.forward(~m[2024-01], ~m[2024-03]))
    ~m[2024-01]

    iex> Month.Range.earliest(Month.Range.backward(~m[2024-03], ~m[2024-02]))
    ~m[2024-02]

    iex> Month.Range.earliest(Month.Range.backward(~m[2024-01], ~m[2024-02]))
    nil
  """
  def earliest(%__MODULE__{size: 0}), do: nil
  def earliest(%__MODULE__{start: start, direction: :forward}), do: start

  def earliest(%__MODULE__{start: start, direction: :backward, size: size}),
    do: Month.add(start, (size - 1) * -1)

  @doc """
  Returns the latest month of the range.

  Returns `nil` for empty ranges.

  ## Examples

  iex> Month.Range.latest(Month.Range.forward(~m[2024-01], ~m[2024-03]))
  ~m[2024-03]

  iex> Month.Range.latest(Month.Range.backward(~m[2024-04], ~m[2024-02]))
  ~m[2024-04]

  iex> Month.Range.latest(Month.Range.backward(~m[2024-01], ~m[2024-02]))
  nil
  """
  def latest(%__MODULE__{size: 0}), do: nil
  def latest(%__MODULE__{start: start, direction: :backward}), do: start

  def latest(%__MODULE__{start: start, direction: :forward, size: size}),
    do: Month.add(start, size - 1)

  @doc """
  Converts Month Range to an end-inclusive Date.Range from earliest to latest Month.

  The resulting date range will always be built with a step size of 1, but the
  range might be empty.

  ## Example

      iex> Shared.Month.Range.forward(~m[2024-01], ~m[2024-03]) |> Shared.Month.Range.to_date_range()
      Date.range(~D[2024-01-01], ~D[2024-03-31], 1)

      iex> Shared.Month.Range.backward(~m[2024-01], ~m[2024-03]) |> Shared.Month.Range.to_date_range()
      Date.range(~D[2024-01-01], ~D[2023-12-31], 1)
  """
  @spec to_date_range(t()) :: Date.Range.t()
  def to_date_range(%__MODULE__{size: 0, start: start}),
    do: Date.range(Month.first_day(start), Date.add(Month.first_day(start), -1), 1)

  def to_date_range(%__MODULE__{} = month_range) do
    first = month_range |> earliest() |> Month.first_day()
    last = month_range |> latest() |> Month.last_day()
    Date.range(first, last)
  end

  defimpl Enumerable do
    alias Shared.Month

    def count(%Month.Range{size: size}), do: {:ok, size}

    def member?(%Month.Range{size: 0}, _), do: {:ok, false}
    def member?(%Month.Range{start: month, size: 1}, %Month{} = month), do: {:ok, true}

    def member?(%Month.Range{} = range, %Month{} = month) do
      earliest = Month.Range.earliest(range)
      latest = Month.Range.latest(range)

      {:ok,
       Month.compare(month, earliest) in [:eq, :gt] and
         Month.compare(month, latest) in [:eq, :lt]}
    end

    def reduce(%Month.Range{start: start, size: size, direction: direction}, acc, fun) do
      step =
        case direction do
          :forward -> 1
          :backward -> -1
        end

      start
      |> Stream.iterate(&Month.add(&1, step))
      |> Enum.take(size)
      |> Enumerable.reduce(acc, fun)
    end

    def slice(%Month.Range{start: start, size: size, direction: direction}) do
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
         |> Month.add(start_at)
         |> Stream.iterate(&Month.add(&1, step))
         |> Enum.take(amount)
       end}
    end
  end
end
