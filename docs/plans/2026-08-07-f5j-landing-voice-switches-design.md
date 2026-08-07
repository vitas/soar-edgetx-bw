# F5J Landing Voice Switch Design

## Context

The three Pocket F5J templates already use logical switch `L7`, defined from
`SD2`, to finish a flight and open score entry. Their landing voice special
functions are separate: the `f3jlnd` and `crowof` tracks are currently assigned
to `L35` and `L45`, which are timing-related logical switches rather than the
physical landing switch positions.

## Requirements

- Moving SD down (`SD2`) announces landing.
- Moving SD up (`SD0`) announces landing off/crow off.
- `L7` remains defined from `SD2` so flight completion and score entry do not
  change.
- X-tail, M-tail, and V-tail F5J templates stay consistent.

## Considered Approaches

1. Assign the voice special functions directly to `SD2` and `SD0`. This is the
   smallest change and expresses the physical control mapping clearly.
2. Add logical switches for both SD positions and assign the voice functions to
   those logical switches. This adds indirection without adding behavior.
3. Repurpose `L35` and `L45` as the SD position switches. This risks changing
   other inherited Sense behavior and makes the fix harder to audit.

## Decision

Use direct physical switch assignments. In each Pocket F5J template, change the
special function playing `f3jlnd` to `SD2` and the special function playing
`crowof` to `SD0`. Do not change the logical-switch definitions or the Lua score
keeper.

Add a regression test that checks both switch/track pairs in all three F5J
templates. Update the README switch table to document the landing-on and
landing-off announcement positions.

## Verification

Run the template regression test, the complete repository test suite, and the
repository linter. The final verification command is `make verify`.
