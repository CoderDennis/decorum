These are my thoughts and notes while investigating how this library should be implemented.
I'm including it in the repo to preserve revision history as I find answers to my own questions and evolve the design.

References to Martin are refering to Martin Janiczek. I first learned about the Hypothesis form of shrinking from this YouTube video https://youtu.be/WE5bmt0zBxg?si=fyg6R_O3iRrbuc7_ He also implemented this in elm-test.

Elixir Outlaws ep 2 has a good quote. Something like “shrinking is the real magic of property based testing.” Ep 4 also talks about prop testing and a debate around StreamData being included in Elixir core.

### Internal representation of PRNG history.

We're currently using a list of 32-bit integers, which is the same as the Elm implementation.

Unsigned Integers work best because they shrink easily by dividing by 2 or subtracting 1.

What is the internal representation of integers in the BEAM? Small integer is 1 word (60 bits on 64-bit architecture) See https://www.erlang.org/doc/efficiency_guide/advanced.html

What effect does size of integer stored in PRNG history have on the rand algorithm used? If only storing 32-bit ints, then it doesn't matter.

- [ ] Should we use a bytes as is done in Hypothesis? 
No matter what size ints we store, when a larger value is requested, we need to use more than one of them.

Using smaller integers might make it more important to label chunks of random history the way hypothesis does. I couldn’t find the equivalent in the Elm implementation. Martin confirmed that it's not in the Elm code.

### How is `:rand` thread safe when running ExUnit async true?

We sidestep this question by remembering `:rand.state`.
How does that relate to the given seed?
From https://hexdocs.pm/ex_unit/1.15.4/ExUnit.html#configure/1-options
> `:seed` - an integer seed value to randomize the test suite. This seed is also mixed with the test module and name to create a new unique seed on every test, which is automatically fed into the :rand module. This provides randomness between tests, but predictable and reproducible results. A :seed of 0 will disable randomization and the tests in each file will always run in the order that they were defined in;

