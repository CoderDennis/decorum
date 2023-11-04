This is a copy of my thoughts and notes while investigating how this library should be implemented. I'm including it in the repo so to preserve revision history as I find answers to my own questions and evolve the design.


On prng playback need to distinguish between no history and getting to the end of the history. Tag as :random or :hardcoded ?
With no history needs to use the same seed as ExUnit, which should happen automatically. But do we need to be able to specify the seed for internal testing? Make this explicit by passing the seed from ExUnit.configuration()
Should the history store floats from :rand.uniform() or should it store integers? I thought it should store 64 bit unsigned integers because those can easily be shrunk by dividing by 2 or subtracting 1. And float (see below) is defined as an interpretation of 64 bits. Will the integer generator ever need to produce integers larger than 64 bits?
Would 32 bit integers work? Floats would consume 2 of them as in the Elm implementation. If a larger range was requested, then take 2 or more of them? What is the internal representation of integers in the BEAM? Small integer is 1 word (60 bits on 64-bit architecture) See https://www.erlang.org/doc/efficiency_guide/advanced.html
What effect does size of integer stored in PRNG history have on the rand algorithm used? If only storing 32-bit ints, then it doesn't matter.
Use 32-bit integers as history.
Simple replay should be easy to test.
Needs to work with async tests. How does that relate to the given seed?
From https://hexdocs.pm/ex_unit/1.15.4/ExUnit.html#configure/1-options
:seed - an integer seed value to randomize the test suite. This seed is also mixed with the test module and name to create a new unique seed on every test, which is automatically fed into the :rand module. This provides randomness between tests, but predictable and reproducible results. A :seed of 0 will disable randomization and the tests in each file will always run in the order that they were defined in;
Get end to end working with single integer shrinking and then stream of integers. Use these to test prng history shrinking.
How does the float generator optimize for shrinking? (I initially guessed that it simplified towards 1.0 instead of towards zero, but that wouldn’t produce simpler fractions. I ) See https://github.com/HypothesisWorks/hypothesis/blob/d55849df92d01a25364aa2 1a1adb310ee0a3a390/hypothesis- python/src/hypothesis/internal/conjecture/floats.py which was linked to from https://github.com/elm-explorations/test/blob/master/src/Fuzz/Float.elm
If rand.uniform is given a range, then shrinking prng history should respect that range. Is there a way to apply the range on an already shrunken random value? Random int in range hi - lo plus lo. Copy from elm implementation because the range could be negative.
When validating a shrunken history need to distinguish between running out of numbers and no longer failing the test. Should be easy to write a test for this.
What is the process of rerunning the test and trying further shrinking? It actually seems similar to genetic algorithms. For a given test, this shouldn’t need to be parallelized.
There’s also the process of rerunning the test N times looking for initial failures. N is how many items we take from the generator. N should be configurable, but start with 100.
Can compiling a property ensure that :rand was not used outside our PRNG wrapper? It would need to prevent things like Enum.random. No need for this because we are tracking rand state
How is :rand thread safe when running ExUnit async true? We sidestep this question by remembering :rand.state
How long of lists should the list generator produce? StreamData gives lists up to generation size. PropEr also uses an internal increasing size parameter. The sized function in PropCheck is used to get the current size parameter. In StreamData sized is a macro and the scale function is used to add a multiple of the size.
What about the biased coin flip for choosing another item? I don’t understand how the shrinker would know that the pair goes together.
In Elm implementation Fuzz.elm, why does forcedChoice need to consume a random number? How is that different from constant? Martin confirmed that throwing an error instead of just accepting it may not be right.
Do we need to label chunks of random history the way hypothesis does? I couldn’t find the equivalent in the Elm implementation. Martin confirmed that it's not in the Elm code.
Generators in StreamData create functions that take a seed (it’s called seed, but it’s really :rand.state() ) and keeps track of the next state. Fuzzers in Elm Test take a prng parameter. (see rollDice in https://github.com/elm- explorations/test/blob/master/src/Fuzz.elm) The Random prng in Elm also keeps track of the next seed. *** Maybe that's a key ingredient -- then it doesn't matter what calls to :rand are made in other threads if our PRNG is keeping the next seed that it will use.
Add a Generator behaviour?
A Generator is one of these things:
A. a function that takes in a PRNG struct (and a size?) and acts as an enumerable Stream. Implementing a stream doesn’t give the updated prng struct from which to get the history. But outside of running properties we don't need it to do that. It could behave like a Stream by default and internally to check_all the state could be tracked. Can a generator implement the next_fun used by Stream.unfold? Yes
Implement Enumerable for Decorum struct using stream function.
B. A callback that receives 1 or more random integers and returns a value along
with an atom that signals continuation or halt. Could it be passed in a function that gets the next random number in the event more than one is needed? An init function that returns how many random numbers the callback needs? Then the prng history could be grouped by those chunks. I’m not sure that composes very well. There would be a difference between a primitive generator and one that built on existing generators.
I need to read more of the property testing book before fully answering this question.
Elixir Outlaws ep 2 has a good quote. Something like “shrinking is the real magic of property based testing.” Ep 4 also talks about prop testing and a debate around StreamData being included in Elixir core.
Is there a better syntax for defining property tests in Elixir?
Prefer StreamData syntax for macros like `check all` instead of PropCheck (and PropEr) syntax of `forall`? Yes.
Body of `check all` uses asserts. Body of `forall` returns boolean. Using asserts seems more like what a user of ExUnit would be familiar with.
Is there a way to do it inside the test macro instead of using a property macro? Or just making the property macro the only thing that’s needed? Why require a macro inside the body of another macro? From https://github.com/whatyouhide/stream_data/blob/main/lib/ex_unit_properties.ex it looks like the property macro is a convenience for marking tests as properties.
PRNG history only needs to be preserved for a single test iteration. In check_all, we don't need the history for the whole 100 test runs. We only need it for one that fails a test.
Catch errors raised by body_fn so we can capture PRNG history and enter shrinking cycle. Also raise our own exception type that has good debug output.
I considered setting up property test macros and using them to build up tests for the system, but I'm not sure that would help. What properties do we test for generators or shrinking? Eventually I want to run the shrinking challenges (https://github.com/jlink/shrinking-challenge)
                       