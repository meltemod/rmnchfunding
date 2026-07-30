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

A data frame with 99 rows (33 purpose codes x 3 universes) and 4
columns:

- purpose_code:

  CRS five-digit purpose code, as character. Held as text so codes are
  never treated as numbers and never lose a leading digit when joined
  against a CRS extract.

- purpose_name:

  Purpose code description.

- universe:

  Factor with levels `"rmnch"`, `"srhr"`, `"fp"`.

- weight:

  Share of the disbursement attributed to the universe, as a proportion
  in `[0, 1]` — not a percentage. `NA` where no weight has been agreed;
  see Unresolved weights.

## Source

Donors Delivering for SRHR Report 2026, "Selected percentages per OECD
DAC codes (as under the Muskoka 2, the Donors Delivering for SRHR, and
the FP methodology)", pages 110-111.
<https://donorsdelivering.report/wp-content/uploads/2026/06/DD_Report2026_Update.pdf>

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

Only 51010 is built so far. The three disease codes need an IHME Global
Burden of Disease extract that cannot be fetched automatically, so
`muskoka(universe = "rmnch")` still refuses to compute rather than
return a total missing three large CRS sectors. See
`data-raw/gbd/README.md`.

The SRHR and family-planning universes are complete and unaffected.

## See also

[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)
for the multilateral half of the estimate.
