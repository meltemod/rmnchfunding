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

A data frame with 182 rows and 12 columns:

- recipient_code:

  OECD recipient code.

- recipient_name:

  OECD recipient name.

- iso3:

  World Bank ISO3 code, or `NA` where there is no record.

- wb_name:

  World Bank economy name, for checking the match by eye.

- gbd_location_name:

  IHME GBD location name. GBD keys by name rather than code, so the
  spelling is resolved here rather than at use time.

- continent, region, subregion:

  Geographic ancestor codes, from the same frontier logic
  [`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md)
  uses.

- continent_name, region_name, subregion_name:

  The same, as names — `F6` and `S4_S7` are not legible on their own.

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

## Three naming systems

Each source names countries differently, and none of the three is
reachable from another by plain string matching. Cote d'Ivoire is the
sharpest case, where the three spellings differ in both the accent and
the apostrophe:

- OECD:

  "Cote" with a circumflex, and a curly (typographic) apostrophe

- World Bank:

  "Cote" with no circumflex, and an ASCII apostrophe

- GBD:

  "Cote" with a circumflex, and an ASCII apostrophe

This is why all three spellings are columns of one table rather than
being matched where they are used: a rename in any source then fails in
the place that documents the mapping, not somewhere downstream.

## The geography is OECD DAC, not M49

`continent`, `region` and `subregion` come from OECD's
`HCL_DACRECIPIENTS` hierarchy, which is the DAC's own recipient
taxonomy. It is **not** the UN M49 standard and not the World Bank's
regions, and it differs from both in ways that change which recipients
are grouped together:

- M49 places Turkiye in Western Asia; DAC places it in Europe.

- M49 subdivides Europe into Northern, Southern, Eastern and Western;
  DAC does not subdivide Europe at all.

- The World Bank groups Egypt with the Middle East; DAC places it in
  Africa. Kazakhstan and Uzbekistan are Europe & Central Asia to the
  World Bank, Asia to the DAC.

DAC is used because the weights attach to OECD recipient codes and are
joined to CRS disbursements by OECD recipient. Grouping in any other
taxonomy would impute across a boundary the disbursement data does not
recognise.

Note also that the World Bank and GBD data are read **only at country
level**. Their own regional aggregates are never used: a GBD regional
figure is a ratio of summed cases, burden-weighted by construction,
whereas an imputed value here is an unweighted mean of country ratios.
The two are different quantities and are not mixed.

## The hierarchy is ragged

Not every continent is subdivided to the same depth. Africa runs three
levels — Africa, Sub-Saharan Africa, Eastern Africa — while Europe holds
its fifteen recipients directly with no regional layer.

The `region` and `subregion` **code** columns therefore carry the
recipient itself where a level does not exist, which is what the
imputation cascade groups on. The corresponding **name** columns are
`NA` in that case, so an absent level reads as absent rather than as
"Turkiye's region is Turkiye". Fifteen recipients have no region level,
all of them European.

## Exported as a CSV

A flat copy, with the imputation source for each purpose code added,
ships at `inst/extdata/recipient_crosswalk.csv` for readers checking the
method without running R:

    read.csv(system.file("extdata", "recipient_crosswalk.csv",
                         package = "rmnchfunding"))

## See also

[rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md),
[crs_recipients](https://meltemod.github.io/rmnchfunding/reference/crs_recipients.md).