Generators in StreamData create functions that take a seed (it’s called seed,
but it’s really `:rand.state()`) and keeps track of the next state. Fuzzers in Elm Test take a prng parameter. (see rollDice in https://github.com/elm-explorations/test/blob/master/src/Fuzz.elm)
The Random prng in Elm also keeps track of the next seed. -- Maybe that's a key ingredient --
**it doesn't matter what calls to `:rand` are made in other threads if our PRNG is keeping the next seed that it will use.**

PRNG history only needs to be preserved for a single test iteration. In `check_all`, we don't need the history for the whole 100 test runs. We only need it for one that fails a test. 
However, we do need to use a new seed for each run. How do other implementations handle this? https://github.com/elm-explorations/test/blob/master/src/Test/Fuzz.elm has a `stepSeed` function that gets the seed for the next run.
We can use `:rand.jump()` for the same purpose.

It's important to not specify a new seed so that we're based on the one ExUnit sets up automatically.

### TODO:

- [x] On prng playback need to distinguish between no history and getting to the end of the history. Tag as :random or :hardcoded ?
With no history it needs to use the same seed as ExUnit, which happens automatically because we start with a call to `:rand.jump()`

- [x] Simple history replay should be easy to test.

- [x] Hanlde getting to the end of prng history. Change `next/1` to `next!/1` and raise EmptyHistoryError.

- [ ] When validating a shrunken history need to distinguish between running out of numbers and no longer failing the test. Should be easy to write a test for this. What is the process of rerunning the test and trying further shrinking? It actually seems similar to genetic algorithms. For a given test, this shouldn’t need to be parallelized.

- [x] Remove `prng` parameter from `check_all` because we need a new one for each test run. Or make it optional.

- [x] Catch errors raised by `body_fn` so we can capture PRNG history and enter shrinking cycle.

- [ ] Raise our own exception type that has good debug output.

- [x] Get end to end with shrinking working with single integer generator.

- [ ] Add `list_of` with shrinking on a list of integers. Use "list is sorted" as the property which should shrink to `[1,0]`.

- [ ] Add support for generating integers larger than the internal representation of the PRNG history which is currently a 32-bit integer. This requires consuming more than one value. The `next` funciton probably needs a byte_count parameter.

- [x] Implement Enumerable protocol for Decorum struct.

- [ ] Implement float generator by copying Elm/Hypothesis implementation. How does it optimize for shrinking? (I initially guessed that it simplified towards 1.0 instead of towards zero, but that wouldn’t produce simpler fractions.) See https://github.com/HypothesisWorks/hypothesis/blob/d55849df92d01a25364aa21a1adb310ee0a3a390/hypothesis-python/src/hypothesis/internal/conjecture/floats.py which was linked to from https://github.com/elm-explorations/test/blob/master/src/Fuzz/Float.elm


- [x] Run the test body N times looking for initial failures. N is how many items we take from the generator. N should be configurable, but start with 100.

- [ ] Add configuration option for how many times to run the test body.

- [ ] Rename PRNG module to Random?
I don’t love the name PRNG.
Maybe flatten the structure while keeping `random/0` and `hardcoded/1` constructor functions.

- [ ] Run the shrinking challenges (https://github.com/jlink/shrinking-challenge)

### How do we make generators composible? What happens when a property uses more than one generator?

Users should be able to create new generators based on the library generators. This may become clear while implementing the list generator.

### How long of lists should the list generator produce?
**StreamData gives lists up to generation size.**
PropEr also uses an internal increasing size parameter. The sized function in PropCheck is used to get the current size parameter. In StreamData sized is a macro and the scale function is used to add a multiple of the size.

What about the biased coin flip for choosing another item? The Elm implementation uses it.
I don’t understand how the shrinker would know that the pair goes together. How could this relate to using the size parameter for affecting the length of the generated lists?

### What is a Generator?

A function that takes in a PRNG struct (and a size?) and returns the next value and an updated PRNG struct. Implementing a stream doesn’t give the updated prng struct from which to get the history. But outside of running properties, we don't need it to do that. 
It could behave like a Stream by default and internally to `check_all` the state could be tracked. The generator function is essentially the same as `next_fun` used by `Stream.unfold`.

### What is a Shrinker?

A function that takes a PRNG history, a generator, and a test function and searches through a stream of shortlex smaller histories.

Iterate through those histories until:
- A. we find one that still fails the test
- B. We run out of possible smaller histories
- C. We try some maximum number of times.

How does it find possible smaller histories? By using some set of strategies or passes?

When it finds a valid smaller history, then starts over with that one?

Individually shrink integers. Try zero, divide by 2, subtract 1, and removing from history. Do we need to keep track of values we’ve used? Might be important to avoid retrying zero a bunch of times.

Do we shrink the first value and then shrink the rest of the history?

Only feed used history into next round of shrinking? Discard unused values at the end of history.

Storing larger integers might make shrinking less efficient because it takes longer to reach low values. 

### Is there a better syntax for defining property tests in Elixir?

**Prefer StreamData syntax for macros like `check all`** instead of PropCheck (and PropEr) syntax of `forall`.

Body of `check all` uses asserts. Body of `forall` returns boolean. Using asserts seems more like what a user of ExUnit would be familiar with.

Is there a way to do it inside the test macro instead of using a property macro? Or just making the property macro the only thing that’s needed? Why require a macro inside the body of another macro?
From https://github.com/whatyouhide/stream_data/blob/main/lib/ex_unit_properties.ex it looks like 
**the property macro is a convenience for marking tests as properties.**

### Other thoughts or questions

In Elm implementation Fuzz.elm, why does forcedChoice need to consume a random number? How is that different from constant?
Martin confirmed that throwing an error instead of just accepting it may not be right.

I considered setting up property test macros and using them to build up tests for the system, but I'm not sure that would help.
Just use `check_all` directly without the macros. Add macros later.

How important is it for `Decorum.uniform_integer/1` to produce uniformly random values?
I tried the code from https://rosettacode.org/wiki/Verify_distribution_uniformity/Chi-squared_test and its `chi2IsUniform/2` function returned false for all the examples I ran.
The `chi2Probability/2` results were around `1.69e-13` when they were expected to be greater than `0.05`.