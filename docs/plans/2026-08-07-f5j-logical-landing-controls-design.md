# F5J Logical Landing Controls Design

## Context

The Pocket F5J templates currently use `L7 = SD2` for score entry, but their
actual proportional crow path is disabled by the `BrkOff` replacement mix on
`L36`. `L36` is an inherited sticky logical switch that is not controlled by
SD, so moving SD down does not release the brake override and the flap,
aileron, and elevator landing movements remain off.

The flight-timer announcement also uses `L7`, so it runs on the landing switch.
The previous voice-only correction assigned physical SD positions directly to
special functions, which is inconsistent with the other model templates.

## Requirements

- Moving SD down enables proportional crow controlled by the throttle stick.
- Moving SD up forces crow off.
- Moving SB down enables the repeating flight-time announcement.
- Landing score entry remains on SD down.
- Mixes, special functions, timers, and scripts consume logical switches, not
  physical switch sources.
- X-tail, M-tail, and V-tail F5J templates remain behaviorally identical where
  their tail layouts do not require differences.

## Considered Approaches

1. Reuse the existing logical roles: keep `L7` for landing on, add `L12` for the
   SB time announcement, and redefine the existing `BrkOff` gate `L36` for
   landing off. This keeps consumers logical and requires the fewest changes.
2. Add separate new logical switches for both SB time and SD crow-off, then
   change the `BrkOff` mix to the new crow-off switch. This preserves the old
   `L36` chain but adds unused indirection.
3. Repurpose `L35` or `L45` for crow-off. Those switches participate in the
   inherited landing timing chain, making the resulting control graph harder to
   audit.

## Decision

Use the existing logical-switch architecture with clear dedicated roles:

- `L7`: `FUNC_AND` with `SD2,NONE` (existing) — landing on and score entry.
- `L12`: `FUNC_AND` with `SB2,NONE` (new) — flight-time announcement.
- `L36`: `FUNC_AND` with `SD0,NONE` (redefined) — landing/crow off.

Keep the `BrkOff` replacement mix assigned to `L36`. When SD is up, `L36` is
true and the mix replaces the proportional brake value with the crow-off value.
When SD is down, `L36` is false, so input `I4` remains connected to the throttle
stick and drives proportional crow through the existing virtual-channel and
surface mix chain.

Assign the landing-on voice to `L7`, landing-off/crow-off voice to `L36`, and
the repeating `Tmr1` announcement to `L12`. The Lua score keeper continues to
read `L7`; no Lua changes are needed.

## Testing

Add regression coverage for all three F5J templates that verifies:

- the three logical switch definitions;
- the `BrkOff` replacement mix remains gated by `L36`;
- the proportional brake input remains sourced from the throttle stick;
- the timer and landing special functions use `L12`, `L7`, and `L36`;
- no landing or timer special function uses a physical switch directly.

Update the README switch table and run `make verify`, which includes the
repository linter, YAML checks, Lua loading checks, and model-template tests.
