defmodule Decorum.History do
  @moduledoc false

  alias Decorum.History.Chunk

  @type t :: list(non_neg_integer())

  @doc """
  Compare two histories acording to shortlex order.

  Shorter histories are always considered smaller.

  Equal length histories are compared using normal Erlang ordering.
  """
  @spec compare(t(), t()) :: :lt | :eq | :gt
  def compare(history1, history2) do
    case {{Enum.count(history1), history1}, {Enum.count(history2), history2}} do
      {{length1, _}, {length2, _}} when length1 > length2 -> :gt
      {{length1, _}, {length2, _}} when length1 < length2 -> :lt
      {{_, history1}, {_, history2}} when history1 > history2 -> :gt
      {{_, history1}, {_, history2}} when history1 < history2 -> :lt
      _ -> :eq
    end
  end

  @spec delete_chunk(t(), Chunk.t()) :: t()
  def delete_chunk(history, chunk) do
    {pre, _, post} = get_chunked_parts(history, chunk)

    Enum.concat(
      pre,
      post
    )
  end

  @spec replace_chunk(t(), Chunk.t(), t()) :: t()
  def replace_chunk(history, chunk, new_values) do
    {pre, old_values, post} = get_chunked_parts(history, chunk)

    if old_values != new_values do
      Enum.concat([
        pre,
        new_values,
        post
      ])
    else
      history
    end
  end

  @spec replace_chunk_with_zero(t(), Chunk.t()) :: t()
  def replace_chunk_with_zero(history, %Chunk{length: length} = chunk) do
    replace_chunk(history, chunk, List.duplicate(0, length))
  end

  @spec sort_chunk(t(), Chunk.t()) :: t()
  def sort_chunk(history, %Chunk{length: 1}), do: history

  def sort_chunk(history, chunk) do
    {pre, chunk_elements, post} = get_chunked_parts(history, chunk)

    sorted = Enum.sort(chunk_elements)

    if sorted != chunk_elements do
      Enum.concat([
        pre,
        sorted,
        post
      ])
    else
      history
    end
  end

  @spec get_chunk_elements(t(), Chunk.t()) :: t()
  def get_chunk_elements(history, chunk) do
    {_, chunk_elements, _} = get_chunked_parts(history, chunk)
    chunk_elements
  end

  defp get_chunked_parts(history, %Chunk{start: start, length: length}) do
    {pre, rest} = Enum.split(history, start)
    {chunk_elements, post} = Enum.split(rest, length)
    {pre, chunk_elements, post}
  end
end
