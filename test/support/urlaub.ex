defmodule Urlaub do
  @moduledoc false
  use Ecto.Schema
  use Shared.Datumsbereich, beginn: :von, ende: :bis

  schema "urlaube" do
    field :von, :date
    field :bis, :date
    belongs_to :vertrag, Vertrag
  end
end
