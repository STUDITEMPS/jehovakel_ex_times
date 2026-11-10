defprotocol Shared.ZeitraumProtokoll do
  @type interval :: %Timex.Interval{
          left_open: false,
          right_open: true,
          from: NaiveDateTime.t(),
          until: NaiveDateTime.t()
        }

  @type zeitraum :: Date.Range.t() | interval()

  @spec zeitraum(t) :: zeitraum()
  def zeitraum(zeitraum)

  @impl true
  defmacro __deriving__(module, options) do
    struct_keys = Enum.sort(Enum.map(Macro.struct_info!(module, __CALLER__), & &1.field))

    if zeitraum_key = Keyword.get(options, :zeitraum) do
      validate_key!(zeitraum_key, struct_keys, module)

      zeitraum_key_impl(module, zeitraum_key)
    else
      default = if :beginn not in struct_keys and :start in struct_keys, do: :start, else: :beginn
      beginn_key = Keyword.get(options, :beginn, default)
      ende_key = Keyword.get(options, :ende, :ende)

      validate_key!(beginn_key, struct_keys, module)
      validate_key!(ende_key, struct_keys, module)

      beginn_ende_key_impl(module, beginn_key, ende_key)
    end
  end

  defp validate_key!(key, struct_keys, module) do
    if key not in struct_keys do
      raise ArgumentError,
            "#{inspect(key)} is not a key of %#{inspect(module)}{}. Keys are: #{inspect(struct_keys)}"
    end
  end

  defp zeitraum_key_impl(module, zeitraum_key) do
    quote do
      defimpl Shared.ZeitraumProtokoll, for: unquote(module) do
        def zeitraum(zeitraum) do
          case zeitraum.unquote(zeitraum_key) do
            %Date{} = datum -> Date.range(datum, datum)
            %Date.Range{} = zeitraum -> zeitraum
            %Timex.Interval{} = zeitraum -> zeitraum
            zeitraum -> Shared.ZeitraumProtokoll.zeitraum(zeitraum)
          end
        end
      end
    end
  end

  defp beginn_ende_key_impl(module, beginn_key, ende_key) do
    quote do
      defimpl Shared.ZeitraumProtokoll, for: unquote(module) do
        def zeitraum(zeitraum) do
          start = zeitraum.unquote(beginn_key)
          ende = zeitraum.unquote(ende_key)

          case {start, ende} do
            {%Date{}, %Date{}} -> Date.range(start, ende)
            _ -> Shared.Zeitperiode.new(start, ende)
          end
        end
      end
    end
  end
end

defimpl Shared.ZeitraumProtokoll, for: [Shared.Month, Shared.Week] do
  def zeitraum(%@for{} = zeitraum), do: @for.to_range(zeitraum)
end

defimpl Shared.ZeitraumProtokoll, for: [Shared.Month.Range, Shared.Week.Range] do
  def zeitraum(%@for{} = month_range), do: @for.to_date_range(month_range)
end

defimpl Shared.ZeitraumProtokoll, for: Date do
  def zeitraum(datum), do: Date.range(datum, datum)
end

defimpl Shared.ZeitraumProtokoll, for: [Date.Range, Timex.Interval] do
  def zeitraum(zeitraum), do: zeitraum
end
