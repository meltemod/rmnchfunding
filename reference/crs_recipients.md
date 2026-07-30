# CRS recipient codes: which are aggregates, which are countries

The OECD recipient codelist is hierarchical, and this records the part
of that structure
[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
needs: whether a code stands for a group of recipients or for a single
one.

## Usage

``` r
crs_recipients
```

## Format

A data frame with 290 rows and 7 columns:

- recipient_code:

  OECD recipient code. Unique.

- recipient_name:

  Official OECD name, from codelist `CL_AREA_ORG`. Bundled so that a
  recipient absent from a donor's data can still be labelled — see the
  `complete` argument of
  [`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md).

- n_children:

  Most children the code has in any grouping.

- n_appearances:

  How many groupings the code appears in.

- min_depth:

  Shallowest depth at which it appears.

- is_aggregate:

  `TRUE` if `n_children > 0`. 39 codes are aggregates and 251 are
  leaves. This is what de-duplication keys on.

- is_unallocated:

  `TRUE` for OECD's 28 `_X` buckets, which hold spending not
  attributable to a country. See Leaves are not countries.

## Source

Structure from OECD hierarchical codelist `HCL_DACRECIPIENTS` version
1.5; names from codelist `CL_AREA_ORG` version 1.6, which the hierarchy
declares as its source. Retrieved 2026-07-30. Rebuild with
`data-raw/crs_recipients.R`.

## Details

A CRS query with the recipient dimension left open returns aggregates
and individual countries as **sibling rows**. "Developing countries",
"Africa" and "Kenya" all come back together, so summing the rows counts
Kenya once as itself, again in its region, again in its continent and
again in the global total. Nothing in the response marks which rows are
aggregates, and the resulting total can be several times the true
figure. This dataset is how
[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
strips them, without a network call on every query.

## The hierarchy is not a tree

The top level holds overlapping *analytical groupings* rather than one
nesting: `DPGC` (developing countries) sits beside `LLDC` (landlocked
least developed), `SIDS` (small island states), `FSCAC` (fragile
contexts), the World Bank income groups (`OLICWB`, `LMICWB`, `UMICWB`,
`HICSWB`) and others. A country belongs to several at once, so codes
have many parents and recur at different depths — one code appears six
times.

Two consequences shape this table. It is keyed by **distinct code**,
since a walk emitting one row per visit yields 863 rows for 290 codes.
And `is_aggregate` means "has children *anywhere* in the hierarchy",
because a code that is a leaf of one grouping may parent members of
another, and must still not be summed alongside them.

## Leaves are not countries

OECD reports the part of a donor's spending it cannot attribute to any
one country in `_X` buckets: `DPGC_X` "Developing countries
unspecified", `F6_X` "Sub-Saharan Africa unspecified", and so on for
each region. These have no members, so they are leaves — correctly,
because unlike a region they do not overlap the countries beside them
and can safely be summed alongside them.

They are nonetheless not countries, and the distinction is large rather
than pedantic: for the United States in 2022 they are over 40% of the
disbursements this package fetches. `is_unallocated` marks them so a
caller can sum by country without them and sum a donor total with them.

The flag is independent of `is_aggregate`. Two `_X` codes, `INC_X` and
`INCWB_X`, group the countries of unspecified income classification and
so do have members; they are aggregates as well as unallocated.

## See also

[`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md),
whose `recipients` argument uses this.
