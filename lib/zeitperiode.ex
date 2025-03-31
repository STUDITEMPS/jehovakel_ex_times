defmodule Shared.Zeitperiode do
  @moduledoc """
  Repräsentiert eine Arbeitszeit-Periode oder Schicht
  """
  @type t :: Timex.Interval.t()

  @type interval ::
          [start: DateTime.t(), ende: DateTime.t()]
          | [start: NaiveDateTime.t(), ende: NaiveDateTime.t()]

  @default_base_timezone_name "Europe/Berlin"

  @spec new(Date.t(), Time.t(), Time.t()) :: t()
  def new(%Date{} = kalendertag, %Time{} = von, %Time{} = bis) do
    von_als_datetime = to_datetime(kalendertag, von)

    bis_als_datetime =
      if before?(von, bis) do
        to_datetime(kalendertag, bis)
      else
        next_day = Timex.shift(kalendertag, days: 1)
        to_datetime(next_day, bis)
      end

    to_interval(von_als_datetime, bis_als_datetime)
  end

  # Basiszeitzone ist die Zeitzone, in der die Zeit erfasst wurde, aktuell immer Dtl.
  @spec new(DateTime.t(), DateTime.t(), String.t()) :: t
  def new(%DateTime{} = von, %DateTime{} = bis, base_timezone_name) do
    von = Shared.Zeitperiode.Timezone.convert(von, base_timezone_name)

    bis = Shared.Zeitperiode.Timezone.convert(bis, base_timezone_name)

    %{offset_std: von_offset} =
      Shared.Zeitperiode.Timezone.timezone_info_for(von, base_timezone_name)

    %{offset_std: bis_offset} =
      Shared.Zeitperiode.Timezone.timezone_info_for(bis, base_timezone_name)

    shift =
      cond do
        von_offset == bis_offset -> 0
        von_offset == 0 -> -bis_offset
        bis_offset == 0 -> von_offset
      end

    von_naive = von |> DateTime.to_naive()

    bis_naive =
      bis
      |> DateTime.to_naive()
      |> Timex.shift(seconds: shift)

    to_interval(von_naive, bis_naive)
  end

  @spec new(von :: DateTime.t(), bis :: DateTime.t()) :: t
  def new(%DateTime{} = von, %DateTime{} = bis) do
    # default value using `\\` produces the warning `definitions with multiple clauses and default values require a header.`
    new(von, bis, @default_base_timezone_name)
  end

  @spec new(von :: NaiveDateTime.t(), bis :: NaiveDateTime.t()) :: t
  def new(%NaiveDateTime{} = von, %NaiveDateTime{} = bis), do: to_interval(von, bis)

  @spec new(von :: Date.t(), bis :: Date.t()) :: t
  def new(%Date{} = von, %Date{} = bis) do
    von_als_datetime = to_datetime(von, ~T[00:00:00])
    bis_als_datetime = bis |> Timex.shift(days: 1) |> to_datetime(~T[00:00:00])

    to_interval(von_als_datetime, bis_als_datetime)
  end

  @spec from_interval(interval :: String.t()) :: t
  def from_interval(interval) when is_binary(interval) do
    [start: start, ende: ende] = parse(interval)
    new(start, ende)
  end

  @spec von(t) :: Timex.Types.valid_datetime()
  def von(periode), do: periode.from

  @spec bis(t) :: Timex.Types.valid_datetime()
  def bis(periode), do: periode.until

  @spec von_datum(t) :: Date.t()
  def von_datum(periode), do: periode |> von() |> NaiveDateTime.to_date()

  @spec bis_datum(t) :: Date.t()
  def bis_datum(%{until: %{hour: 0, minute: 0, second: 0}} = periode) do
    periode |> bis() |> NaiveDateTime.to_date() |> Timex.shift(days: -1)
  end

  def bis_datum(periode) do
    periode |> bis() |> NaiveDateTime.to_date()
  end

  @spec dauer(t) :: Timex.Duration.t() | {:error, any}
  def dauer(periode), do: duration(periode, :duration)
  @spec dauer_in_stunden(t) :: float | {:error, any}
  def dauer_in_stunden(periode), do: duration(periode, :hours)
  @spec dauer_in_minuten(t) :: float | {:error, any}
  def dauer_in_minuten(periode), do: duration(periode, :minutes)

  @deprecated "verwende `Zeitraum.ueberschneidung?/2`"
  @spec ueberschneidung?(periode :: t, andere_periode :: t) :: boolean
  defdelegate ueberschneidung?(periode, andere_periode), to: Shared.Zeitraum

  @deprecated "verwende `Zeitraum.teil_von?/2`"
  @spec teil_von?(zu_testende_periode :: t, periode :: t) :: boolean
  defdelegate teil_von?(zu_testende_periode, periode), to: Shared.Zeitraum

  @spec beginnt_vor?(periode1 :: t, periode2 :: t) :: boolean
  def beginnt_vor?(periode1, periode2) do
    NaiveDateTime.compare(periode1.from, periode2.from) == :lt
  end

  @spec to_string(t) :: String.t()
  def to_string(periode), do: Timex.Interval.format!(periode, "%Y-%m-%d %H:%M", :strftime)

  @spec to_iso8601(Timex.Interval.t()) :: binary()
  def to_iso8601(%Timex.Interval{from: %NaiveDateTime{} = von, until: %NaiveDateTime{} = bis}) do
    [von, bis] |> Enum.map_join("/", &NaiveDateTime.to_iso8601/1)
  end

  @spec to_iso8601(interval()) :: binary()
  def to_iso8601(start: %DateTime{} = start, ende: %DateTime{} = ende) do
    [start, ende] |> Enum.map_join("/", &DateTime.to_iso8601/1)
  end

  def to_iso8601(start: %NaiveDateTime{} = start, ende: %NaiveDateTime{} = ende) do
    [start, ende] |> Enum.map_join("/", &NaiveDateTime.to_iso8601/1)
  end

  @spec parse(binary()) :: interval()
  def parse(interval) when is_binary(interval) do
    [start, ende] =
      interval
      |> String.replace("--", "/")
      |> String.split("/")

    [start: start |> Shared.Zeit.parse(), ende: ende |> Shared.Zeit.parse()]
  end

  @deprecated "Use parse/1 instead"
  def parse_interval(interval) when is_binary(interval), do: parse(interval)

  @deprecated "Use Shared.Zeit.parse/1 instead"
  def parse_time(time) when is_binary(time), do: Shared.Zeit.parse(time)

  @spec dauer_der_ueberschneidung(periode1 :: Timex.Interval.t(), periode2 :: Timex.Interval.t()) ::
          Timex.Duration.t()
  def dauer_der_ueberschneidung(periode1, periode2) do
    dauer1 = dauer(periode1)

    dauer_differenz =
      case Timex.Interval.difference(periode1, periode2) do
        [] -> Shared.Dauer.leer()
        [periode] -> dauer(periode)
        [periode1, periode2] -> Shared.Dauer.addiere(dauer(periode1), dauer(periode2))
      end

    Shared.Dauer.subtrahiere(dauer1, dauer_differenz)
  end

  @doc """
  Zieht von einer Liste von Zeitperioden eine andere Liste von Zeitperioden ab,
  so dass alle Überlappungen mit der zweiten Liste aus der ersten Liste entfernt
  werden.
  """
  @spec differenz(list(Timex.Interval.t()) | Timex.Interval.t(), list(Timex.Interval.t())) ::
          list(Timex.Interval.t())
  def differenz(basis_intervalle, abzuziehende_intervalle) when is_list(basis_intervalle) do
    basis_intervalle |> Enum.flat_map(&differenz(&1, abzuziehende_intervalle))
  end

  def differenz(%Timex.Interval{} = basis_intervall, []) do
    [basis_intervall]
  end

  def differenz(%Timex.Interval{} = basis_intervall, [abzuziehendes_intervall]) do
    basis_intervall |> differenz(abzuziehendes_intervall)
  end

  def differenz(%Timex.Interval{} = basis_intervall, [abzuziehendes_intervall | rest]) do
    basis_intervall |> differenz(abzuziehendes_intervall) |> differenz(rest)
  end

  # Zieht von einer einzelnen Zeitperiode eine andere ab. Für tolle Beispiele siehe
  # https://hexdocs.pm/timex/3.5.0/Timex.Interval.html#difference/2
  defdelegate differenz(basis_intervall, abzuziehendes_intervall),
    to: Timex.Interval,
    as: :difference

  @doc """
  Ermittelt die Überschneidung zweier Zeitperioden.
  """
  @spec ueberschneidung(Zeitperiode.t(), Zeitperiode.t()) :: Zeitperiode.t() | nil
  def ueberschneidung(a, b) do
    case differenz(a, differenz(a, b)) do
      [ueberschneidung] -> ueberschneidung
      [] -> nil
    end
  end

  defp truncate(%NaiveDateTime{} = datetime), do: NaiveDateTime.truncate(datetime, :second)
  defp truncate(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)

  defp to_interval(von, bis) do
    Timex.Interval.new(
      from: truncate(von),
      until: truncate(bis),
      left_open: false,
      right_open: true,
      step: [seconds: 1]
    )
  end

  defp to_datetime(date, time), do: NaiveDateTime.new!(date, time)

  defp duration(periode, :duration), do: Timex.Interval.duration(periode, :duration)

  defp duration(periode, :hours),
    do: periode |> duration(:duration) |> Timex.Duration.to_hours()

  defp duration(periode, :minutes),
    do: periode |> duration(:duration) |> Timex.Duration.to_minutes() |> Float.round()

  defmodule Timezone do
    @spec convert(
            DateTime.t(),
            binary() | Timex.AmbiguousTimezoneInfo.t() | Timex.TimezoneInfo.t()
          ) :: DateTime.t() | Timex.AmbiguousDateTime.t()
    def convert(datetime, timezone) do
      case Timex.Timezone.convert(datetime, timezone) do
        {:error, _} ->
          shifted = %{datetime | hour: datetime.hour + 1}
          converted = Timex.Timezone.convert(shifted, timezone)
          _shifted_back = %{converted | hour: converted.hour - 1}

        converted ->
          converted
      end
    end

    def timezone_info_for(time, timezone_name) do
      case Timex.Timezone.get(timezone_name, time) do
        # 02:00 - 03:00 day of the summer time / winter time switch
        {:error, _} ->
          # Timex.shift/2 funktioniert nicht, weil dann dieselbe Exception geworfen wird
          time = %{time | hour: time.hour + 1}
          Timex.Timezone.get(timezone_name, time)

        %Timex.TimezoneInfo{} = timezone_info ->
          timezone_info
      end
    end
  end

  if function_exported?(Time, :before?, 2) do
    defdelegate before?(a, b), to: Time
  else
    def before?(a, b), do: Time.compare(a, b) == :lt
  end
end
