# Releases

## v0.11.0

  - Remove support for `Memory::Usage.of(..., via:)` and instead use `Memory::Graph.for` which collects more detailed usage until the specified depth, at which point it delgates to `Memory::Usage.of`. This should be more practical.

## v0.10.0

  - Add support for `Memory::Usage.of(..., via:)` for tracking reachability of objects.
  - Introduce `Memory::Graph` for computing paths between parent/child objects.

## v0.9.0

  - Explicit `ignore:` and `seen:` parameters for `Memory::Usage.of` to allow customization of ignored types and tracking of seen objects.

## v0.8.4

  - Fix bugs when printing reports due to interface mismatch with `Memory::Usage`.

## v0.8.3

  - Handle `Memory::Usage.of(number)` without error.

## v0.8.2

  - Fix several formatting issues.

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
