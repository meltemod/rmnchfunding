# rmnchfunding 0.0.0.9000

* Added `sector_weights`: the share of each of 33 OECD CRS purpose codes
  attributed to the RMNCH, SRHR and family-planning universes.
* Added `agency_weights`: the share of 11 multilateral agencies' spending
  attributed to each universe, for the 2022, 2023 and 2024 methodology
  vintages.
* Both tables are transcribed from the Donors Delivering for SRHR Report 2026,
  pages 110-111, and cited as such.
* Four RMNCH sector weights (12262, 12263, 13040, 51010) are recorded as `NA`
  rather than `0`. Their RMNCH share is set per donor country, which a table
  with one weight per code cannot express; the donor-level weights are still
  to be derived. `muskoka(universe = "rmnch")` will refuse to compute rather
  than treat them as zero. SRHR and family planning are complete.
* IDA's family-planning weight is `0` in every vintage, matching the published
  method. The revised Muskoka 1% alternative will be reachable as
  `muskoka(universe = "fp", ida = 1)` rather than as a table entry.
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
