# Builds `agency_weights`: the share of a multilateral agency's spending
# attributed to each funding universe, by methodology vintage.
#
#   Rscript data-raw/agency_weights.R
#
## Source: Donors Delivering for SRHR Report 2026, pp. 110-111.
## Full citation under "Provenance" below.

library(tibble)

# As in data-raw/sector_weights.R, weights are entered as PERCENTAGES to keep
# this script diffable against the source table, and converted to proportions
# at the bottom.
#
# `method_year` is the vintage of the METHODOLOGY, not the year of the
# spending it is applied to. The three columns of the source table are three
# successive revisions of the same coefficients; a caller reproducing a
# published 2023 figure needs the 2023 coefficients regardless of which
# years of CRS data the figure covers. Keeping vintages side by side rather
# than overwriting is what makes an old estimate reproducible after the
# method moves on.

raw <- tribble(
  ~agency,                     ~method_year, ~rmnch, ~srhr,   ~fp,
  "GAVI",                              2022,  91.00,  3.71,  0.00,
  "GAVI",                              2023,  91.00,  2.07,  0.00,
  "GAVI",                              2024,  91.00,  2.37,  0.00,
  "Global Fund",                       2022,  43.42, 54.22,  5.00,
  "Global Fund",                       2023,  44.11, 57.23,  5.00,
  "Global Fund",                       2024,  44.91, 57.05,  5.00,
  "IDA",                               2022,   9.83,  3.88,  0.00, # fp: see below
  "IDA",                               2023,   7.12,  3.00,  0.00, # fp: see below
  "IDA",                               2024,   6.49,  2.73,  0.00, # fp: see below
  "UNFPA",                             2022,  49.00, 91.33, 20.00,
  "UNFPA",                             2023,  49.00, 90.36, 20.00,
  "UNFPA",                             2024,  49.00, 90.48, 20.00,
  "UNICEF",                            2022,  15.00,  5.31,  0.00,
  "UNICEF",                            2023,  15.00,  4.97,  0.00,
  "UNICEF",                            2024,  15.00,  5.00,  0.00,
  "UNAIDS",                            2022,   0.00, 50.00,  0.00,
  "UNAIDS",                            2023,  43.80, 100.00, 0.00,
  "UNAIDS",                            2024,  45.36, 58.93,  0.00,
  "UNRWA",                             2022,   6.44,  1.61,  0.00,
  "UNRWA",                             2023,   5.22,  1.30,  0.00,
  "UNRWA",                             2024,   5.32,  1.33,  0.00,
  "World Food Programme",              2022,   3.77,  0.97,  0.00,
  "World Food Programme",              2023,   4.07,  1.11,  0.00,
  "World Food Programme",              2024,   3.12,  0.70,  0.00,
  "World Health Organisation",         2022,  29.15, 10.92,  5.00,
  "World Health Organisation",         2023,  28.62, 10.58,  5.00,
  "World Health Organisation",         2024,  28.03, 10.11,  5.00,
  "Asian Development Bank",            2022,   7.19,  1.33,  0.00,
  "Asian Development Bank",            2023,  13.42,  3.38,  0.00,
  "Asian Development Bank",            2024,   7.13,  0.75,  0.00,
  "African Development Fund",          2022,   1.45,  0.50,  0.00,
  "African Development Fund",          2023,   0.76,  0.21,  0.00,
  "African Development Fund",          2024,   0.63,  0.24,  0.00
)

# ---- IDA and family planning ---------------------------------------------
#
# IDA's FP weight is given as "0.00%*" in all three vintages, where every
# other zero is written plainly. The footnote reads:
#
#   "Currently the Donors Delivering methodology does not count IDA
#    contributions to FP. However, as the revised Muskoka applies 1% to IDA,
#    and due to the continued relevance of this multilateral contribution to
#    FP, this will be reassessed for alignment in time for the next report."
#
# So 0% is a deliberate methodological choice, not missing information, and
# it is stored here as a plain 0. The 1% alternative is NOT a second row in
# this table: it belongs to the revised Muskoka method rather than to the
# Donors Delivering vintages, and adding it here would imply a vintage in
# which it was the published figure. It is offered instead as the `ida`
# argument of `muskoka()`, which substitutes 1% at call time when
# `universe = "fp"`. The default is 0, matching this table and the published
# report; a caller who wants the revised Muskoka treatment asks for it and
# the change is visible in their code.
#
# Expect this to move: the footnote says it is under review for the next
# report. When it changes, it changes as a new method_year row here, and the
# `ida` argument's default should be revisited at the same time.

# ---- provenance ----------------------------------------------------------
# Donors Delivering for SRHR Report 2026, "Selected percentages per OECD DAC
# codes (as under the Muskoka 2, the Donors Delivering for SRHR, and the FP
# methodology)", pages 110-111. Retrieved 2026-07-29 from
# https://donorsdelivering.report/wp-content/uploads/2026/06/DD_Report2026_Update.pdf
#
# RMNCH follows Muskoka 2 (London School of Hygiene and Tropical Medicine);
# FP follows the revised Muskoka method agreed at the 2012 London Summit;
# SRHR follows the Donors Delivering method. The three overlap by
# construction, so their totals must never be added together.

stopifnot(
  !anyDuplicated(raw[c("agency", "method_year")]),
  all(raw$method_year %in% 2022:2024)
)

# Long format, matching sector_weights: one row per
# (agency, method_year, universe).
agency_weights <- do.call(rbind, lapply(
  c("rmnch", "srhr", "fp"),
  function(u) {
    tibble(
      agency      = raw$agency,
      method_year = as.integer(raw$method_year),
      universe    = factor(u, levels = c("rmnch", "srhr", "fp")),
      weight      = raw[[u]] / 100
    )
  }
))
agency_weights <- agency_weights[
  order(agency_weights$universe, agency_weights$agency, agency_weights$method_year),
]
rownames(agency_weights) <- NULL

stopifnot(
  nrow(agency_weights) == nrow(raw) * 3L,
  all(agency_weights$weight >= 0 & agency_weights$weight <= 1, na.rm = TRUE),
  # Every agency must appear in every vintage, or a caller switching
  # method_year would silently lose an agency from the total.
  all(table(agency_weights$agency, agency_weights$method_year) == 3L)
)

message(
  "agency_weights: ", nrow(agency_weights), " rows, ",
  length(unique(agency_weights$agency)), " agencies x ",
  length(unique(agency_weights$method_year)), " vintages, ",
  sum(is.na(agency_weights$weight)), " unresolved weights"
)

usethis::use_data(agency_weights, overwrite = TRUE, compress = "xz")
