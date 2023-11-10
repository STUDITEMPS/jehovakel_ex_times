defmodule Shared.ZeitperiodeTest do
  use ExUnit.Case, async: true
  use PropCheck

  alias Shared.Zeitperiode, as: Periode
  import Support.TimeAssertionHelper

  describe "Konstruktion aus Date und Times" do
    test "wenn von ist kleiner als bis" do
      date = ~D[2018-03-20]
      von = ~T[10:00:00]
      bis = ~T[12:20:00]
      periode = Periode.new(date, von, bis)

      assert Periode.to_string(periode) == "[2018-03-20 10:00, 2018-03-20 12:20)"

      date = ~D[2018-03-20]
      von = ~T[10:00:00]
      bis = ~T[00:00:00]
      periode = Periode.new(date, von, bis)

      assert Periode.to_string(periode) == "[2018-03-20 10:00, 2018-03-21 00:00)"
    end

    test "wenn von ist größer als bis" do
      date = ~D[2018-03-20]
      von = ~T[21:20:00]
      bis = ~T[06:00:00]
      periode = Periode.new(date, von, bis)

      assert Periode.to_string(periode) == "[2018-03-20 21:20, 2018-03-21 06:00)"

      date = ~D[2018-03-21]
      von = ~T[00:00:00]
      bis = ~T[06:00:00]
      periode = Periode.new(date, von, bis)

      assert Periode.to_string(periode) == "[2018-03-21 00:00, 2018-03-21 06:00)"
    end

    test "wenn von ist glech bis" do
      date = ~D[2018-03-20]
      von = ~T[06:00:00]
      bis = ~T[06:00:00]
      periode = Periode.new(date, von, bis)

      assert Periode.to_string(periode) == "[2018-03-20 06:00, 2018-03-21 06:00)"

      date = ~D[2018-03-21]
      von = ~T[00:00:00]
      bis = ~T[00:00:00]
      periode = Periode.new(date, von, bis)

      assert Periode.to_string(periode) == "[2018-03-21 00:00, 2018-03-22 00:00)"
    end
  end

  describe "Konstruktion aus Dates" do
    test "Bis-Datum ist Teil der Zeitperiode" do
      von = ~D[2018-03-20]
      bis = ~D[2018-03-31]
      periode = Periode.new(von, bis)

      assert Periode.to_string(periode) == "[2018-03-20 00:00, 2018-04-01 00:00)"
    end

    test "Ende kann nicht vor Start liegen" do
      assert {:error, :invalid_until} = Periode.new(~D[2020-01-01], ~D[2019-12-31])
    end
  end

  describe "Konstruktion aus DateTimes" do
    test "Ende kann nicht vor Start liegen" do
      assert {:error, :invalid_until} =
               Periode.new(~U[2020-01-01 01:00:00Z], ~U[2020-01-01 00:00:00Z])
    end

    test "Periode kann nicht leer sein" do
      assert {:error, :invalid_until} =
               Periode.new(~U[2020-01-01 00:00:00Z], ~U[2020-01-01 00:00:00Z])
    end

    # Sommerzeit in 2018 begann am 25.03. um 02:00 und endete am 28.10. um 03:00
    test "Periode kann Zeitzonen überspannen" do
      periode = Periode.new(~U[2018-03-24 21:00:00Z], ~U[2018-03-25 02:00:00Z])
      assert Periode.von(periode) == ~N[2018-03-24 22:00:00]
      # WONTFIX: Sollte eigentlich bis 4 Uhr gehen
      assert Periode.bis(periode) == ~N[2018-03-25 03:00:00]

      periode = Periode.new(~U[2018-10-28 00:00:00Z], ~U[2018-10-28 08:00:00Z])
      assert Periode.von(periode) == ~N[2018-10-28 02:00:00]
      # WONTFIX: Sollte eigentlich bis 09 Uhr gehen
      assert Periode.bis(periode) == ~N[2018-10-28 10:00:00]
    end
  end

  describe "Dauer" do
    test "Dauer in Stunden" do
      date = ~D[2018-03-20]
      von = ~T[21:20:00]
      bis = ~T[06:00:00]
      periode = Periode.new(date, von, bis)

      assert Periode.dauer_in_stunden(periode) |> Float.round(2) == 8.67
    end

    test "Dauer als Duration" do
      date = ~D[2018-03-20]
      von = ~T[21:30:00]
      bis = ~T[06:00:00]
      periode = Periode.new(date, von, bis)

      assert Periode.dauer(periode) == Shared.Dauer.aus_stundenzahl(8.5)
    end

    test "Dauer in Minuten" do
      date = ~D[2018-03-20]
      von = ~T[21:20:00]
      bis = ~T[06:00:00]
      periode = Periode.new(date, von, bis)

      assert Periode.dauer_in_minuten(periode) == 520
    end

    test "Dauer in Minuten bei Mitternacht" do
      date = ~D[2018-03-20]
      von = ~T[23:00:00]
      bis = ~T[00:00:00]
      periode = Periode.new(date, von, bis)

      assert Periode.dauer_in_minuten(periode) == 60
    end

    test "Dauer bei Wechsel zur Sommerzeit" do
      periode = Periode.new(~U[2018-03-25 00:00:00Z], ~U[2018-03-25 02:00:00Z])
      assert Periode.dauer_in_stunden(periode) == 2.0
    end

    test "Dauer bei Wechsel zur Winterzeit" do
      periode = Periode.new(~U[2018-10-28 00:00:00Z], ~U[2018-10-28 04:00:00Z])
      assert Periode.dauer_in_stunden(periode) == 4.0
    end
  end

  describe "Überschneidung" do
    test "keine Überschneidung an den Rändern der Perioden" do
      periode = Periode.new(~D[2018-03-20], ~T[16:00:00], ~T[18:00:00])
      andere_periode = Periode.new(~D[2018-03-20], ~T[18:00:00], ~T[22:00:00])

      refute Periode.ueberschneidung?(periode, andere_periode)
    end

    test "bei Überschneidung der Periodele" do
      periode = Periode.new(~D[2018-03-20], ~T[16:00:00], ~T[18:00:00])
      andere_periode = Periode.new(~D[2018-03-20], ~T[17:00:00], ~T[22:00:00])
      assert Periode.ueberschneidung?(periode, andere_periode)
    end
  end

  describe "beginnt_vor\2" do
    test "p1 liegt vor p2" do
      periode = Periode.new(~D[2018-03-20], ~T[16:00:00], ~T[18:00:00])
      andere_periode = Periode.new(~D[2018-03-20], ~T[18:00:00], ~T[22:00:00])

      assert true === Periode.beginnt_vor?(periode, andere_periode)
    end

    test "p1 liegt nach p2" do
      periode = Periode.new(~D[2018-03-20], ~T[16:00:00], ~T[18:00:00])
      andere_periode = Periode.new(~D[2018-03-20], ~T[18:00:00], ~T[22:00:00])

      assert false === Periode.beginnt_vor?(andere_periode, periode)
    end

    test "p1 ist gleich zu p2" do
      periode = Periode.new(~D[2018-03-20], ~T[16:00:00], ~T[18:00:00])

      assert false === Periode.beginnt_vor?(periode, periode)
    end
  end

  describe "kann mit Zeiten mit Zeitzonen umgehen" do
    test "wenn es eine Zeitumstellung auf Sommerzeit gibt" do
      {:ok, start, _offset} = DateTime.from_iso8601("2018-03-23T22:00:00+01:00")
      {:ok, ende, _offset} = DateTime.from_iso8601("2018-03-24T04:00:00+02:00")

      periode = Periode.new(start, ende)

      assert Periode.dauer_in_stunden(periode) == 5.0
      assert to_string(periode.from) == "2018-03-23 22:00:00"
      assert to_string(periode.until) == "2018-03-24 03:00:00"
    end

    test "wenn es eine Zeitumstellung auf Winterzeit gibt" do
      start =
        Timex.to_datetime(
          %{year: 2018, month: 10, day: 27, hour: 22, minute: 0, second: 0},
          "Europe/Berlin"
        )

      ende =
        Timex.to_datetime(
          %{year: 2018, month: 10, day: 28, hour: 4, minute: 0, second: 0},
          "Europe/Berlin"
        )

      periode = Periode.new(start, ende)

      assert to_string(periode.from) == "2018-10-27 22:00:00"
      # WONTFIX: Sollte eigentlich bis 04:00 gehen
      assert to_string(periode.until) == "2018-10-28 05:00:00"
      assert Periode.dauer_in_stunden(periode) == 7.0
    end

    test "wenn der Start uneindeutig ist" do
      start = ~N[2018-10-28 02:30:00] |> Shared.Zeit.mit_deutscher_zeitzone()
      ende = ~N[2018-10-28 08:30:00] |> Shared.Zeit.mit_deutscher_zeitzone()

      periode = Periode.new(start, ende)

      assert to_string(periode.from) == "2018-10-28 02:30:00"
      # WONTFIX: Sollte eigentlich bis 08:30 Uhr gehen
      assert to_string(periode.until) == "2018-10-28 09:30:00"

      # WONTFIX: Sollte eigentlich nur 6 Stunden betragen da wir bei
      # uneindeutigem Start von Winterzeit ausgehen und 02:30+02:00 bis
      # 08:30+02:00 sind 6 Stunden...
      assert Periode.dauer_in_stunden(periode) == 7.0
    end

    test "wenn das Ende uneindeutig ist" do
      start = ~N[2018-10-27 22:00:00] |> Shared.Zeit.mit_deutscher_zeitzone()
      ende = ~N[2018-10-28 02:30:00] |> Shared.Zeit.mit_deutscher_zeitzone()

      periode = Periode.new(start, ende)

      assert to_string(periode.from) == "2018-10-27 22:00:00"
      assert to_string(periode.until) == "2018-10-28 02:30:00"
      # WONTFIX: Sollte eigentlich 5.5 Stunden sein, da wir bei uneindeutigem
      # Ende von Winterzeit ausgehen und zwischen 22:00+02:00 (20:00 UTC) und
      # 02:30+01:00 (01:30 UTC) vergehen 5.5 Stunden.
      assert Periode.dauer_in_stunden(periode) == 4.5
    end

    test "kann die Zeitzone bei der Umstellung auf Winterzeit ermitteln" do
      {:ok, start, _offset} = DateTime.from_iso8601("2019-10-26T17:50:00+02:00")

      start = %{
        start
        | std_offset: 3600,
          utc_offset: 3600,
          time_zone: "Europe/Berlin",
          zone_abbr: "CEST"
      }

      {:ok, ende, _offset} = DateTime.from_iso8601("2019-10-27T03:50:00+01:00")

      ende = %{
        ende
        | std_offset: 0,
          utc_offset: 3600,
          time_zone: "Europe/Berlin",
          zone_abbr: "CET"
      }

      assert Periode.new(start, ende)
    end

    test "wenn es keine Zeitumstellung gibt" do
      start =
        Timex.to_datetime(
          %{year: 2018, month: 9, day: 27, hour: 22, minute: 0, second: 0},
          "Europe/Berlin"
        )

      ende =
        Timex.to_datetime(
          %{year: 2018, month: 9, day: 28, hour: 4, minute: 0, second: 0},
          "Europe/Berlin"
        )

      periode = Periode.new(start, ende)

      assert to_string(periode.from) == "2018-09-27 22:00:00"
      assert to_string(periode.until) == "2018-09-28 04:00:00"
      assert Periode.dauer_in_stunden(periode) == 6.0
    end

    test "wenn es eine Zeitumstellung auf Sommerzeit gibt und die Zeit in UTC vorliegt" do
      start =
        Timex.to_datetime(
          %{year: 2018, month: 3, day: 24, hour: 21, minute: 0, second: 0},
          "Etc/UTC"
        )

      ende =
        Timex.to_datetime(
          %{year: 2018, month: 3, day: 25, hour: 2, minute: 0, second: 0},
          "Etc/UTC"
        )

      periode = Periode.new(start, ende)

      assert to_string(periode.from) == "2018-03-24 22:00:00"
      # WONTFIX: Sollte eigentlich 4 Uhr sein
      assert to_string(periode.until) == "2018-03-25 03:00:00"
      assert Periode.dauer_in_stunden(periode) == 5.0
    end

    test "wenn es eine Zeitumstellung auf Winterzeit gibt und die Zeit in UTC vorliegt" do
      start =
        Timex.to_datetime(
          %{year: 2018, month: 10, day: 27, hour: 20, minute: 0, second: 0},
          "Etc/UTC"
        )

      ende =
        Timex.to_datetime(
          %{year: 2018, month: 10, day: 28, hour: 3, minute: 0, second: 0},
          "Etc/UTC"
        )

      periode = Periode.new(start, ende)

      assert to_string(periode.from) == "2018-10-27 22:00:00"
      # WONTFIX: Sollte eigentlich 4 Uhr sein
      assert to_string(periode.until) == "2018-10-28 05:00:00"
      assert Periode.dauer_in_stunden(periode) == 7.0
    end

    test "wenn es keine Zeitumstellung gibt und die Zeit in UTC vorliegt" do
      start =
        Timex.to_datetime(
          %{year: 2018, month: 9, day: 27, hour: 20, minute: 0, second: 0},
          "Etc/UTC"
        )

      ende =
        Timex.to_datetime(
          %{year: 2018, month: 9, day: 28, hour: 2, minute: 0, second: 0},
          "Etc/UTC"
        )

      periode = Periode.new(start, ende)

      assert Periode.dauer_in_stunden(periode) == 6.0
      assert to_string(periode.from) == "2018-09-27 22:00:00"
      assert to_string(periode.until) == "2018-09-28 04:00:00"
    end

    test "Zeitumstellung und die Zeitzone kann nun geparsed werden kann" do
      interval = "2018-10-27T17:00:00+02:00/2018-10-28T10:00:00+01:00"
      assert periode = Periode.from_interval(interval)
      # WONTFIX: Sollte eigentlich bis 10 Uhr gehen
      assert Periode.to_string(periode) == "[2018-10-27 17:00, 2018-10-28 11:00)"

      interval = "2019-03-30T22:00:00+01:00/2019-03-31T07:00:00+02:00"
      assert periode = Periode.from_interval(interval)
      # WONTFIX: Sollte eigentlich bis 7 Uhr gehen
      assert Periode.to_string(periode) == "[2019-03-30 22:00, 2019-03-31 06:00)"

      interval = "2019-03-30T22:00:00+01:00/2019-03-31T04:00:00+02:00"
      assert periode = Periode.from_interval(interval)
      # WONTFIX: Sollte eigentlich bis 4 Uhr gehen
      assert Periode.to_string(periode) == "[2019-03-30 22:00, 2019-03-31 03:00)"
    end
  end

  describe "from_interval/1" do
    test "parse Interval und erstelle eine neue Zeitperiode" do
      interval = "2018-09-27T17:00:00+02:00/2018-09-28T10:00:00+02:00"

      assert periode = Periode.from_interval(interval)
      assert Periode.dauer_in_stunden(periode) == 17.0
      assert Periode.von(periode) == ~N(2018-09-27 17:00:00)
      assert Periode.bis(periode) == ~N(2018-09-28 10:00:00)
    end
  end

  describe "parse_interval/1" do
    test "parse ISO8601 Zeitintervall" do
      assert Periode.parse("2019-04-16T23:30:00+02:00/2019-04-16T23:45:00+02:00")
             |> entspricht_intervall?("2019-04-16T23:30:00+02:00/2019-04-16T23:45:00+02:00")

      assert Periode.parse("2019-04-16T23:30:00+02:00--2019-04-16T23:45:00+02:00")
             |> entspricht_intervall?("2019-04-16T23:30:00+02:00/2019-04-16T23:45:00+02:00")
    end
  end

  describe "to_iso8601/1" do
    test "formatiere Periode als naives ISO8601 Intervall" do
      assert periode = Periode.new(~N[2020-03-16 18:23:00], ~N[2020-04-02 08:38:11])
      assert "2020-03-16T18:23:00/2020-04-02T08:38:11" == Periode.to_iso8601(periode)
    end

    test "formatiere Intervall als ISO8601 Intervall" do
      intervall_string = "2020-03-16T18:23:00+01:00/2020-04-02T08:38:11+02:00"
      assert intervall = Periode.parse(intervall_string)
      assert intervall_string == Periode.to_iso8601(intervall)
    end

    test "formatiere naives Intervall als ISO8601 Intervall" do
      intervall_string = "2020-03-16T18:23:00/2020-04-02T08:38:11"
      assert intervall = Periode.parse(intervall_string)
      assert intervall_string == Periode.to_iso8601(intervall)
    end

    test "Perioden und Intervalle sind unterschiedlich" do
      intervall_string = "2020-03-16T18:23:00+01:00/2020-04-02T08:38:11+02:00"
      assert intervall = Periode.parse(intervall_string)
      assert periode = Periode.from_interval(intervall_string)
      refute Periode.to_iso8601(intervall) == Periode.to_iso8601(periode)
    end
  end

  describe "teil_von?/2" do
    test "erkennt, ob ein Periode komplett in einem anderen Periode liegt" do
      periode = Periode.new(~D[2018-03-20], ~T[23:00:00], ~T[00:00:00])

      refute periode |> Periode.teil_von?(periode)

      refute Periode.new(~D[2018-03-20], ~T[23:00:00], ~T[01:00:00])
             |> Periode.teil_von?(periode)

      refute Periode.new(~D[2018-03-20], ~T[23:30:00], ~T[00:00:00])
             |> Periode.teil_von?(periode)

      refute Periode.new(~D[2018-03-20], ~T[22:30:00], ~T[23:00:00])
             |> Periode.teil_von?(periode)

      refute Periode.new(~D[2018-03-20], ~T[23:30:00], ~T[01:00:00])
             |> Periode.teil_von?(periode)

      assert Periode.new(~D[2018-03-20], ~T[23:30:00], ~T[23:45:00])
             |> Periode.teil_von?(periode)
    end
  end

  describe "dauer_der_ueberschneidung/2" do
    test "test" do
      dauer_der_ueberschneidung_test = fn start_ende_1, start_ende_2, erwartet ->
        [start1, ende1] =
          start_ende_1
          |> String.split("-")
          |> Enum.map(&(&1 <> ":00"))
          |> Enum.map(&Time.from_iso8601!/1)

        [start2, ende2] =
          start_ende_2
          |> String.split("-")
          |> Enum.map(&(&1 <> ":00"))
          |> Enum.map(&Time.from_iso8601!/1)

        periode1 = Periode.new(~D[2018-03-20], start1, ende1)
        periode2 = Periode.new(~D[2018-03-20], start2, ende2)
        dauer = Periode.dauer_der_ueberschneidung(periode1, periode2)

        assert dauer == Shared.Dauer.aus_stundenzahl(erwartet)
      end

      assert dauer_der_ueberschneidung_test.("10:00-12:00", "10:00-12:00", 2.0)
      assert dauer_der_ueberschneidung_test.("10:00-12:00", "12:00-13:00", 0.0)
      assert dauer_der_ueberschneidung_test.("10:00-13:00", "11:00-12:00", 1.0)
      assert dauer_der_ueberschneidung_test.("09:00-13:00", "11:00-12:00", 1.0)
      assert dauer_der_ueberschneidung_test.("12:00-13:00", "10:00-14:00", 1.0)
    end
  end

  describe "differenz einzelner Zeitperioden" do
    # Restliche Testabdeckung ist in Timex zu finden ;-)
    @datum ~D[2018-03-20]
    test "zieht von erster Periode die Überlappung mit der zweiten Periode ab" do
      neun_bis_elf = Periode.new(@datum, ~T[09:00:00], ~T[11:00:00])
      zehn_bis_zwoelf = Periode.new(@datum, ~T[10:00:00], ~T[12:00:00])

      neun_bis_zehn = Periode.new(@datum, ~T[09:00:00], ~T[10:00:00])

      assert Periode.differenz(neun_bis_elf, zehn_bis_zwoelf) == [neun_bis_zehn]
    end
  end

  describe "differenz von Listen von Zeitperioden" do
    test "erzeugt neue Liste von Zeitperioden ohne die Überlappungen mit der zweiten Liste von Zeitperioden" do
      datum = ~D[2019-04-22]

      assert [Periode.new(datum, ~T[08:00:00], ~T[15:00:00])] ==
               Periode.differenz(
                 [Periode.new(datum, ~T[08:00:00], ~T[16:00:00])],
                 [Periode.new(datum, ~T[15:00:00], ~T[16:00:00])]
               )
    end

    test "Liste bleibt unverändert, wenn keine Überlappung mit der zweiten Liste vorhanden ist" do
      erste_liste = [Periode.new(~D[2019-04-22], ~T[14:00:00], ~T[15:00:00])]

      assert erste_liste ==
               Periode.differenz(
                 erste_liste,
                 [
                   Periode.new(~D[2019-04-24], ~T[17:00:00], ~T[18:00:00]),
                   Periode.new(~D[2019-04-25], ~T[19:00:00], ~T[20:00:00])
                 ]
               )
    end

    test "Liste bleibt unverändert, wenn es nichts zu subtrahieren gibt" do
      intervalle = [Periode.new(~D[2019-04-22], ~T[08:00:00], ~T[15:00:00])]
      assert intervalle == Periode.differenz(intervalle, [])
    end

    # Minuend - Subtrahend = Differenz
    # [----    --------- --   -----]   # Minuend
    # [  ----    ---     -- ----   ]   # Subtrahend
    # [--      --   ----        ---]   # Differenz
    property "Differenz und Subtrahend dürfen sich nicht überschneiden" do
      forall {minuend, subtrahend} <- minuend_und_subtrahend() do
        differenz = Periode.differenz(minuend, subtrahend)

        !ueberschneidung?(differenz, subtrahend)
      end
    end

    def dauer(intervalle) when is_list(intervalle) do
      intervalle |> Enum.reduce(Shared.Dauer.leer(), &Shared.Dauer.addiere(&1, &2))
    end

    # Helpers
    def ueberschneidung?(perioden, andere_perioden) do
      perioden
      |> Enum.any?(fn periode ->
        andere_perioden
        |> Enum.any?(fn andere_periode -> Periode.ueberschneidung?(periode, andere_periode) end)
      end)
    end

    # Generators
    def minuend_und_subtrahend do
      {non_empty(list(periode())), non_empty(list(periode()))}
    end

    def periode do
      let {date_tuple, start, ende} <- {date(), time(), time()} do
        Periode.new(Date.from_erl!(date_tuple), start, ende)
      end
    end

    def time do
      let {hour, minute, second} <- {integer(0, 23), integer(0, 59), integer(0, 59)} do
        {:ok, time} = Time.new(hour, minute, second)
        time
      end
    end

    def date do
      such_that(date_tuple <- date_tuple(), when: valid_date?(date_tuple))
    end

    %{year: max_year} = Date.utc_today()
    @max_year max_year
    def date_tuple do
      let {year, month, day} <- {integer(1999, @max_year), integer(1, 12), integer(1, 31)} do
        {year, month, day}
      end
    end

    def valid_date?({year, month, day}) do
      case Date.from_erl({year, month, day}) do
        {:ok, _date} -> true
        {:error, :invalid_date} -> false
      end
    end
  end
end
