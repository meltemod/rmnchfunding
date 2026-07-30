# GBD extract needed for CRS codes 12262, 12263 and 13040

The RMNCH weights for malaria control (12262), tuberculosis control (12263) and
STD control including HIV/AIDS (13040) are computed from IHME Global Burden of
Disease **case numbers**, by location, age, sex and year.

**This extract is not in the repository and cannot be fetched automatically.**
GHDx has no unauthenticated API: every `https://vizhub.healthdata.org/gbd-results/api/…`
path returns the single-page-app HTML shell rather than data, whatever query is
appended. The file has to be downloaded by hand, once, and committed here.

Until it exists, `data-raw/rmnch_recipient_weights.R` builds only code 51010,
these three codes stay `NA` in `sector_weights`, and `muskoka(universe = "rmnch")`
refuses to compute rather than return a total missing three large sectors.

## The exact query to run

At <https://vizhub.healthdata.org/gbd-results/> (a free account is required),
request **one extract** with:

| Field | Value |
|---|---|
| GBD round | Latest available. **Record which**, in `VINTAGE.txt` below |
| Measure | **Incidence** *and* **Prevalence** |
| Metric | **Number** — case counts, not rates or percentages |
| Cause | **Malaria**, **HIV/AIDS**, **Tuberculosis** |
| Location | **All locations** (countries and territories) |
| Age | **<5 years**, **15-49 years**, **All ages** |
| Sex | **Both** and **Female** |
| Year | **2002** to the latest available |

Measure by code: malaria uses **Incidence**; HIV/AIDS and tuberculosis use
**Prevalence**. Requesting both measures in one extract is simpler than two
downloads and the build script selects the right one per cause.

Age group `15-49` and sex `Female` are needed only for the HIV reproductive
health numerator, but are cheap to include.

## What to do with the download

1. Put the CSV (or the unzipped CSVs, if GBD splits the download) in this
   directory. Any filename ending `.csv` is picked up.
2. Create `VINTAGE.txt` here recording, in plain text:
   - the GBD round (for example "GBD 2021"),
   - the download date,
   - the exact query as run, if it differs at all from the table above.

   The reference workbook this package validates against used an extract
   downloaded 29 December 2018 from the GBD 2017 round. Recording the vintage
   is what makes a later rebuild explicable rather than merely different.
3. Re-run `Rscript data-raw/rmnch_recipient_weights.R`.

Expected columns, which is what the build script reads: `measure_name`,
`location_name`, `sex_name`, `age_name`, `cause_name`, `metric_name`, `year`,
`val`. GBD has changed these header names between rounds, so the script checks
for them and fails with the names it actually found rather than computing from
the wrong column.

## The formulas the extract feeds

For every location and year, with all counts being **Number** (cases):

    12262 malaria, measure = Incidence
      RH  = 0
      MNH = 0.15                      fixed, from the Countdown method
      CH  = cases <5, both sexes / cases all ages, both sexes
      weight = 0.15 + CH

    13040 HIV/AIDS, measure = Prevalence
      RH  = cases females 15-49 / cases all ages, both sexes
      MNH = 0
      CH  = cases <5, both sexes / cases all ages, both sexes
      weight = RH + CH

    12263 tuberculosis, measure = Prevalence
      RH  = 0
      MNH = 0
      CH  = cases <5, both sexes / cases all ages, both sexes
      weight = CH

## Licence and citation

IHME GBD data is **CC BY-NC 4.0**. It is not redistributed by this package —
only the derived weights are — but the extract committed here must carry its
vintage so the derivation can be traced.

Institute for Health Metrics and Evaluation (IHME), Global Burden of Disease
Study Results. Seattle: University of Washington.
<https://ghdx.healthdata.org/gbd-results-tool>

Method: Dingle A, Schäferhoff M, Borghi J, Lewis Sabin M, Arregoces L,
Martinez-Alvarez M, Pitt C. "Estimates of aid for reproductive, maternal,
newborn, and child health: findings from application of the Muskoka2 method,
2002–17." *The Lancet Global Health* 2020; 8(3): e374–e386,
doi:10.1016/S2214-109X(20)30005-X, supplementary appendix sections I.2 and I.3.

## One decision still open

GBD's latest round reaches 2021, while the target window runs to 2024. The
same carry-forward rule as the World Bank component applies — most recent
observed year, capped at `MAX_CARRY_FORWARD` (3 years), with `source_year`
recording which year a weight came from. That covers 2022–2024 from 2021. If
a newer round extends coverage, the cap stops mattering.
