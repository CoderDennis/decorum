defmodule Decorum.History.Chunk do
  @moduledoc false

  defstruct [:start, :length]

  @type t :: %__MODULE__{start: non_neg_integer(), length: non_neg_integer()}

  @spec new(non_neg_integer(), non_neg_integer()) :: t
  def new(start, length) do
    %__MODULE__{start: start, length: length}
  end

  @spec chunks(non_neg_integer(), non_neg_integer()) :: list(t)
  def chunks(history_length, chunk_length) do
    0..(history_length - chunk_length)
    |> Enum.map(fn start -> new(start, chunk_length) end)
  end
end
