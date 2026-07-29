# Builds `sector_weights`: the share of each CRS purpose-code disbursement
# attributed to each funding universe under the revised Muskoka method.
#
#   Rscript data-raw/sector_weights.R
#
## Source: Donors Delivering for SRHR Report 2026, pp. 110-111.
## Full citation under "Provenance" below.

library(tibble)

# Weights are entered here as PERCENTAGES, exactly as they appear in the
# source table, so that this script can be diffed against it by eye. They are
# converted to proportions at the bottom, because every downstream use is a
# multiplication against a disbursement and a stray factor of 100 in that
# position is both easy to introduce and hard to notice in a total.
#
# NA means "no agreed weight yet", NOT zero. The distinction matters: a zero
# says the sector contributes nothing, an NA says we do not know what it
# contributes. Collapsing the two would silently understate every total that
# touches an affected sector, so `muskoka()` must refuse to run rather than
# treat NA as 0. The two reasons a cell is NA are recorded per row below.

raw <- tribble(
  ~purpose_code, ~purpose_name,                                                 ~rmnch, ~srhr,  ~fp,
  "11230",       "Basic life skills for adults",                                     0,   4.4,    0,
  "11231",       "Basic life skills for youth",                                      0,   9.4,    0,
  "12110",       "Health policy and administrative management",                     40,  15.4,    5,
  "12181",       "Medical education/training",                                      40,  16.1,    5,
  "12182",       "Medical research",                                                 0,   0.0,    0,
  "12191",       "Medical services",                                               100,  17.5,    5,
  "12220",       "Basic health care",                                               40,  10.0,    5,
  "12230",       "Basic health infrastructure",                                     40,  13.6,    5,
  "12240",       "Basic nutrition",                                                100,  38.4,    0,
  "12250",       "Infectious disease control",                                      40,   2.0,    0,
  "12261",       "Health education",                                                40,  17.2,    5,
  "12262",       "Malaria control",                                                 NA,  15.0,    0, # rmnch varies*
  "12263",       "Tuberculosis control",                                            NA,   0.0,    0, # rmnch varies*
  "12281",       "Health personnel development",                                    40,  17.0,    5,
  "13010",       "Population policy and administrative management",                 40,  35.4,    5,
  "13020",       "Reproductive health care",                                       100,  83.7,   20,
  "13030",       "Family planning",                                                100,  99.3,  100,
  "13040",       "STD control including HIV/AIDS",                                  NA, 100.0,    3, # rmnch varies*
  "13081",       "Personnel development for population and reproductive health",   100,  84.6,    5,
  "14030",       "Basic drinking water supply and basic sanitation",                15,   0.0,    0,
  "14031",       "Basic drinking water supply",                                     15,   0.0,    0,
  "14032",       "Basic sanitation",                                                15,   0.0,    0,
  "15150",       "Democratic participation and civil society",                       0,   1.2,    0,
  "15160",       "Human rights",                                                     0,   6.3,    0,
  "15170",       "Women's equality organisations and institutions",                  0,   4.4,    0,
  "15180",       "Ending violence against women and girls",                          0,   9.4,    0,
  "16064",       "Social mitigation of HIV and AIDS",                                0,  15.4,    0,
  "51010",       "General budget support-related aid",                              NA,  16.1,  0.5, # rmnch varies*
  "72010",       "Material relief assistance and services",                        4.4,   0.0,    0,
  "72040",       "Emergency food aid",                                             1.9,  17.5,    0,
  "72050",       "Relief coordination, protection and support services",           2.1,  10.0,    0,
  "73010",       "Reconstruction relief and rehabilitation",                       1.4,  13.6,    0,
  "74020",       "Multi-hazard response preparedness",                             1.5,   0.3,    0
)

# ---- why the NAs are NA --------------------------------------------------
#
# "varies*" — The source gives no single RMNCH figure for 12262 (malaria),
#   12263 (tuberculosis), 13040 (HIV/AIDS) and 51010 (general budget
#   support), because the RMNCH share of these sectors is set PER DONOR
#   COUNTRY rather than globally. They are NA here because this table has one
#   weight per (code, universe) and cannot hold a per-donor value — not
#   because the numbers are unknowable.
#
#   The donor-level weights are to be derived from the published per-donor
#   RMNCH totals in Annex 3 of the source report. That derivation needs the
#   CRS disbursements those totals were built from, so it waits on the OECD
#   fetchers. When it lands it belongs in its own table keyed by donor —
#   NOT as extra rows here, which would make `weight` mean different things
#   in different rows.
#
#   Until then `muskoka(universe = "rmnch")` must refuse to compute. Three of
#   the four are large CRS sectors and a silent zero would understate every
#   donor's total.

# ---- a coincidence in the SRHR column, reviewed and accepted -------------
# The SRHR values for 15170, 15180, 16064, 51010, 72010, 72040, 72050 and
# 73010 happen to reproduce the SRHR values of the table's first eight rows
# (11230, 11231, 12110, 12181, 12182, 12191, 12220, 12230) exactly and in
# order: 4.4, 9.4, 15.4, 16.1, 0.0, 17.5, 10.0, 13.6. This looks like a
# spreadsheet fill and was queried as one. It is not: the values are correct
# as given. Recorded here so the next person to notice the pattern does not
# spend the same time on it.

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
  !anyDuplicated(raw$purpose_code),
  # CRS purpose codes are five digits. Held as character, not integer, so
  # that codes are never arithmetic and never lose a leading digit in a join
  # against a CRS extract that stores them as text.
  all(grepl("^[0-9]{5}$", raw$purpose_code))
)

# Long format: one row per (purpose_code, universe). `muskoka()` takes a
# single universe and joins on purpose_code, which a wide table would make
# awkward — it would have to select a column by name at runtime.
sector_weights <- do.call(rbind, lapply(
  c("rmnch", "srhr", "fp"),
  function(u) {
    tibble(
      purpose_code = raw$purpose_code,
      purpose_name = raw$purpose_name,
      universe     = factor(u, levels = c("rmnch", "srhr", "fp")),
      weight       = raw[[u]] / 100
    )
  }
))
sector_weights <- sector_weights[
  order(sector_weights$universe, sector_weights$purpose_code),
]
rownames(sector_weights) <- NULL

stopifnot(
  nrow(sector_weights) == nrow(raw) * 3L,
  # A weight is a share of a disbursement; outside [0, 1] it is a data entry
  # error, not an unusual case.
  all(sector_weights$weight >= 0 & sector_weights$weight <= 1, na.rm = TRUE)
)

message(
  "sector_weights: ", nrow(sector_weights), " rows, ",
  sum(is.na(sector_weights$weight)), " unresolved weights (",
  paste(
    vapply(
      split(sector_weights, sector_weights$universe),
      function(d) paste0(as.character(d$universe[1]), ": ", sum(is.na(d$weight))),
      character(1)
    ),
    collapse = ", "
  ), ")"
)

usethis::use_data(sector_weights, overwrite = TRUE, compress = "xz")
