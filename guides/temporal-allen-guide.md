# Temporal & Allen Interval Algebra Guide

TerminusDB provides 19 temporal operators for working with time intervals, dates, and Allen's interval algebra. This guide covers the key operations.

## Intervals

### Constructing intervals

```elixir
import TerminusDB.WOQL

# Construct a half-open interval [start, end)
query = interval("v:Start", "v:End", "v:Interval")

# With a known duration
query = interval_start_duration("v:Start", "v:Duration", "v:Interval")
query = interval_duration_end("v:Duration", "v:End", "v:Interval")
```

## Allen's Interval Algebra

Allen's interval algebra defines 13 relations between time intervals:

```elixir
import TerminusDB.WOQL

# Classify the relationship between two intervals
query = interval_relation("v:Relation", "v:XStart", "v:XEnd", "v:YStart", "v:YEnd")

# For typed intervals (xdd:dateTimeInterval)
query = interval_relation_typed("v:Relation", "v:X", "v:Y")
```

The possible relations are: `before`, `after`, `meets`, `met_by`, `overlaps`,
`overlapped_by`, `during`, `contains`, `starts`, `started_by`, `finishes`,
`finished_by`, `equals`.

## Date arithmetic

```elixir
import TerminusDB.WOQL

# Duration between two dates (end-of-month preserving)
query = date_duration("v:Start", "v:End", "v:Duration")

# Day after / before
query = day_after("v:Date", "v:NextDay")
query = day_before("v:Date", "v:PrevDay")
```

## Calendar operations

### Weekday

```elixir
import TerminusDB.WOQL

# ISO 8601 weekday (Monday=1, Sunday=7)
query = weekday("v:Date", "v:Weekday")

# US convention (Sunday=1, Saturday=7)
query = weekday_sunday_start("v:Date", "v:Weekday")
```

### ISO week

```elixir
import TerminusDB.WOQL

# ISO 8601 week-numbering year and week
query = iso_week("v:Date", "v:Year", "v:Week")
```

### Month operations

```elixir
import TerminusDB.WOQL

# First/last day of a month
query = month_start_date("v:YearMonth", "v:Date")
query = month_end_date("v:YearMonth", "v:Date")

# Generators: every first/last of month in [start, end)
query = month_start_dates("v:Date", "v:Start", "v:End")
query = month_end_dates("v:Date", "v:Start", "v:End")
```

## Range utilities

```elixir
import TerminusDB.WOQL

# Test if value is in half-open range [start, end)
query = in_range("v:Value", 10, 100)

# Generate a sequence
query = sequence("v:Value", 1, 10)           # 1..9
query = sequence("v:Value", 1, 10, 2)        # 1, 3, 5, 7, 9 (step=2)
query = sequence("v:Value", 1, 10, 2, 5)     # First 5 values: 1, 3, 5, 7, 9

# Min/max of a list
query = range_min("v:List", "v:Min")
query = range_max("v:List", "v:Max")
```

## Range queries on triples

```elixir
import TerminusDB.WOQL

# Find triples with object value in [10, 100)
query = triple_slice("v:Subject", "v:Predicate", "v:Object", 10, 100)

# Descending order
query = triple_slice_rev("v:Subject", "v:Predicate", "v:Object", 10, 100)

# Find next/previous value
query = triple_next("v:Subject", "v:Predicate", "v:Object", "v:Next")
query = triple_previous("v:Subject", "v:Predicate", "v:Object", "v:Prev")
```
