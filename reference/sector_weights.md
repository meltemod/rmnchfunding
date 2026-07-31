# Sector weights for the revised Muskoka method

The share of a disbursement in each OECD CRS purpose code that is
attributed to a funding universe. These coefficients, applied to CRS
bilateral flows, are one half of a Muskoka estimate;
[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)
is the other.

## Usage

``` r
sector_weights
```

## Format

A data frame with 396 rows (33 purpose codes x 3 universes x 4 report
editions) and 7 columns:

- purpose_code:

  CRS five-digit purpose code, as character. Held as text so codes are
  never treated as numbers and never lose a leading digit when joined
  against a CRS extract.

- purpose_name:

  Purpose code description.

- universe:

  Factor with levels `"rmnch"`, `"srhr"`, `"fp"`.

- report_edition:

  Which Donors Delivering edition the row describes: 2023, 2024, 2025 or
  2026.

- weight:

  Share of the disbursement attributed to the universe, as a proportion
  in `[0, 1]` — not a percentage. This is the figure to compute with,
  and is the same in every edition. `NA` for the four RMNCH cells the
  source gives as `varies*`.

- weight_printed:

  What that edition's own table prints. Identical to `weight` except for
  the nine misprinted values.

- is_misprint:

  `TRUE` where `weight` and `weight_printed` differ.

Editions before 2023 are excluded. They publish SRHR as three components
(RH + MNH + SRR) on a different basis — 15170 is 17.0% in the 2022
edition against 7.6% in 2023 — and split their purpose codes
differently. That is a methodology revision rather than an erratum, and
mixing the two bases would give weights comparable to neither.

## Source

Donors Delivering for SRHR Report 2026, "Selected percentages per OECD
DAC codes (as under the Muskoka 2, the Donors Delivering for SRHR, and
the FP methodology)", pages 110-111.
<https://donorsdelivering.report/wp-content/uploads/2026/06/DD_Report2026_Update.pdf>

Nine values instead follow the 2023 and 2024 editions, which agree with
each other and which the 2026 edition's own donor totals bear out; see
Nine values are corrected against the 2026 edition.
<https://donorsdelivering.report/wp-content/uploads/2024/05/DD_Report2024_FINALspreads.pdf>
<https://donorsdelivering.report/wp-content/uploads/2023/06/DD_Report2023_v6_spreads.pdf>

RMNCH follows the Muskoka 2 methodology developed by the London School
of Hygiene and Tropical Medicine; family planning follows the revised
Muskoka methodology agreed at the 2012 London Summit; SRHR follows the
Donors Delivering methodology. The three overlap by construction, so
their totals must not be added together.

## Weights that vary by recipient and year

Four of the 99 weights are `NA`, all in the RMNCH universe. The source
table gives these as `varies*` rather than a single figure, because the
RMNCH share of these sectors is set **per recipient country and year**
rather than globally:

- 12262:

  Malaria control

- 12263:

  Tuberculosis control

- 13040:

  STD control including HIV/AIDS

- 51010:

  General budget support-related aid

They are `NA` here because a single column cannot hold a value that
varies by recipient and year, not because they are unknown in principle.
Muskoka2 computes them from open disease-burden and
government-health-expenditure data; the results live in
[rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md)
and are joined to a disbursement on its recipient and year.

All four are built. See
[rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md)
for how they are computed and `data-raw/gbd/README.md` for the Global
Burden of Disease extract they depend on.

## Nine values the 2025 and 2026 editions misprint

The four editions agree on every cell but nine. For those, `weight`
follows the 2023 and 2024 editions, which are identical to each other
and whose values — not the later tables' — reproduce the 2025 and 2026
editions' own published donor totals. They are errata rather than
revisions, which is why `weight` is the same in all four editions and
only `weight_printed` differs.

|  |  |  |  |
|----|----|----|----|
| code | name | `weight` | `weight_printed` (2025, 2026) |
| 15170 | Women's equality organisations | 7.6% | 4.4% |
| 15180 | Ending violence against women and girls | 41.5% | 9.4% |
| 16064 | Social mitigation of HIV and AIDS | 50.0% | 15.4% |
| 51010 | General budget support-related aid | 0.0% | 16.1% |
| 72010 | Material relief assistance and services | 2.3% | 0.0% |
| 72040 | Emergency food aid | 0.1% | 17.5% |
| 72050 | Relief coordination, protection and support | 0.7% | 10.0% |
| 73010 | Reconstruction relief and rehabilitation | 0.6% | 13.6% |
| 12191 | Medical services (RMNCH, not SRHR) | 40% | 100% |

The first eight are consecutive rows of the SRHR column, and the 2026
table gives them that column's own first eight values in order — 4.4,
9.4, 15.4, 16.1, 0.0, 17.5, 10.0, 13.6 — which is what a spreadsheet
fill produces.

Using the printed 2026 weights, SRHR estimates miss the published donor
totals by 11.4% at the median and only 8 of 99 provider-years land
within 1%. Using the values above, the median error is 0.01% and 93 of
99 land within 1%. For 12191, the RMNCH median error is 0.20% at 40%
against 2.79% at 100%.

The printed weights are not merely a worse fit but arithmetically
impossible: under them, 27 of 99 provider-years would need a
**negative** multilateral half to reach their published total — EU
Institutions 2023 would need −3,411 million — and a weighted sum of
non-negative contributions cannot be negative. Under the corrected
values, 1 of 99 does.

[`vignette("rmnchfunding")`](https://meltemod.github.io/rmnchfunding/articles/rmnchfunding.md)
gives the full derivation, including how the eight were identified from
the published totals alone, before the 2023 and 2024 editions were
consulted.
[`muskoka_weights()`](https://meltemod.github.io/rmnchfunding/reference/muskoka_weights.md)
shows both columns side by side for any edition.

## See also

[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)
for the multilateral half of the estimate.
