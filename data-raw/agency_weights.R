# Builds `agency_weights`: the share of a multilateral agency's spending
# attributed to each funding universe, per spending year and per report
# edition.
#
#   Rscript data-raw/agency_weights.R
#
## Source: Donors Delivering for SRHR Reports 2025 (pp. 104-105) and 2026
## (pp. 110-111). Full citation under "Provenance" below.

library(tibble)

# As in data-raw/sector_weights.R, weights are entered as PERCENTAGES to keep
# this script diffable against the source tables, and converted to
# proportions at the bottom.
#
# ---- why there are two keys, not one -------------------------------------
#
# `data_year` is the year of the SPENDING. The report calculates these
# percentages as "the proportion of all disbursements from the multilateral
# that benefit SRHR each year", so an agency's weight genuinely differs
# between 2022 and 2023 because its own disbursement mix differed.
#
# `report_edition` is the year of the REPORT. Each edition recomputes the
# weights for every year it covers, including years an earlier edition
# already published, as the underlying multilateral data is revised. The
# revisions are not cosmetic: of the 22 agency-years published in both the
# 2025 and 2026 editions, 20 differ, and some differ by a lot — the Asian
# Development Bank's 2023 RMNCH weight is 5.18% in the 2025 edition and
# 13.42% in the 2026 edition.
#
# Both keys are therefore load-bearing, and a caller must take the weights
# and the published totals from the SAME edition. Pairing one edition's
# totals with another's weights produces a number that reproduces neither
# report. The editions also use different price bases — 2022 constant prices
# in 2025, 2023 constant prices in 2026 — which is a second reason not to mix
# them without deflating.

ed2025 <- tribble(
  ~agency,                     ~data_year, ~rmnch,  ~srhr,   ~fp,
  "GAVI",                            2021,  91.00,   8.52,  0.00,
  "GAVI",                            2022,  91.00,   3.67,  0.00,
  "GAVI",                            2023,  91.00,   2.07,  0.00,
  "Global Fund",                     2021,  43.78,  58.49,  5.00,
  "Global Fund",                     2022,  42.70,  53.49,  5.00,
  "Global Fund",                     2023,  42.68,  55.41,  5.00,
  "IDA",                             2021,   6.02,   2.68,  0.00,
  "IDA",                             2022,   6.80,   2.68,  0.00,
  "IDA",                             2023,   5.07,   2.13,  0.00,
  "UNFPA",                           2021,  49.00,  95.04, 20.00,
  "UNFPA",                           2022,  49.00,  98.19, 20.00,
  "UNFPA",                           2023,  49.00,  98.09, 20.00,
  "UNICEF",                          2021,  15.00,   6.44,  0.00,
  "UNICEF",                          2022,  15.00,   5.82,  0.00,
  "UNICEF",                          2023,  15.00,   5.41,  0.00,
  "UNAIDS",                          2021,   0.00,  50.00,  0.00,
  "UNAIDS",                          2022,   0.00,  50.00,  0.00,
  "UNAIDS",                          2023,  43.72, 100.00,  0.00,
  "UNRWA",                           2021,   6.49,   1.70,  0.00,
  "UNRWA",                           2022,   6.68,   1.74,  0.00,
  "UNRWA",                           2023,   6.18,   1.81,  0.00,
  "World Food Programme",            2021,   3.98,   1.03,  0.00,
  "World Food Programme",            2022,   3.76,   0.97,  0.00,
  "World Food Programme",            2023,   4.02,   1.09,  0.00,
  "World Health Organisation",       2021,  26.55,   9.92,  5.00,
  "World Health Organisation",       2022,  29.19,  10.92,  5.00,
  "World Health Organisation",       2023,  28.65,  10.58,  5.00,
  "Asian Development Bank",          2021,   2.40,   0.39,  0.00,
  "Asian Development Bank",          2022,   3.24,   0.60,  0.00,
  "Asian Development Bank",          2023,   5.18,   1.30,  0.00,
  "African Development Fund",        2021,   1.21,   0.13,  0.00,
  "African Development Fund",        2022,   0.98,   0.34,  0.00,
  "African Development Fund",        2023,   0.56,   0.15,  0.00
)

ed2026 <- tribble(
  ~agency,                     ~data_year, ~rmnch,  ~srhr,   ~fp,
  "GAVI",                            2022,  91.00,   3.71,  0.00,
  "GAVI",                            2023,  91.00,   2.07,  0.00,
  "GAVI",                            2024,  91.00,   2.37,  0.00,
  "Global Fund",                     2022,  43.42,  54.22,  5.00,
  "Global Fund",                     2023,  44.11,  57.23,  5.00,
  "Global Fund",                     2024,  44.91,  57.05,  5.00,
  "IDA",                             2022,   9.83,   3.88,  0.00, # fp: see below
  "IDA",                             2023,   7.12,   3.00,  0.00, # fp: see below
  "IDA",                             2024,   6.49,   2.73,  0.00, # fp: see below
  "UNFPA",                           2022,  49.00,  91.33, 20.00,
  "UNFPA",                           2023,  49.00,  90.36, 20.00,
  "UNFPA",                           2024,  49.00,  90.48, 20.00,
  "UNICEF",                          2022,  15.00,   5.31,  0.00,
  "UNICEF",                          2023,  15.00,   4.97,  0.00,
  "UNICEF",                          2024,  15.00,   5.00,  0.00,
  "UNAIDS",                          2022,   0.00,  50.00,  0.00,
  "UNAIDS",                          2023,  43.80, 100.00,  0.00,
  "UNAIDS",                          2024,  45.36,  58.93,  0.00,
  "UNRWA",                           2022,   6.44,   1.61,  0.00,
  "UNRWA",                           2023,   5.22,   1.30,  0.00,
  "UNRWA",                           2024,   5.32,   1.33,  0.00,
  "World Food Programme",            2022,   3.77,   0.97,  0.00,
  "World Food Programme",            2023,   4.07,   1.11,  0.00,
  "World Food Programme",            2024,   3.12,   0.70,  0.00,
  "World Health Organisation",       2022,  29.15,  10.92,  5.00,
  "World Health Organisation",       2023,  28.62,  10.58,  5.00,
  "World Health Organisation",       2024,  28.03,  10.11,  5.00,
  "Asian Development Bank",          2022,   7.19,   1.33,  0.00,
  "Asian Development Bank",          2023,  13.42,   3.38,  0.00,
  "Asian Development Bank",          2024,   7.13,   0.75,  0.00,
  "African Development Fund",        2022,   1.45,   0.50,  0.00,
  "African Development Fund",        2023,   0.76,   0.21,  0.00,
  "African Development Fund",        2024,   0.63,   0.24,  0.00
)

