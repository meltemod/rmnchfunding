# Multilateral agency weights for the revised Muskoka method

The share of a multilateral agency's spending attributed to a funding
universe, per spending year and per report edition. Applied to a
provider's imputed share of an agency's outflows, these coefficients
give the multilateral half of a Muskoka estimate;
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
gives the bilateral half.

## Usage

``` r
agency_weights
```

## Format

A data frame with 396 rows (11 agencies x 3 spending years x 3 universes
x 4 report editions) and 5 columns:

- agency:

  Multilateral agency or initiative, by display name.

- data_year:

  Integer year of the **spending**: 2019 to 2024. Each edition covers
  three consecutive years, and successive editions step forward by one,
  so the four together span the range with no gap.

- universe:

  Factor with levels `"rmnch"`, `"srhr"`, `"fp"`.

- weight:

  Share of agency spending attributed to the universe, as a proportion
  in `[0, 1]` — not a percentage.

- report_edition:

  Integer year of the **report** that published the weight: 2023, 2024,
  2025 or 2026. See Two keys, not one.

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

Donors Delivering for SRHR Report 2025, same table, pages 104-105.
<https://donorsdelivering.report/wp-content/uploads/2025/06/DDSRHR2025.pdf>

The sector table is identical in all four editions apart from nine
misprints, so
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
carries no edition key; only the multilateral weights were revised.

## Two keys, not one

Unlike
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md),
these coefficients are not fixed constants, and they need two keys
rather than one.

`data_year` is the year of the spending. The report calculates each
weight as the proportion of that multilateral's own disbursements in
that year which benefit the universe, so an agency's weight genuinely
differs between 2022 and 2023 because its disbursement mix differed.

`report_edition` is the year of the report. Each edition recomputes the
weights for every year it covers — including years an earlier edition
already published — as the underlying multilateral data is revised.
These revisions are substantial, not cosmetic: of the 66
agency-year-universe cells published in both the 2025 and 2026 editions,
31 changed. The Asian Development Bank's 2023 RMNCH weight is 5.18% in
the 2025 edition and 13.42% in the 2026 edition.

Both keys are load-bearing. **Take the weights and the published totals
from the same edition**: pairing one edition's totals with another's
weights produces a figure that reproduces neither report. The editions
also use different price bases — 2022 constant prices in 2025, 2023
constant prices in 2026 — which is a second reason not to mix them
without deflating.

## A suspected transposition in the 2023 edition

The 2023 edition prints World Food Programme 2020 as RMNCH 1.03%, SRHR
3.75%. The 2024 edition prints the same spending year as RMNCH 3.75%,
SRHR 1.03% — the two swapped. WFP's RMNCH weight is 3.70–3.96% in every
other published year and its SRHR weight 0.94–1.03%, so the 2024
ordering is the one that fits and the 2023 edition looks transposed.

It is recorded here **as printed and not corrected**. Unlike the nine
sector misprints in
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md),
this one has not been tested against the 2023 edition's own published
donor totals, and an untested correction would be a guess. Anyone
reproducing 2023-edition figures should know about it.

More generally, the agency weights have not had the treatment the sector
weights received: no independent reconstruction from published totals
has been attempted for them. That a misprint was found in one half of
the source table is reason to treat the other half as unverified rather
than as confirmed.

The four editions between them cover six spending years, 2019 to 2024,
which is the window `muskoka()` targets and the range over which
[rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md)
is built.

## IDA and family planning

IDA's family-planning weight is `0` everywhere. The 2026 edition marks
it `0.00%*` where every other zero is written plainly, and its footnote
explains why (the 2025 edition carries the plain zero, so the caveat is
new):

“Currently the Donors Delivering methodology does not count IDA
contributions to FP. However, as the revised Muskoka applies 1% to IDA,
and due to the continued relevance of this multilateral contribution to
FP, this will be reassessed for alignment in time for the next report.”

The zero is therefore a deliberate methodological choice, not missing
information, and is stored as a plain `0`. The 1% alternative is not a
row in this table — it belongs to the revised Muskoka method rather than
to any published edition — so `muskoka()` offers it as the `ida`
argument instead, applied at call time when `universe = "fp"`. The
default is `0`, matching this table and the published report.

Expect this to change: the footnote says it is under review for the next
edition.

## See also

[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
for the bilateral half of the estimate.
