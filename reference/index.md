# Package index

## Fetching OECD data

Retrieve the two sources the Muskoka method applies coefficients to.
Both take an explicit price basis, because OECD rebases its own constant
series with each release.

- [`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
  : Fetch bilateral CRS disbursements for a donor
- [`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md)
  : Fetch a provider's core contributions to multilateral agencies

## Classifying recipients

OECD classifies recipients geographically, by DAC List income tier and
by World Bank income group, all at once. Each is a different cut of the
same money, so each sums to the same total, and each can be cut at a
chosen level.

- [`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md)
  : Total a donor's disbursements by recipient classification

## Coefficient tables

The weights the method depends on, transcribed from the Donors
Delivering for SRHR reports and cited there.

- [`sector_weights`](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
  : Sector weights for the revised Muskoka method
- [`agency_weights`](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)
  : Multilateral agency weights for the revised Muskoka method

## Lookups

Reference data the fetchers depend on: which recipient codes are
aggregates, how the hierarchy nests, and how report agency names map to
OECD channel codes.

- [`crs_recipients`](https://meltemod.github.io/rmnchfunding/reference/crs_recipients.md)
  : CRS recipient codes: which are aggregates, which are countries
- [`crs_recipient_tree`](https://meltemod.github.io/rmnchfunding/reference/crs_recipient_tree.md)
  : CRS recipient hierarchy edges
- [`agency_channels`](https://meltemod.github.io/rmnchfunding/reference/agency_channels.md)
  : Multilateral agency to OECD channel code crosswalk

## Package

- [`rmnchfunding`](https://meltemod.github.io/rmnchfunding/reference/rmnchfunding-package.md)
  [`rmnchfunding-package`](https://meltemod.github.io/rmnchfunding/reference/rmnchfunding-package.md)
  : rmnchfunding: Tools For Reproducible RMNCH Funding Analysis
