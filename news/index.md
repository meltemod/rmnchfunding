# Changelog

## rmnchfunding 0.0.0.9000

- Added `sector_weights`: the share of each of 33 OECD CRS purpose codes
  attributed to the RMNCH, SRHR and family-planning universes.
- Added `agency_weights`: the share of 11 multilateral agencies’
  spending attributed to each universe, keyed by spending year
  (2021-2024) *and* by the report edition that published it (2025,
  2026). Both keys matter — each edition recomputes years an earlier one
  already published, and 31 of the 66 overlapping cells differ, by as
  much as 5.18% vs 13.42%. Weights and published totals must be taken
  from the same edition, which also fixes the price base (2022 constant
  prices in 2025, 2023 in 2026).
- Both tables are transcribed from the Donors Delivering for SRHR
  Report, 2026 edition pp. 110-111 and 2025 edition pp. 104-105, and
  cited as such. The sector table is identical across editions; only the
  multilateral weights were revised.
- Four RMNCH sector weights (12262, 12263, 13040, 51010) are recorded as
  `NA` rather than `0`. Their RMNCH share is set per donor country,
  which a table with one weight per code cannot express; the donor-level
  weights are still to be derived. `muskoka(universe = "rmnch")` will
  refuse to compute rather than treat them as zero. SRHR and family
  planning are complete. The two report editions together span the four
  years needed to identify them.
- IDA’s family-planning weight is `0` in every year and edition,
  matching the published method. The revised Muskoka 1% alternative will
  be reachable as `muskoka(universe = "fp", ida = 1)` rather than as a
  table entry.
- Added an internal `solve_donor_weights()`, which recovers a donor’s
  four per-donor RMNCH weights from published totals by bounded least
  squares, assuming the weights are constant across years. It reports
  which weights are identified, which codes the donor never disbursed
  in, and which donors are underdetermined, plus a bound on the error
  induced by rounding in the published totals. Not yet wired to
  anything: it needs the CRS disbursements the totals were built from.
- Added
  [`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md),
  which fetches a donor’s bilateral CRS disbursements for the Muskoka
  purpose codes, by recipient and year.
- Added
  [`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md),
  which fetches a provider’s core contributions to the eleven weighted
  multilateral agencies.
- Added `crs_recipients`, the recipient hierarchy, and
  `agency_channels`, the agency-to-OECD-channel crosswalk. Both are what
  stop the fetchers from double counting or matching on names.
- Both fetchers take `prices = "constant"` with an explicit `base` year,
  or `prices = "current"`. The base is never implicit: OECD rebases its
  own constant series with each release (2024 now, 2023 a few months
  ago), so values are always fetched in current prices and deflated here
  with OECD’s per-donor ODA deflators. Use base 2022 to reproduce the
  2025 report edition and 2023 for the 2026 edition.
- Removed the `rescale01()` placeholder that shipped with the template.

`muskoka()` itself is not written yet, and the per-donor RMNCH weights
are not yet derived.
