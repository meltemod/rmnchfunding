# rmnchfunding 0.0.0.9000

* Added `sector_weights`: the share of each of 33 OECD CRS purpose codes
  attributed to the RMNCH, SRHR and family-planning universes.
* Added `agency_weights`: the share of 11 multilateral agencies' spending
  attributed to each universe, keyed by spending year (2021-2024) *and* by the
  report edition that published it (2025, 2026). Both keys matter — each
  edition recomputes years an earlier one already published, and 31 of the 66
  overlapping cells differ, by as much as 5.18% vs 13.42%. Weights and
  published totals must be taken from the same edition, which also fixes the
  price base (2022 constant prices in 2025, 2023 in 2026).
* Both tables are transcribed from the Donors Delivering for SRHR Report,
  2026 edition pp. 110-111 and 2025 edition pp. 104-105, and cited as such.
  The sector table is identical across editions; only the multilateral weights
  were revised.
* Four RMNCH sector weights (12262, 12263, 13040, 51010) are recorded as `NA`
  rather than `0`. Their RMNCH share is set per donor country, which a table
  with one weight per code cannot express; the donor-level weights are still
  to be derived. `muskoka(universe = "rmnch")` will refuse to compute rather
  than treat them as zero. SRHR and family planning are complete. The two
  report editions together span the four years needed to identify them.
* IDA's family-planning weight is `0` in every year and edition, matching the
  published method. The revised Muskoka 1% alternative will be reachable as
  `muskoka(universe = "fp", ida = 1)` rather than as a table entry.
* Added an internal `solve_donor_weights()`, which recovers a donor's four
  per-donor RMNCH weights from published totals by bounded least squares,
  assuming the weights are constant across years. It reports which weights are
  identified, which codes the donor never disbursed in, and which donors are
  underdetermined, plus a bound on the error induced by rounding in the
  published totals. Not yet wired to anything: it needs the CRS disbursements
  the totals were built from.
* Removed the `rescale01()` placeholder that shipped with the template.

No estimate can be computed yet: the OECD fetchers and `muskoka()` are not
written.

<!--
Conventions:

* The heading must carry a PARSEABLE VERSION NUMBER. R builds its news
  database by matching version strings in these headings, so the usual
  "# pkg (development version)" idiom yields "no news entries found" and an
  R CMD check NOTE. Use the development version from DESCRIPTION instead.
* One bullet per user-visible change, written for someone who uses the
  package rather than someone who wrote it. Internal refactors go
  unmentioned unless behaviour changed.
* Credit contributors as (@handle, #issue).
* On release, rename this heading to the release version, then open a fresh
  development heading above it.
-->
