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
  rather than `0`. Their RMNCH share is set per recipient country and year,
  which a table
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
* Added `oecd_crs()`, which fetches a donor's bilateral CRS disbursements for
  the Muskoka purpose codes, by recipient and year.
* Added `oecd_multi()`, which fetches a provider's core contributions to the
  eleven weighted multilateral agencies.
* Added `crs_recipients`, the recipient hierarchy, and `agency_channels`, the
  agency-to-OECD-channel crosswalk. Both are what stop the fetchers from
  double counting or matching on names.
* Both fetchers take `prices = "constant"` with an explicit `base` year, or
  `prices = "current"`. The base is never implicit: OECD rebases its own
  constant series with each release (2024 now, 2023 a few months ago), so
  values are always fetched in current prices and deflated here with OECD's
  per-donor ODA deflators. Use base 2022 to reproduce the 2025 report edition
  and 2023 for the 2026 edition.
* Added `crs_classify()`, which totals a donor's disbursements by recipient
  classification. OECD classifies recipients geographically, by DAC List income
  tier and by World Bank income group simultaneously; each is a different cut of
  the same money, so each sums to the same grand total. Each can also be cut at
  a chosen `level` — geography runs total, continent, region, subregion,
  country; the income classifications run total, tier or group, country.
  Overlapping flags such as `HIPC`, `LLDC`, `SIDS` and `FSCAC` are deliberately
  not classifications: they partition nothing.
* Added `crs_recipient_tree`, the hierarchy edges that make a level cut
  possible. It carries one local repair — OECD's codelist omits `DPGC_X` from
  `INC_X`'s children although the reported `INC_X` value includes it, which
  costs 32% of a donor's total when an income classification is cut to country
  level.
* `oecd_crs()` and `oecd_multi()` now return 0 rows with a warning, rather than
  erroring, when a donor funded nothing in the requested sectors and years.
  Greece has no records under codes 13020, 13030 or 13040 for 2021-2024, and
  erroring on that would abort any loop over donors on its first sparse one.
  The empty result carries the same columns and attributes as a populated one.
* Fixed `oecd_crs()` and `oecd_multi()` treating an empty OECD result as a
  network failure. OECD answers an empty query with HTTP 404 and the body
  "NoRecordsFound", which httr2 raised on before the body could be read.
* `crs_classify()` gains `complete`, which fills members the donor did not fund
  with an explicit `0` so that the rows are the same for every donor and year.
  For the United States over 2021-2024, 151 recipients appear in the data out of
  207 in the hierarchy. OECD reports no row at all for an unfunded recipient, so
  a zero and an absent row mean the same thing: completing changes the shape of
  a result but never a total.
* `crs_recipients` gains `recipient_name`, from codelist `CL_AREA_ORG`, so that
  a zero-filled row says which country reported nothing.
* Added `rmnch_recipient_weights`, the RMNCH weights that Muskoka2 sets per
  recipient country and year rather than globally, with the reproductive-health,
  maternal-newborn and child-health components kept as separate columns. Code
  51010 (general budget support) is built from World Bank government health
  expenditure and population structure; validated against the published
  Muskoka2 reference for 2002-2017, where 94% of 2,195 recipient-years fall
  within 0.02 of the reference and the median absolute difference is 0.0023.
* **Corrected model.** These four weights were previously documented as varying
  per DONOR and recoverable by solving published donor totals. They vary by
  recipient and year and are computed from source data. `solve_donor_weights()`
  is retained as an independent cross-check and its documentation now says so.
* Every weight records its provenance: `source` distinguishes own data from a
  regional substitute, and `source_year` records the year the data was observed
  where a value was carried forward. World Bank health-expenditure coverage
  stops in 2023 (203 economies, against 7 for 2024), so most 2024 weights are
  carried; carrying is capped at three years, beyond which a weight is `NA`.
* Added `recipient_crosswalk`, joining OECD recipient codes to World Bank ISO3
  and recording each recipient's geographic ancestors for the regional
  fallback. 170 of 182 recipients match directly; the 12 that do not each carry
  a reason, and the build fails on any recipient that is neither matched nor
  explained.
* All four `varies*` codes are now built. Malaria (12262), tuberculosis (12263)
  and STD control including HIV/AIDS (13040) come from an IHME Global Burden of
  Disease 2023 extract covering 2011-2023, committed under `data-raw/gbd/`
  because GHDx has no unauthenticated API. 2,912 weights: 4 codes x 182
  recipients x 4 years, none unresolved.
* Validated against the published Muskoka2 reference over the years it covers.
  General budget support and tuberculosis reproduce it closely (94.2% and 80.5%
  of observations within 0.02); malaria is moderate; **HIV agrees least well**,
  and the divergence sits entirely in its RH component. All three plausible
  readings of that formula were tested on identical rows and none reconciles
  the two, so the documented formula is retained and the difference is
  attributed to GBD revising HIV estimates between rounds. HIV weights are the
  least certain of the four; see `?rmnch_recipient_weights`.
* Where a disease is absent from a country entirely, the child share is 0 and
  the weight reduces to the fixed component. GBD reports zero malaria incidence
  for 118 of 204 locations, so this is the common case rather than an edge one.
  It is deliberately not a regional substitute: taking a malarious neighbour's
  child share would invent burden that is not there.
* Removed the `rescale01()` placeholder that shipped with the template.

`muskoka()` itself is not written yet, and the RMNCH weights for the three
disease codes await a GBD extract.

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
