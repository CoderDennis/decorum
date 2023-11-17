defmodule Decorum.History do
  @moduledoc """
  History is currently a list of non-negative integers.

  It might make sense to expand it to a structure where groups of random bytes could be labeled.

  The original Hypothesis implementation uses labels. The Elm test implementation does not.
  """

  @type t :: list(non_neg_integer())

  @doc """
  Takes a PRNG history and shrinks it to smaller values.

  Smaller is defined as shorter or lower sort order.

  All the results are guaranteed to be smaller than the input,
  but there is no guarantee on the order of the results when compared to each other.
  """
  @spec shrink(t()) :: Enumerable.t(t())
  def shrink([]), do: []

  def shrink([i]) do
    shrink_int(i)
    |> Enum.map(fn s -> [s] end)
  end

  def shrink(history) do
    Stream.concat(
      shrink_length(history),
      shrink_values(history)
    )
  end

  # Removes 1 item at a time.
  # Should be expanded to remove varying sized chunks.
  # Also should remove segments from within the history instead of only at the beginning.
  defp shrink_length(history) do
    Stream.unfold(history, fn
      [_h, h2 | t] -> {[h2 | t], [h2 | t]}
      _ -> nil
    end)
  end

  defp shrink_values([h | t]) do
    Stream.resource(
      fn -> {[], h, t} end,
      fn
        :halt ->
          {:halt, :ok}

        {previous, current, []} ->
          {
            shrink_int(current)
            |> Enum.map(fn c -> previous ++ [c] end),
            :halt
          }

        {previous, current, [next | rest] = remaining} ->
          {
            shrink_int(current)
            |> Enum.map(fn c -> previous ++ [c] ++ remaining end),
            {previous ++ [current], next, rest}
          }
      end,
      fn _ -> :ok end
    )
    |> Stream.uniq()
  end

  @doc """
  Shrinks a single integer into smaller possible values.

  Order of values is not guaranteed, but 0 is the first result.
  """
  @spec shrink_int(non_neg_integer()) :: Enumerable.t(non_neg_integer())
  def shrink_int(0), do: []

  def shrink_int(i) do
    Stream.resource(
      fn -> {i - 1, MapSet.new()} end,
      fn
        {n, _seen} when n < 1 ->
          {:halt, :ok}

        {n, seen} ->
          div_2 = div(n, 2)
          new_values = MapSet.new([0, n, div_2, n - 1])
          {MapSet.difference(new_values, seen), {div_2, MapSet.union(new_values, seen)}}
      end,
      fn _ -> :ok end
    )
  end
end
