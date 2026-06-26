# ADR-0010: Temporal / Allen interval algebra WOQL operators

Date: 2026-06-25
Status: Accepted (implementation in v0.3.2)

## Context

The gap analysis (`baoulo/reviews/gap-analysis-3.2.md`) identified 19 temporal
operators in the Python client that were absent from the Elixir client. These
cover interval construction, Allen's interval algebra relations, date
arithmetic, calendar operations, and range utilities.

TerminusDB 12 supports these as first-class WOQL JSON-LD `@type` values.

## Decision

Implement all 19 operators as functional builders in the `WOQL` module, matching
the Python client's JSON-LD `@type` values exactly.

### Operators

**Interval constructors (3):**
- `interval/3` → `Interval`
- `interval_start_duration/3` → `IntervalStartDuration`
- `interval_duration_end/3` → `IntervalDurationEnd`

**Allen relations (2):**
- `interval_relation/5` → `IntervalRelation`
- `interval_relation_typed/3` → `IntervalRelationTyped`

**Date arithmetic (1):**
- `date_duration/3` → `DateDuration`

**Day operations (2):**
- `day_after/2` → `DayAfter`
- `day_before/2` → `DayBefore`

**Weekday (2):**
- `weekday/2` → `Weekday`
- `weekday_sunday_start/2` → `WeekdaySundayStart`

**ISO week (1):**
- `iso_week/3` → `IsoWeek`

**Month operations (4):**
- `month_start_date/2` → `MonthStartDate`
- `month_end_date/2` → `MonthEndDate`
- `month_start_dates/3` → `MonthStartDates`
- `month_end_dates/3` → `MonthEndDates`

**Range utilities (4):**
- `in_range/3` → `InRange`
- `sequence/5` → `Sequence` (step/count default `nil`)
- `range_min/2` → `RangeMin`
- `range_max/2` → `RangeMax`

### Value wrappers

Temporal operands use the `Value` wrapper (same as comparison/string ops),
consistent with the 4-wrapper model from ADR-0008.

### Encoder/decoder

Each operator gets a dedicated `encode/1` clause in `Encoder` and a `decode/1`
clause in `Decoder`. `Sequence` omits `step`/`count` fields when `nil`.

## Consequences

- 19 new operators, 19 encoder clauses, 19 decoder clauses.
- ~57 new unit tests (builder + encode + round-trip per op).
- Property test generators extended for temporal ops.

## Alternatives considered

1. **Subset only** — rejected (all 19 are in the Python client; partial
   coverage would be confusing).
2. **Separate `WOQL.Temporal` module** — rejected (ops are WOQL operators, not
   a separate DSL; keeping them in `WOQL` matches Python).
