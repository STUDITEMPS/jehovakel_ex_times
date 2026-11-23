defmodule Vertrag do
  @moduledoc false
  use Ecto.Schema
  use Shared.Datumsbereich, beginn: :gueltig_ab, ende: :gueltig_bis

  schema "vertraege" do
    field :gueltig_ab, :date
    field :gueltig_bis, :date
  end
end
