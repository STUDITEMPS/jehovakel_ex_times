defmodule Shared.Zeit do
  alias Shared.Zeitperiode

  @spec mit_deutscher_zeitzone(datum :: Date.t(), zeit :: Time.t()) :: DateTime.t()
  @doc """
  Wandelt ein Datum und eine Zeit in ein DateTime Struct mit deutscher Zeitzone
  um. Es wird also angenommen, dass die übergebene Zeit in Deutschland statt
  fand.

  iex> Shared.Zeit.mit_deutscher_zeitzone(~D[2018-02-22], ~T[15:00:00])
  #DateTime<2018-02-22 15:00:00+01:00 CET Europe/Berlin>

  iex> Shared.Zeit.mit_deutscher_zeitzone(~N[2018-03-25 03:00:00])
  #DateTime<2018-03-25 03:00:00+02:00 CEST Europe/Berlin>

  iex> Shared.Zeit.mit_deutscher_zeitzone(~N[2018-10-28 02:30:00])
  #DateTime<2018-10-28 02:30:00+01:00 CET Europe/Berlin>
  """
  def mit_deutscher_zeitzone(%Date{} = date, %Time{} = time) do
    {:ok, datetime} = NaiveDateTime.new(date, time)

    datetime
    |> mit_deutscher_zeitzone()
  end

  @spec mit_deutscher_zeitzone(NaiveDateTime.t()) :: DateTime.t()
  def mit_deutscher_zeitzone(%NaiveDateTime{} = datetime) do
    datetime = datetime |> Timex.to_datetime("Europe/Berlin")

    case datetime do
      %Timex.AmbiguousDateTime{type: :ambiguous, after: winterzeit} -> winterzeit
      _ -> datetime
    end
  end

  @spec mit_deutscher_zeitzone(DateTime.t()) :: DateTime.t()
  def mit_deutscher_zeitzone(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_naive()
    |> mit_deutscher_zeitzone()
  end

  @spec mit_deutscher_zeitzone(datum :: Date.t(), start :: Time.t(), ende :: Time.t()) ::
          Timex.Interval.t()
  def mit_deutscher_zeitzone(%Date{} = datum, %Time{} = start, %Time{} = ende) do
    zeitperiode = Zeitperiode.new(datum, start, ende)

    Zeitperiode.new(
      Zeitperiode.von(zeitperiode) |> mit_deutscher_zeitzone(),
      Zeitperiode.bis(zeitperiode) |> mit_deutscher_zeitzone(),
      "Etc/UTC"
    )
  end

  @spec parse(binary) :: DateTime.t() | NaiveDateTime.t()
  def parse(to_parse) when is_binary(to_parse) do
    case Timex.parse(to_parse, "{ISO:Extended}") do
      {:ok, %DateTime{} = date_time} ->
        if date_time.utc_offset != 0 do
          DateTime.shift_zone!(date_time, "Europe/Berlin")
        else
          date_time
        end

      {:ok, %NaiveDateTime{} = naive_date_time} ->
        naive_date_time

      {:error, _} ->
        case Date.from_iso8601(to_parse) do
          {:ok, date} -> NaiveDateTime.new!(date, ~T[00:00:00])
          {:error, reason} -> raise ArgumentError, "Invalid date/time format: #{reason}"
        end
    end
  end

  @spec jetzt :: DateTime.t()
  def jetzt do
    Timex.local() |> DateTime.truncate(:second)
  end

  defmodule Sigil do
    @spec sigil_G(term :: binary(), _modifiers :: charlist()) :: DateTime.t()
    @doc """
    Wandelt ISO8601 Date Strings und Time Strings in DateTime mit deutscher Zeitzone

    ## Examples

      iex> ~G[2018-04-03 17:20:00]
      #DateTime<2018-04-03 17:20:00+02:00 CEST Europe/Berlin>

    """
    def sigil_G(string, []) do
      # [date_string, time_string] = String.split(string)
      # date = Date.from_iso8601!(date_string)
      # time = Time.from_iso8601!(time_string)
      naive = NaiveDateTime.from_iso8601!(string)
      Shared.Zeit.mit_deutscher_zeitzone(naive)
    end
  end
end
