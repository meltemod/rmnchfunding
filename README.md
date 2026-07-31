# rmnchfunding

<!-- badges: start -->
[![R-CMD-check](https://github.com/meltemod/rmnchfunding/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/meltemod/rmnchfunding/actions/workflows/R-CMD-check.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Calculates bilateral and multilateral funding for reproductive, maternal,
newborn and child health (RMNCH), sexual and reproductive health and rights
(SRHR) and family planning from OECD Creditor Reporting System (CRS) flows and
OECD providers' total use of the multilateral system, using the revised Muskoka
method.

> **Status: under construction.** The coefficient tables and both OECD fetchers
> are in place. `muskoka()` itself is not written yet, and the four per-donor
> RMNCH weights are not yet derived, so the package does not produce a Muskoka
> estimate — but `oecd_crs()` and `oecd_multi()` are usable on their own.

---

## 1. Installation

```r
# install.packages("pak")
pak::pak("meltemod/rmnchfunding")
```

Requires R >= 4.1. Developed against R 4.6.x.

## 2. Usage

Fetch a donor's bilateral disbursements and multilateral core contributions:

```r
library(rmnchfunding)

# Bilateral, by recipient country, in the 2026 edition's price base
crs <- oecd_crs("USA", years = 2022:2024, prices = "constant", base = 2023)

# Core contributions to the eleven weighted agencies
mul <- oecd_multi("USA", years = 2022:2024, prices = "constant", base = 2023)
```

Recipients can be classified three ways, each summing to the same total, and
each cuttable at a chosen level:

```r
d <- oecd_crs("USA", years = 2022, prices = "constant", base = 2023,
              recipients = "all")             # "all" keeps the aggregate rows

crs_classify(d, "geographic")                      # continents
crs_classify(d, "geographic", level = "subregion")
crs_classify(d, "dac_income", level = "country")
crs_classify(d, "wb_income")
```

| Classification | Levels |
|---|---|
| `geographic` | `total`, `continent`, `region`, `subregion`, `country` |
| `dac_income` | `total`, `tier`, `country` |
| `wb_income` | `total`, `group`, `country` |

`HIPC`, `LLDC`, `SIDS`, `FSCAC` and `ACP` are deliberately *not* classifications
— they are overlapping flags a country carries in addition to its place in each
one above, so they partition nothing. See `vignette("rmnchfunding")` and
`?crs_classify`.

The coefficient tables and the two lookups the fetchers depend on:

```r
sector_weights                # CRS purpose code -> share, per universe
agency_weights                # multilateral agency -> share, per year and edition
crs_recipients                # which recipient codes are aggregates
crs_recipient_tree            # hierarchy edges, for cutting at a level
agency_channels               # agency -> OECD channel code
rmnch_recipient_weights       # the four weights that vary by recipient and year
recipient_crosswalk           # OECD <-> World Bank <-> GBD names, and geography
```

Four RMNCH weights are computed per recipient and year rather than being global
constants, from IHME Global Burden of Disease and World Bank data. Recipients
absent from those sources take their geographic group's mean, narrowest first,
and every weight records whether it is `"own"` or borrowed. `recipient_map()`
shows the whole relation:

```r
recipient_map()                                  # the full crosswalk
recipient_map("12262", imputed_only = TRUE)      # who borrows a malaria weight
```

The same content ships as a file for use outside R:

```r
read.csv(system.file("extdata", "recipient_crosswalk.csv",
                     package = "rmnchfunding"))
```

The geography is the **OECD DAC** hierarchy — not UN M49, not World Bank
regions. They disagree about Türkiye, Egypt and Central Asia, which changes
which recipients are grouped for imputation.

The planned entry point is a single function covering all three universes:

```r
muskoka(universe = "rmnch")           # or "srhr", or "fp"
muskoka(universe = "fp", ida = 1)     # revised Muskoka 1% for IDA
```

Both tables are transcribed from the Donors Delivering for SRHR Report,
[2026 edition](https://donorsdelivering.report/wp-content/uploads/2026/06/DD_Report2026_Update.pdf)
pages 110–111 and
[2025 edition](https://donorsdelivering.report/wp-content/uploads/2025/06/DDSRHR2025.pdf)
pages 104–105. The sector table is identical in both; the multilateral weights
were revised, so `agency_weights` carries them per edition. The three universes
overlap by construction, so their totals must never be added together.

Full reference: <https://meltemod.github.io/rmnchfunding/>

## 3. Development

```bash
Rscript dev/00-setup.R        # installs dev tooling, documents
```

Then, from an R session at the package root:

```r
devtools::load_all()          # attach the package as it stands, no install
devtools::document()          # regenerate man/ and NAMESPACE from roxygen
devtools::test()              # run tests/testthat/
devtools::check()             # the full R CMD check — run before every push
```

Everything under `man/` and the `NAMESPACE` file is **generated**. Edit the
roxygen comments above each function instead; a hand-edit to `man/` is lost
the next time anyone runs `document()`.

## 4. Repository layout

```
.
├── DESCRIPTION             Metadata and dependencies. The source of truth.
├── NAMESPACE               GENERATED by roxygen2 — do not edit
├── R/                      All package code
├── man/                    GENERATED help pages — do not edit
├── tests/testthat/         One test file per R/ file, same stem
├── vignettes/              Long-form documentation, built by knitr
├── data-raw/               Scripts that BUILD data/ — not shipped to users
├── data/                   Exported datasets (.rda), created by data-raw/
├── _pkgdown.yml            Website configuration
├── .github/workflows/      CI: R CMD check and pkgdown deploy
├── dev/                    Developer bootstrap — not shipped to users
├── .Rbuildignore           What stays in the repo and out of the tarball
└── NEWS.md                 User-facing changelog
```

## 5. Adding a dependency

1. Add it to `Imports:` in `DESCRIPTION` (or `Suggests:` if optional).
2. Refer to it as `pkg::fun()` in code, or add `@importFrom pkg fun` in
   `R/rmnchfunding-package.R` and re-run `document()`.
3. Never call `library()` inside `R/` — it alters the user's search path
   and `R CMD check` flags it.

---

## 6. Decision log

Record every non-obvious choice here, with its reasoning, so a future
maintainer can tell what was deliberate and what was incidental. Add a row,
then a subsection below it if the choice needs more than a line.

| # | Decision | Rationale in brief |
|---|----------|--------------------|
| 1 | One `muskoka(universe=)` rather than `muskoka1()`/`muskoka2()`/`revised_fp()` | The three universes share a method and differ only in coefficients. Three functions would triplicate the pipeline to vary a lookup. |
| 2 | Coefficients stored as proportions, entered as percentages | Every use is a multiplication against a disbursement; a stray factor of 100 there is invisible in a total. `data-raw/` keeps percentages so it stays diffable against the source table. |
| 3 | Unknown coefficients are `NA`, never `0` | A zero asserts the sector contributes nothing. Conflating the two understates totals silently. |
| 4 | Weight tables held in long format | `muskoka()` takes one universe and joins on code; a wide table would need runtime column selection by name. |
| 5 | Agency weights keyed by spending year *and* report edition | Weights are per spending year, and each edition recomputes earlier years. 31 of 66 overlapping cells differ between editions. |
| 6 | Purpose codes stored as character | Keeps codes out of arithmetic and preserves leading digits when joining CRS extracts that store them as text. |
| 7 | IDA's FP treatment is a `muskoka()` argument, not a table row | 0% (Donors Delivering) and 1% (revised Muskoka) are two live methods. A row would imply 1% was once published. |
| 8 | Per-donor RMNCH weights assumed constant across years | Turns one equation per published year into repeated observations of the same unknowns, which is what makes recovery possible at all. |
| 9 | Unidentified donors return `NA`, not a point from the solution family | A donor spending in all four `varies*` codes is underdetermined by one. Picking a representative solution would present an undetermined number as a result. |
| 10 | CRS and MULTI fetched from the `dcd-public` host | These two dataflows moved; the ordinary `public` host answers every query with HTTP 500, which reads as a broken request rather than a wrong address. |
| 11 | Every hierarchical dimension pinned to its total | `RECIPIENT`, `CHANNEL`, `MODALITY` and `SECTOR` each return a `_T` total *and* its components. Left open, one figure comes back six or more times and sums to a multiple of the truth. |
| 12 | Values fetched in current prices and deflated here | OECD rebases its constant series each release, and serves only the current base. Deflating locally lets any base be requested and keeps one code path. |
| 13 | `crs_classify()` separate from `oecd_crs()` rather than an argument | One fetch serves every classification and level, so folding it in would mean re-downloading to change the view. |
| 14 | Classification levels are frontiers, not depth slices | The hierarchy is ragged — Africa nests to subregions, Europe holds countries directly. A depth slice would drop every European country and stop adding up. |
| 15 | One local repair to the hierarchy: `INC_X` -> `DPGC_X` | OECD's codelist omits an edge its own reported aggregates include. Without it, income classifications lose 32% of a donor's total at country level. |

### Decision 3 — unsupplied coefficients are `NA`, never `0`

**Chosen:** Hold the four per-donor RMNCH weights as `NA`, and have `muskoka()`
refuse to compute a total that depends on one.

**Rejected:** Substituting `0`, which would let every call return a number.

**Why.** The two are indistinguishable in a result but opposite in meaning. A
zero says a sector contributes nothing to the universe; an `NA` says this table
cannot express the value. Three of the four `varies*` RMNCH cells (12262
malaria, 12263 tuberculosis, 13040 HIV/AIDS) are large CRS sectors, so treating
them as zero would understate RMNCH totals substantially — and the output would
carry no sign that anything was missing.

Note the contrast with IDA's family-planning weight, which *is* a plain `0`.
That zero is a published methodological choice with a footnote explaining it, so
it is data. The `varies*` cells are a shape mismatch, so they are absent.

**Cost.** The package cannot produce an RMNCH total until the per-donor weights
are derived. SRHR and FP are complete and unaffected.

### Decision 7 — IDA's family-planning treatment is an argument, not a row

**Chosen:** `agency_weights` records IDA's published FP weight of 0%.
`muskoka(universe = "fp", ida = )` accepts `0` (default) or `1` to apply the
revised Muskoka 1% instead.

**Rejected:** An extra row in `agency_weights` carrying the 1% figure.

**Why.** The report's footnote says the Donors Delivering method does not count
IDA contributions to FP, while the revised Muskoka method applies 1%, and that
the two will be reconciled in a later report. Those are two live methods, not
two vintages of one. Adding a row would assert that 1% was published in some
year, which it was not. Making it an argument keeps the default reproducing the
report exactly, and puts any departure from it in the caller's own code.

**Cost.** One more argument, and it only means anything for `universe = "fp"`.
The default will need revisiting when the next report reconciles the two.

### Decision 11 — every hierarchical dimension pinned to its total

**Chosen:** `oecd_crs()` pins `CHANNEL`, `MODALITY` and `UNIT_MEASURE`;
`oecd_multi()` pins `RECIPIENT`, `SECTOR` and `UNIT_MEASURE`. `RECIPIENT` in CRS
is filtered after the fact against [crs_recipients] instead, because the
per-recipient breakdown is itself wanted.

**Rejected:** Leaving them open and summing whatever comes back.

**Why.** SDMX dimensions here are hierarchies, and a query returns the `_T`
total *alongside* every component, at more than one level of nesting. Measured:
one donor, one purpose code, one recipient, one year came back as 34 CRS rows
(channel `_T` plus 10000–60000, modality `_T` plus B/C/D plus B03/C01/D01/D02).
For MULTI, one donor-agency-year came back six times — `RECIPIENT` `DPGC` and
`DPGC_X` crossed with `SECTOR` `1000`, `998` and `99810`. Summing gave $20.7bn
for a US core contribution to the Global Fund whose true value is $3.3bn.

Nothing in the response marks which rows are totals, so this fails silently and
plausibly. Both fetchers now also assert one row per key and stop rather than
sum if that ever changes.

**Cost.** Channel and modality breakdowns are not reachable through these
functions. Adding them would mean returning those dimensions as columns rather
than opening the filter.

### Decision 5 — agency weights keyed by spending year *and* report edition

**Chosen:** `agency_weights` carries both `data_year` (2021–2024) and
`report_edition` (2025, 2026). 198 rows.

**Rejected:** A single year column. That was the first implementation, and it
was wrong — see below.

**Why.** The two columns mean different things and neither is redundant.
`data_year` is the year of the spending: the report computes each weight as the
proportion of that agency's own disbursements in that year benefiting the
universe, so it moves with the agency's disbursement mix. `report_edition` is
the year of the report, and every edition *recomputes* the weights for all
years it covers, including years already published, as the underlying data is
revised.

Those revisions are not cosmetic. Of the 66 agency-year-universe cells
published in both editions, **31 changed** — the Asian Development Bank's 2023
RMNCH weight is 5.18% as first published and 13.42% a year later. So weights
and published totals must come from the *same* edition; mixing them reproduces
neither report. The editions also differ in price base (2022 vs 2023 constant
prices).

The first version of this table had one `method_year` column, documented as the
methodology vintage rather than the spending year. That reading did not survive
contact with the 2025 edition: the columns are labelled 2021–2023 there and
2022–2024 in 2026, which only makes sense as spending years, and the report
says the percentages are computed from each multilateral's disbursements "each
year". The edition axis was missing entirely.

**Cost.** Callers must specify both keys, and each new edition adds ~99 rows
rather than replacing them. In exchange, the two editions together span four
spending years — which is exactly what makes the four per-donor RMNCH weights
identifiable.

---

## 7. Known gaps

Things carried forward deliberately, so they read as choices rather than
oversights.

- **Four RMNCH sector weights are per-donor and not yet derived** (12262,
  12263, 13040, 51010). The source marks these `varies*` because their RMNCH
  share is set per donor country. They must be back-derived from the published
  per-donor totals in Annex 3 of the report, which needs the CRS data those
  totals were built from — so this waits on the fetchers. Until then
  `muskoka(universe = "rmnch")` will refuse to compute rather than understate.
  SRHR and FP are complete.
- **The per-donor weights are identifiable but not yet computed.** Weights are
  taken as constant across years (Decision 8), so each published year is one
  equation against four unknowns. The 2025 and 2026 editions together cover
  2021–2024, which supplies the four needed. What remains is the CRS
  disbursements those totals were built from, i.e. the fetchers. Two hazards to
  watch when it runs: the editions revise each other's years, so equations must
  pair totals with same-edition weights and be deflated to a common base; and
  ill-conditioned donors amplify the 0.005-million rounding in the published
  totals, which `solve_donor_weights()` reports as an explicit error bound
  rather than leaving implicit.
- **No agency crosswalk yet.** `agency_weights` identifies agencies by display
  name. Joining to OECD data needs channel codes; matching on name at run time
  would fail silently.
- `README.md` is plain Markdown, not `README.Rmd`. The usage block above is
  therefore hand-written and not verified by anything. Run
  `usethis::use_readme_rmd()` if you want the examples executed on build.
- **No test-coverage workflow.** Codecov uploads need a `CODECOV_TOKEN`
  repository secret, so a coverage workflow shipped by the template would
  fail on the first push. Add it with
  `usethis::use_github_action("test-coverage")` once the token is set.
- **The pkgdown site needs one manual step.** In the repository settings,
  set Pages to deploy from the `gh-pages` branch. Until then the workflow
  builds the site successfully but nothing is served.
