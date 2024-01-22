defmodule HistoryTest do
  use ExUnit.Case, async: true

  alias Decorum.History
  alias Decorum.History.Chunk

  test "delete_chunk removes the specified chunk" do
    assert History.delete_chunk([1, 2, 3, 4, 5], Chunk.new(2, 2)) == [1, 2, 5]
  end

  test "delete_chunk removes the specified chunk at the beginning of history" do
    assert History.delete_chunk([1, 2, 3, 4, 5], Chunk.new(0, 2)) == [3, 4, 5]
  end

  test "replace_chunk replaces the specified chunk with given values" do
    assert History.replace_chunk([1, 2, 3, 4, 5], Chunk.new(2, 2), [9, 10]) == [1, 2, 9, 10, 5]
  end

  test "replace_chunk replaces the specified chunk at beginning of history with given values" do
    assert History.replace_chunk([1, 2, 3, 4, 5], Chunk.new(0, 2), [9, 10]) == [9, 10, 3, 4, 5]
  end

  test "replace_chunk replaces the specified chunk at end of history with given values" do
    assert History.replace_chunk([1, 2, 3, 4, 5], Chunk.new(3, 2), [9, 10]) == [1, 2, 3, 9, 10]
  end

  test "replace_chunk_with_zero sets values in chunk to zero" do
    assert History.replace_chunk_with_zero([1, 2, 3, 4, 5], Chunk.new(2, 2)) == [1, 2, 0, 0, 5]
  end

  test "sort_chunk sorts the specified chunk" do
    assert History.sort_chunk([5, 4, 3, 2, 1], Chunk.new(2, 2)) == [5, 4, 2, 3, 1]
  end
end
