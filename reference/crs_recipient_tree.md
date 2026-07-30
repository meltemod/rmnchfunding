# CRS recipient hierarchy edges

The parent-child edges of the OECD recipient hierarchy. This is what
allows a classification to be cut at a chosen level by
[`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md).

## Usage

``` r
crs_recipient_tree
```

## Format

A data frame with 845 rows and 2 columns:

- parent_code:

  OECD recipient code of the parent.

- child_code:

  OECD recipient code of the child.

## Source

OECD hierarchical codelist `HCL_DACRECIPIENTS` version 1.5, retrieved
2026-07-30, plus the one repair described above. Rebuild with
`data-raw/crs_recipient_tree.R`.

## Details

An edge list rather than a parent column on
[crs_recipients](https://meltemod.github.io/rmnchfunding/reference/crs_recipients.md),
because the hierarchy is not a tree: its top level holds overlapping
analytical groupings, so a code has several parents.

## One local repair

OECD's codelist does not describe its own reported aggregates exactly.
In the published data `INC_X` ("countries unallocated by income")
includes `DPGC_X` ("developing countries unspecified"); in the codelist,
`DPGC_X` is not among `INC_X`'s children.

The edge `INC_X -> DPGC_X` is therefore added here to match the data. It
is not cosmetic: without it, cutting an income classification at country
level descends `INC_X` through the codelist and drops `DPGC_X` entirely.
For the United States in 2022 that is 7,766.8 million — 32% of the
donor's total — and the country level would silently fail to match the
tier level above it. The shortfall was measured as exactly `DPGC_X`'s
value.

The edge creates no double count: `DPGC_X` is the geographic residual,
and an income scheme's only route to it is through `INC_X`.

`data-raw/crs_recipient_tree.R` reports if OECD ever adds the edge
itself, at which point the repair becomes redundant and should be
removed.

## See also

[`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md),
[crs_recipients](https://meltemod.github.io/rmnchfunding/reference/crs_recipients.md).
