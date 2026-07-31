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
  `NA` rather than `0`. Their RMNCH share is set per recipient country
  and year, which a table with one weight per code cannot express; the
  donor-level weights are still to be derived.
  `muskoka(universe = "rmnch")` will refuse to compute rather than treat
  them as zero. SRHR and family planning are complete. The two report
  editions together span the four years needed to identify them.

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

- Added
  [`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md),
  which totals a donor’s disbursements by recipient classification. OECD
  classifies recipients geographically, by DAC List income tier and by
  World Bank income group simultaneously; each is a different cut of the
  same money, so each sums to the same grand total. Each can also be cut
  at a chosen `level` — geography runs total, continent, region,
  subregion, country; the income classifications run total, tier or
  group, country. Overlapping flags such as `HIPC`, `LLDC`, `SIDS` and
  `FSCAC` are deliberately not classifications: they partition nothing.

- Added `crs_recipient_tree`, the hierarchy edges that make a level cut
  possible. It carries one local repair — OECD’s codelist omits `DPGC_X`
  from `INC_X`’s children although the reported `INC_X` value includes
  it, which costs 32% of a donor’s total when an income classification
  is cut to country level.

- [`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
  and
  [`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md)
  now return 0 rows with a warning, rather than erroring, when a donor
  funded nothing in the requested sectors and years. Greece has no
  records under codes 13020, 13030 or 13040 for 2021-2024, and erroring
  on that would abort any loop over donors on its first sparse one. The
  empty result carries the same columns and attributes as a populated
  one.

- Fixed
  [`oecd_crs()`](https://meltemod.github.io/rmnchfunding/reference/oecd_crs.md)
  and
  [`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md)
  treating an empty OECD result as a network failure. OECD answers an
  empty query with HTTP 404 and the body “NoRecordsFound”, which httr2
  raised on before the body could be read.

- [`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md)
  gains `complete`, which fills members the donor did not fund with an
  explicit `0` so that the rows are the same for every donor and year.
  For the United States over 2021-2024, 151 recipients appear in the
  data out of 207 in the hierarchy. OECD reports no row at all for an
  unfunded recipient, so a zero and an absent row mean the same thing:
  completing changes the shape of a result but never a total.

- `crs_recipients` gains `recipient_name`, from codelist `CL_AREA_ORG`,
  so that a zero-filled row says which country reported nothing.

- Added `rmnch_recipient_weights`, the RMNCH weights that Muskoka2 sets
  per recipient country and year rather than globally, with the
  reproductive-health, maternal-newborn and child-health components kept
  as separate columns. Code 51010 (general budget support) is built from
  World Bank government health expenditure and population structure;
  validated against the published Muskoka2 reference for 2002-2017,
  where 94% of 2,195 recipient-years fall within 0.02 of the reference
  and the median absolute difference is 0.0023.

- **Corrected model.** These four weights were previously documented as
  varying per DONOR and recoverable by solving published donor totals.
  They vary by recipient and year and are computed from source data.
  `solve_donor_weights()` is retained as an independent cross-check and
  its documentation now says so.

- Every weight records its provenance: `source` distinguishes own data
  from a regional substitute, and `source_year` records the year the
  data was observed where a value was carried forward. World Bank
  health-expenditure coverage stops in 2023 (203 economies, against 7
  for 2024), so most 2024 weights are carried; carrying is capped at
  three years, beyond which a weight is `NA`.

- Added `recipient_crosswalk`, joining OECD recipient codes to World
  Bank ISO3 and recording each recipient’s geographic ancestors for the
  regional fallback. 170 of 182 recipients match directly; the 12 that
  do not each carry a reason, and the build fails on any recipient that
  is neither matched nor explained.

- All four `varies*` codes are now built. Malaria (12262),
  tuberculosis (12263) and STD control including HIV/AIDS (13040) come
  from an IHME Global Burden of Disease 2023 extract covering 2011-2023,
  committed under `data-raw/gbd/` because GHDx has no unauthenticated
  API. 2,912 weights: 4 codes x 182 recipients x 4 years, none
  unresolved.

- Validated against the published Muskoka2 reference over 2005-2017, the
  overlap between the GBD extract and the reference, recipient by
  recipient. `ratio` is the median of ours over the reference:

  | code                          |    n | ratio | \<0.01 | \<0.05 | \<0.10 |
  |-------------------------------|-----:|------:|-------:|-------:|-------:|
  | 51010 general budget support  | 1789 | 1.002 |  83.1% |  99.7% |  99.9% |
  | 12263 tuberculosis            | 1872 | 0.985 |  68.2% |  96.0% | 100.0% |
  | 12262 malaria, all            | 1872 | 0.964 |  35.4% |  68.2% |  83.2% |
  | 12262 malaria, burden present | 1159 | 1.000 |  56.3% |  90.7% |  95.5% |
  | 13040 STD incl. HIV/AIDS      | 1872 | 1.031 |  15.3% |  69.2% |  96.4% |

  Exact agreement was never expected: the reference used GBD 2017 and
  2018-vintage World Bank data. Malaria matches in level **exactly**
  (ratio 1.000) once the 713 country-years where GBD 2023 records no
  malaria at all are separated out — those are elimination and
  re-estimated history, not a methodological difference. STD/HIV is the
  loosest and least certain of the four, though much improved by the
  cause correction, and its error is now roughly symmetric rather than
  systematic.

- Where a disease is absent from a country entirely, the child share is
  0 and the weight reduces to the fixed component. GBD reports zero
  malaria incidence for 118 of 204 locations, so this is the common case
  rather than an edge one. It is deliberately not a regional substitute:
  taking a malarious neighbour’s child share would invent burden that is
  not there.

- `recipient_crosswalk` gains `gbd_location_name` and readable
  `continent_name`, `region_name` and `subregion_name`. All three of the
  method’s naming systems now live in one table: Cote d’Ivoire is
  spelled differently by OECD, the World Bank and GBD, and no two are
  reachable from each other by string match, so identity mapping belongs
  in one documented place rather than at each point of use.

- Exported `inst/extdata/recipient_crosswalk.csv`, a flat copy of the
  crosswalk with the imputation source for each purpose code, for
  readers checking the method without running R. 26 of 182 recipients
  have a borrowed weight for at least one code.

- Documented that the imputation geography is the **OECD DAC** recipient
  hierarchy, not UN M49 and not World Bank regions. The three disagree
  in ways that change which recipients are grouped: M49 puts Turkiye in
  Western Asia and subdivides Europe, the DAC does neither; the World
  Bank groups Egypt with the Middle East where the DAC places it in
  Africa.

- `region_name` and `subregion_name` are now `NA` where that level does
  not exist, rather than repeating the recipient. The DAC hierarchy is
  ragged — Africa nests three deep, Europe not at all — so fifteen
  European recipients have no region level, and labelling them with
  their own name read as a bug. The code columns are unchanged, since
  they are what the cascade groups on.

- Added
  [`recipient_map()`](https://meltemod.github.io/rmnchfunding/reference/recipient_map.md),
  which returns the crosswalk the package uses: each OECD recipient with
  its World Bank and GBD identifiers, its place in the DAC geographic
  hierarchy, and whether each of the four varying weights is its own or
  borrowed. `recipient_map("12262", imputed_only = TRUE)` answers “which
  recipients borrow a malaria weight, and from which level”. This joins
  two things that were otherwise separate: the crosswalk had the
  identifiers but no provenance, the weights had the provenance but one
  row per recipient-year.

- Regional substitution is now **burden-weighted** rather than an
  unweighted mean: weighted by all-age case counts for the disease codes
  and by population for general budget support. A ratio of summed cases
  across a group is identically a mean of member ratios weighted by
  their denominators, so a substituted weight now equals what an
  aggregate of the source data over that group would report — which is
  what the published method’s regional rows appear to contain. It
  matters: for tuberculosis in the Caribbean the weighted and unweighted
  figures differ by 38%.

- Where a whole group has zero burden the weights are all zero and a
  weighted mean is undefined, but the answer is not — no cases anywhere
  means a zero child share. Europe is entirely malaria-free, so
  Gibraltar and Kosovo take the MNH constant alone.

- Documented why malaria’s 0.15 MNH constant is applied unconditionally,
  with the alternative tested rather than asserted. Zeroing it where no
  burden is recorded is **worse** against the published reference —
  agreement within 0.10 falls from 83.2% to 59.1% — because not one of
  the 713 zero-burden reference values falls below 0.15. The variant is
  documented in
  [`vignette("rmnchfunding")`](https://meltemod.github.io/rmnchfunding/articles/rmnchfunding.md)
  with the two lines needed to construct it, rather than exposed as an
  argument that would quietly break comparability with the published
  series.

- Stated explicitly that the group a substituted weight is drawn from is
  always an **OECD DAC** grouping, never a GBD or World Bank region. The
  published method assigns such recipients to a GBD region and uses its
  aggregate; this package keeps one taxonomy throughout and averages
  over the same universe the disbursements come from. Substituted
  weights therefore will not reproduce the published figures exactly,
  for 26 of 182 recipients, all small and all marked by `source`.

- The burden weighting itself does follow the published method, and that
  is now evidenced rather than reasoned: Muskoka2 substitutes a GBD
  regional aggregate, which is a ratio of summed cases and so
  burden-weighted by construction.

- Recorded that the Muskoka2 workbook was accessed 2026-07-30, and that
  it is not redistributed with the package: at 187 MB it exceeds
  GitHub’s per-file limit and it is CC BY-NC 3.0 rather than MIT.
  [`?rmnch_recipient_weights`](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md),
  the vignette and `data-raw/reference/README.md` all point at the DOI
  for anyone wanting to inspect the method at source, and note that the
  binary `.xlsb` needs Python’s `pyxlsb` rather than `readxl`.

- **`sector_weights` now departs from the 2026 report on nine values**,
  which that edition misprints. Eight are SRHR weights (15170, 15180,
  16064, 51010, 72010, 72040, 72050, 73010) whose printed values repeat
  the SRHR column’s own first eight in order — a spreadsheet fill — and
  one is 12191’s RMNCH weight, printed as 100% where the earlier
  editions give 40%. The package uses the 2023/2024 values, which agree
  with each other and which reproduce the 2026 edition’s own published
  donor totals.

  This was found by solving the weights from the report’s published
  totals (99 provider-year equations, 33 unknowns) after validating the
  same solver against family planning, whose weights are known correct.
  The printed SRHR weights are not merely a worse fit but arithmetically
  impossible: 27 of 99 provider-years would need a negative multilateral
  half, EU Institutions 2023 needing −3,411 million. The 2023 and 2024
  editions, consulted afterwards, print exactly the recovered values.

  SRHR estimates change materially — median error against published
  totals falls from 11.43% to 0.01%, and the All-DAC 2022 total now
  reproduces exactly.
  [`vignette("rmnchfunding")`](https://meltemod.github.io/rmnchfunding/articles/rmnchfunding.md)
  has the derivation.

- Added
  [`muskoka2()`](https://meltemod.github.io/rmnchfunding/reference/muskoka2.md),
  the entry point: it fetches both OECD sources, applies the sector and
  agency weights, and returns provider-year totals for RMNCH, SRHR or
  family planning. `detail = TRUE` returns the weighted rows instead.

- Against the published Donors Delivering 2026 totals for the United
  States, 2022-2024, in 2023 constant prices: family planning reproduces
  **exactly**, RMNCH within 1%, and SRHR to 0.01% median across all 33
  providers once the misprinted weights above are corrected.

- `recipient_crosswalk` and `rmnch_recipient_weights` now cover the
  unallocated `_X` recipients (207 recipients, 3,312 weights). They are
  not places and have no source data, but CRS reports real disbursements
  against them — 48% of the value in the four varying codes for the
  United States — so
  [`muskoka2()`](https://meltemod.github.io/rmnchfunding/reference/muskoka2.md)
  could not weight half the money without them. They take their
  geographic parent’s figure, and DPGC_X takes a global one, since its
  parent is the root.

- Removed the `rescale01()` placeholder that shipped with the template.

`muskoka()` itself is not written yet, and the RMNCH weights for the
three disease codes await a GBD extract.
