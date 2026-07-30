# OECD recipients mapped to World Bank codes and geographic groups

Joins OECD CRS recipient codes to World Bank ISO3 codes, and records
each recipient's continent, region and subregion. Both are needed to
build
[rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md):
the first to reach the source data, the second to substitute a regional
weight where a recipient has none.

## Usage

``` r
recipient_crosswalk
```

## Format

A data frame with 182 rows and 8 columns:

- recipient_code:

  OECD recipient code.

- recipient_name:

  OECD recipient name.

- iso3:

  World Bank ISO3 code, or `NA` where there is no record.

- wb_name:

  World Bank economy name, for checking the match by eye.

- continent, region, subregion:

  Geographic ancestors, from the same frontier logic
  [`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md)
  uses.

- no_data_reason:

  Why a recipient has no World Bank match, or `NA`.

## Source

OECD codes and hierarchy from
[crs_recipients](https://meltemod.github.io/rmnchfunding/reference/crs_recipients.md)
and
[crs_recipient_tree](https://meltemod.github.io/rmnchfunding/reference/crs_recipient_tree.md);
World Bank economy list from <https://api.worldbank.org/v2/country>,
retrieved 2026-07-30.

## Details

OECD's alphabetic recipient codes are ISO3 for almost every country, so
the join is on the code itself, with exceptions enumerated rather than
pattern-matched. Kosovo is the one genuine code difference — OECD `XKV`
against World Bank `XKX`.

Twelve recipients have no World Bank record at all and carry a
`no_data_reason`: eight small territories outside the World Bank's
economy list, three OECD programmes that are not countries (East African
Community, Indus Basin, Mekong Delta), and Chinese Taipei. These are the
recipients whose weights come from a regional substitute.

The build script fails if any recipient is neither matched nor given a
reason, so a gap in the weights is always a recorded decision rather
than an accident.

## What is excluded

Only leaves under `DPGC` are here. That drops aggregates, the `_X`
unallocated buckets — which are not places and have no population to
compute a weight from — and the multilateral organisations that also
live in OECD's `CL_AREA_ORG` codelist, which covers areas *and*
organisations.

## See also

[rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md),
[crs_recipients](https://meltemod.github.io/rmnchfunding/reference/crs_recipients.md).
