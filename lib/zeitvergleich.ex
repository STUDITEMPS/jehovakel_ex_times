defprotocol Shared.Zeitvergleich do
  @fallback_to_any true

  @spec frueher_als?(struct(), struct()) :: boolean()
  def frueher_als?(self, other)

  @spec zeitgleich?(struct(), struct()) :: boolean()
  def zeitgleich?(self, other)

  @spec frueher_als_oder_zeitgleich?(struct(), struct()) :: boolean()
  def frueher_als_oder_zeitgleich?(self, other)
end

defimpl Shared.Zeitvergleich, for: NaiveDateTime do
  def frueher_als?(%NaiveDateTime{} = self, %NaiveDateTime{} = other) do
    NaiveDateTime.compare(self, other) == :lt
  end

  def zeitgleich?(%NaiveDateTime{} = self, %NaiveDateTime{} = other) do
    NaiveDateTime.compare(self, other) == :eq
  end

  def frueher_als_oder_zeitgleich?(%NaiveDateTime{} = self, %NaiveDateTime{} = other) do
    self |> frueher_als?(other) || self |> zeitgleich?(other)
  end
end

defimpl Shared.Zeitvergleich, for: DateTime do
  def frueher_als?(%DateTime{} = self, %DateTime{} = other) do
    DateTime.compare(self, other) == :lt
  end

  def zeitgleich?(%DateTime{} = self, %DateTime{} = other) do
    DateTime.compare(self, other) == :eq
  end

  def frueher_als_oder_zeitgleich?(%DateTime{} = self, %DateTime{} = other) do
    self |> frueher_als?(other) || self |> zeitgleich?(other)
  end
end

defimpl Shared.Zeitvergleich, for: Time do
  def frueher_als?(%Time{} = self, %Time{} = other) do
    Time.compare(self, other) == :lt
  end

  def zeitgleich?(%Time{} = self, %Time{} = other) do
    Time.compare(self, other) == :eq
  end

  def frueher_als_oder_zeitgleich?(%Time{} = self, %Time{} = other) do
    self |> frueher_als?(other) || self |> zeitgleich?(other)
  end
end

defimpl Shared.Zeitvergleich, for: Date do
  def frueher_als?(%@for{} = self, %@for{} = other) do
    @for.compare(self, other) == :lt
  end

  def zeitgleich?(%@for{} = self, %@for{} = other) do
    @for.compare(self, other) == :eq
  end

  def frueher_als_oder_zeitgleich?(%@for{} = self, %@for{} = other) do
    self |> frueher_als?(other) || self |> zeitgleich?(other)
  end
end
