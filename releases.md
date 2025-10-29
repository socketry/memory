# Releases

## v0.8.1

  - Skip over `ObjectSpace::InternalObjectWrapper` instances in `Memory::Usage.of` to avoid unbounded recursion.

## v0.8.0

  - Removed old `RSpec` integration.
  - Introduced `Memory::Usage` and `Memory::Usage.of(object)` which recursively computes memory usage of an object and its contents.

## v0.7.1

  - Ensure aggregate keys are safe for serialization (and printing).

## v0.7.0

  - Add `Memory::Sampler#as_json` and `#to_json`.

## v0.6.0

  - Add agent context.
