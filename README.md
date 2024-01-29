# Decorum

Property-based testing for Elixir with **shrinking that just works.**

This is an implementation of internal shrinking, which was first invented for the [Hypothesis](https://github.com/HypothesisWorks/hypothesis) library in Python.

Shrinking is the killer feature of property-based testing. It is the process of reducing a randomly generated failing test case into a small human-readable example. 
Other approaches to shrinking require code to be explicitly written to shrink each specific type of generated data.
The approach we are using is built on the concept that the series of random numbers that feeds the data generators can be simplified in a unified manner that will lead to simpler test cases for all data generators automatically.

There are specific implementations for some generators (such as `float` which is on the TODO list for this library) that are fine tuned for this method of shrinking. 
However, new generators built by composing the generators provided here should shrink well without additional thought or effort.
If you find an example of a generator and a test case that does not shrink well, please submit an issue so we can look into it.

## Status

I'm currently in proof-of-concept mode. I've borowed some concepts from [StreamData](https://github.com/whatyouhide/stream_data) which is the de facto standard Elixir library for property-based testing. I've also leaned heavily on the [Elm test](https://github.com/elm-explorations/test) implementation.

There are no macros yet, so property tests are just regular ExUnit tests with names starting with "property" by convention. 

See [NOTES.md](NOTES.md) for my ongoing thoughts, questions, and TODOs.

## Background

- https://youtu.be/WE5bmt0zBxg?si=fyg6R_O3iRrbuc7_ I first learned about the Hypothesis form of shrinking PRNG history from this talk by Martin Janiczek. He also implemented it in elm-test.

- https://hypothesis.works/articles/compositional-shrinking/ 
David R. MacIver, the creator of Hypothesis and the inventor of the internal shrinking concept we are using.
  > Hypothesis takes the “Shrinking outputs can be done by shrinking inputs” idea to its logical conclusion and has a single unified intermediate representation that all generation is based off.

- https://drmaciver.github.io/papers/reduction-via-generation-preview.pdf research paper by David R. MacIver and Alastair F. Donaldson
  > The key idea of internal reduction is to manipulate the underlying source of randomness
  consumed by a random generator, in order to cause the generator to produce smaller test
  cases automatically. The final reduced test case is constructed as if the generator had been
  implausibly lucky and produced a small and readable test case by chance.

## Installation

The package can be installed
by adding `decorum` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:decorum, "~> 0.1.0"}
  ]
end
```

Documentation is generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). The docs can
be found at <https://hexdocs.pm/decorum>.

## ElixirConf EU 2024

I will be presenting a talk about internal shrinking and this library at [ElixirConf EU 2024](https://www.elixirconf.eu/talks/the-magic-of-internal-shrinking-for-property-based-testing/) in Lisbon on April 18-19.