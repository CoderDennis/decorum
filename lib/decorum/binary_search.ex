defmodule Decorum.BinarySearch do
  @moduledoc false

  # experimental generic version of binary search.

  @type int_list :: list(non_neg_integer())

  @doc """
  Take in a list of integers and perform a binary search on each value
  to find the lowest values that still cause the whole list to return true
  for the given `fun`.
  """
  @spec binary_search(int_list(), (int_list() -> boolean())) :: int_list()
  def binary_search([], _), do: []

  def binary_search([a], _), do: a

  def binary_search([first_value | post], fun) when is_function(fun, 1) do
    binary_search(fun, [], post, 0, first_value)
  end

  _ = """
  `fun` takes in the whole list and returns true or false.

  `low` starts at zero and `high` starts at the current value.

  While searching, `high` is the lowest known value that causes `fun` to return true while
  `low` is known to cause `fun` to return false.

  We stop searching when `low` is greater than or equal to `high - 1`
  and then move on to the next value in the list.
  """

  defp binary_search(_fun, pre, [], low, high) when low >= high - 1 do
    Enum.reverse([high | pre])
  end

  defp binary_search(fun, pre, [next | post], low, high) when low >= high - 1 do
    binary_search(fun, [high | pre], post, 0, next)
  end

  defp binary_search(fun, pre, post, low, high) do
    mid = div(low + high, 2)
    list =
      [mid | pre]
      |> Enum.reverse()
      |> Enum.concat(post)

    if fun.(list) do
      binary_search(fun, pre, post, low, mid)
    else
      binary_search(fun, pre, post, mid, high)
    end
  end
end
