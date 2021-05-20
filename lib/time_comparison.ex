defprotocol Shared.TimeComparison do
  @fallback_to_any true

  @spec earlier_than?(struct(), struct()) :: boolean()
  def earlier_than?(self, other)

  @spec equal_to?(struct(), struct()) :: boolean()
  def equal_to?(self, other)

  @spec earlier_than_or_equal_to?(struct(), struct()) :: boolean()
  def earlier_than_or_equal_to?(self, other)
end

defimpl Shared.TimeComparison, for: Any do
  def earlier_than?(%module{} = self, %module{} = other) do
    module.compare(self, other) == :lt
  end

  def equal_to?(%module{} = self, %module{} = other) do
    module.compare(self, other) == :eq
  end

  def earlier_than_or_equal_to?(%module{} = self, %module{} = other) do
    self |> earlier_than?(other) || self |> equal_to?(other)
  end
end