# ---- IDA and family planning ---------------------------------------------
#
# The 2026 edition gives IDA's FP weight as "0.00%*" in every year, where
# every other zero is written plainly. Its footnote reads:
#
#   "Currently the Donors Delivering methodology does not count IDA
#    contributions to FP. However, as the revised Muskoka applies 1% to IDA,
#    and due to the continued relevance of this multilateral contribution to
#    FP, this will be reassessed for alignment in time for the next report."
#
# The 2025 edition carries a plain 0.00% with no footnote, so the caveat is
# new in 2026. Either way the published figure is 0, and that is what is
# stored: a deliberate methodological choice, not missing information.
#
# The 1% alternative is NOT a row in this table. It belongs to the revised
# Muskoka method rather than to any published edition, and a row would assert
# that 1% appeared in some report, which it did not. It is offered instead as
# the `ida` argument of `muskoka()`, applied at call time when
# `universe = "fp"`, defaulting to 0 so that an untouched call reproduces the
# published report. Expect the default to need revisiting: the footnote says
# the two methods are to be reconciled in the next edition.

# ---- provenance ----------------------------------------------------------
# Donors Delivering for SRHR Report 2026, "Selected percentages per OECD DAC
# codes (as under the Muskoka 2, the Donors Delivering for SRHR, and the FP
# methodology)", pages 110-111. Retrieved 2026-07-29 from
# https://donorsdelivering.report/wp-content/uploads/2026/06/DD_Report2026_Update.pdf
#
# Donors Delivering for SRHR Report 2025, same table, pages 104-105.
# Retrieved 2026-07-29 from
# https://donorsdelivering.report/wp-content/uploads/2025/06/DDSRHR2025.pdf
#
# RMNCH follows Muskoka 2 (London School of Hygiene and Tropical Medicine);
# FP follows the revised Muskoka method agreed at the 2012 London Summit;
# SRHR follows the Donors Delivering method. The three overlap by
# construction, so their totals must never be added together.
#
# The SECTOR table is identical in both editions — all 33 codes, all three
# universes — so `sector_weights` needs no edition key. Only the multilateral
# weights were revised. Verified by diffing the two extracted tables.

raw <- rbind(
  cbind(ed2025, report_edition = 2025L),
  cbind(ed2026, report_edition = 2026L)
)

stopifnot(
  !anyDuplicated(raw[c("agency", "data_year", "report_edition")]),
  all(raw$data_year %in% 2021:2024),
  # Each edition covers exactly three consecutive spending years.
  all(vapply(
    split(raw$data_year, raw$report_edition),
    function(y) {
      yrs <- sort(unique(y))
      length(yrs) == 3L && all(diff(yrs) == 1)
    },
    logical(1)
  ))
)

# Long format, matching sector_weights: one row per
# (agency, data_year, universe, report_edition).
agency_weights <- do.call(rbind, lapply(
  c("rmnch", "srhr", "fp"),
  function(u) {
    tibble(
      agency         = raw$agency,
      data_year      = as.integer(raw$data_year),
      universe       = factor(u, levels = c("rmnch", "srhr", "fp")),
      weight         = raw[[u]] / 100,
      report_edition = as.integer(raw$report_edition)
    )
  }
))
agency_weights <- agency_weights[
  order(agency_weights$report_edition, agency_weights$universe,
        agency_weights$agency, agency_weights$data_year),
]
rownames(agency_weights) <- NULL

stopifnot(
  nrow(agency_weights) == nrow(raw) * 3L,
  all(agency_weights$weight >= 0 & agency_weights$weight <= 1, na.rm = TRUE),
  # Every agency must appear in every year an edition covers, or a caller
  # switching edition would silently lose an agency from the total.
  all(table(agency_weights$agency, agency_weights$data_year,
            agency_weights$report_edition) %in% c(0L, 3L))
)

overlap <- merge(
  agency_weights[agency_weights$report_edition == 2025L, ],
  agency_weights[agency_weights$report_edition == 2026L, ],
  by = c("agency", "data_year", "universe")
)
message(
  "agency_weights: ", nrow(agency_weights), " rows, ",
  length(unique(agency_weights$agency)), " agencies, spending years ",
  min(agency_weights$data_year), "-", max(agency_weights$data_year),
  ", editions ",
  paste(sort(unique(agency_weights$report_edition)), collapse = "/"),
  "\n  cells published in both editions: ", nrow(overlap),
  ", of which ", sum(overlap$weight.x != overlap$weight.y), " were revised"
)

usethis::use_data(agency_weights, overwrite = TRUE, compress = "xz")
