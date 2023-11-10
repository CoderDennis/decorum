# Decorum

Property-based testing for Elixir with shrinking that just works.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `decorum` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:decorum, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/decorum>.

## Background

- https://youtu.be/WE5bmt0zBxg?si=fyg6R_O3iRrbuc7_ I first learned about the Hypothesis form of shrinking PRNG history from this talk by Martin Janiczek. He also implemented it in elm-test.

- https://hypothesis.works/articles/compositional-shrinking/ 
David R. MacIver, the creator of Hypothesis and the inventor of the internal shrinking concept we are using here.
  > Hypothesis takes the “Shrinking outputs can be done by shrinking inputs” idea to its logical conclusion and has a single unified intermediate representation that all generation is based off.

- https://drmaciver.github.io/papers/reduction-via-generation-preview.pdf research paper by David R. MacIver and Alastair F. Donaldson
  > The key idea of internal reduction is to manipulate the underlying source of randomness
  consumed by a random generator, in order to cause the generator to produce smaller test
  cases automatically. The final reduced test case is constructed as if the generator had been
  implausibly lucky and produced a small and readable test case by chance.

