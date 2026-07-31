# Builds `sector_weights`: the share of each CRS purpose-code disbursement
# attributed to each funding universe under the revised Muskoka method.
#
#   Rscript data-raw/sector_weights.R
#
## Sources: Donors Delivering for SRHR Report 2026, pp. 110-111, EXCEPT for
## nine misprinted values taken from the 2023 and 2024 editions instead.
## See "nine values are NOT taken from the 2026 edition" below.

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
  "12191",       "Medical services",                                                40,  17.5,    5,  # 2026 misprint: 100
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
  "15170",       "Women's equality organisations and institutions",                  0,   7.6,    0,  # 2026 misprint: 4.4
  "15180",       "Ending violence against women and girls",                          0,  41.5,    0,  # 2026 misprint: 9.4
  "16064",       "Social mitigation of HIV and AIDS",                                0,  50.0,    0,  # 2026 misprint: 15.4
  "51010",       "General budget support-related aid",                              NA,   0.0,  0.5, # rmnch varies*; 2026 misprint: 16.1
  "72010",       "Material relief assistance and services",                        4.4,   2.3,    0,  # 2026 misprint: 0.0
  "72040",       "Emergency food aid",                                             1.9,   0.1,    0,  # 2026 misprint: 17.5
  "72050",       "Relief coordination, protection and support services",           2.1,   0.7,    0,  # 2026 misprint: 10.0
  "73010",       "Reconstruction relief and rehabilitation",                       1.4,   0.6,    0,  # 2026 misprint: 13.6
  "74020",       "Multi-hazard response preparedness",                             1.5,   0.3,    0
)

# ---- why the NAs are NA --------------------------------------------------
#
# "varies*" — The source gives no single RMNCH figure for 12262 (malaria),
#   12263 (tuberculosis), 13040 (HIV/AIDS) and 51010 (general budget
#   support), because Muskoka2 sets the RMNCH share of these sectors PER
#   RECIPIENT COUNTRY AND YEAR, computed from disease-burden and government
#   health-expenditure data. They are NA here because this table has one
#   weight per (code, universe) and cannot hold a value that varies by
#   recipient and year — not because the numbers are unknowable.
#
#   They live in `rmnch_recipient_weights` instead, joined to a disbursement
#   on its recipient and year. See data-raw/rmnch_recipient_weights.R.
#
#   An earlier version of this comment said the weights vary per DONOR and
#   were to be recovered by solving published donor totals. That was a
#   misreading of the method: they vary by recipient, and are computed from
#   source data rather than recovered. `solve_donor_weights()` survives as an
#   independent cross-check on the computed weights, not as their source.
#
#   Until the disease codes are built, `muskoka(universe = "rmnch")` must
#   refuse to compute: three of the four are large CRS sectors and a silent
#   zero would understate every result.

# ---- nine values are NOT taken from the 2026 edition ----------------------
# Eight SRHR values and one RMNCH value in the 2026 table are misprints. The
# values above are the 2023 and 2024 editions', which are identical to each
# other and which reproduce the 2026 edition's own published donor totals.
#
# THE SRHR FILL. In the 2026 table the SRHR column for 15170, 15180, 16064,
# 51010, 72010, 72040, 72050 and 73010 repeats the column's first eight
# values -- 4.4, 9.4, 15.4, 16.1, 0.0, 17.5, 10.0, 13.6 -- exactly and in
# order. Eight consecutive cells overwritten with the top of their own
# column is what a spreadsheet fill does. An earlier version of this file
# flagged the pattern, queried it, and then recorded it as correct as given.
# That was wrong, and the note is replaced rather than amended so nobody
# reads the old conclusion.
#
# HOW IT WAS ESTABLISHED, before the 2023/2024 editions were consulted. The
# 2026 report publishes SRHR totals for 33 providers over three years. With
# 33 sector weights that is 99 equations in 33 unknowns, so the weights can
# be solved for by constrained least squares and compared with the printed
# table. Validating the same solver on family planning -- whose weights are
# known correct, since they reproduce the published FP totals exactly --
# recovers them to within 0.3 points. Applied to SRHR it returns the printed
# value for 25 of 33 codes and disagrees on exactly the eight above.
#
# The eight are not merely a worse fit, they are arithmetically impossible.
# Under the printed weights, 27 of 99 provider-years require a NEGATIVE
# multilateral half to reach their published total; EU Institutions 2023
# needs -3,411m. No agency weights can produce that, since a weighted sum of
# non-negative contributions cannot be negative. Under the values above only
# 1 of 99 does.
#
# The 2023 and 2024 editions then confirmed it outright: they print the
# values used above, and the solved figures match them to a mean of 0.08
# percentage points across the eight. Median error against the published
# donor totals falls from 11.4% to 0.07%.
#
# THE RMNCH MISPRINT. Separately, 12191 medical services is 40% in the 2023
# and 2024 editions and 100% in the 2026. 40% is right: it gives a median
# error against the 2026 edition's own RMNCH totals of 0.20% (83 of 99
# provider-years within 2%), against 2.79% at 100% (42 of 99). This one is
# not part of the fill and has its own cause, unknown.
#
# Full analysis: vignettes/errata.Rmd.

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
