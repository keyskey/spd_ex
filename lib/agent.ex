defmodule SpdEx.Agent do
  @moduledoc """
  Define agent object. Agent has ID, neighbor's ID, point, strategy, and next strategy as a property.
  """
  defstruct id: nil, neighbors_id: nil, point: nil, strategy: nil, next_strategy: nil
end
