# Builds `rmnch_recipient_weights`: the RMNCH weights that Muskoka2 sets per
# RECIPIENT and YEAR rather than globally.
#
#   Rscript data-raw/rmnch_recipient_weights.R
#
## Sources: World Bank API v2 (general budget support component); IHME Global
## Burden of Disease extract (disease components — see "Not yet built" below).

# ---- what these are -------------------------------------------------------
#
# Four CRS purpose codes carry no single RMNCH percentage in the published
# tables, which mark them "varies*":
#
#   12262  malaria control
#   12263  tuberculosis control
#   13040  STD control including HIV/AIDS
#   51010  general budget support-related aid
#
# Muskoka2 computes each from open data, per recipient country and year. The
# weight is the sum of three components — reproductive health, maternal and
# newborn health, and child health:
#
#   weight(code, recipient, year) = RH + MNH + CH
#
# Method and formulas: Dingle A, Schaferhoff M, Borghi J, Lewis Sabin M,
# Arregoces L, Martinez-Alvarez M, Pitt C. "Estimates of aid for reproductive,
# maternal, newborn, and child health: findings from application of the
# Muskoka2 method, 2002-17." Lancet Global Health 2020; 8(3): e374-e386,
# doi:10.1016/S2214-109X(20)30005-X, with supplementary appendix sections I.2
# and I.3. Values decoded from the accompanying data collection, Muskoka2-
# 290120v2.xlsb (v1.4, 24 March 2020), doi:10.17037/DATA.00001526, CC BY-NC 3.0.
#
# NOTE ON AN EARLIER MISREADING: this package previously documented these
# weights as varying per DONOR, recoverable by solving published donor totals.
# That was wrong. They vary by recipient and year, and are computed from source
# data rather than recovered. `solve_donor_weights()` is retained as an
# independent cross-check on the result, not as the source.

# ---- general budget support (51010) ---------------------------------------
#
#   g   = domestic general government health expenditure, as a share of general
#         government expenditure
#   fem, mal = female and male shares of total population
#   wra = women of reproductive age (15-49) as a share of the female population
#   u5f, u5m = ages 0-4 as a share of the female and male populations
#
#   RH  = g * fem * wra
#   MNH = 0
#   CH  = g * (fem * u5f + mal * u5m)
#
# Every World Bank figure is a PERCENTAGE and is divided by 100 on arrival, so
# that everything below is a proportion. Getting this wrong would inflate a
# weight by 10,000, which is obvious, or by 100, which is not.

TARGET_YEARS <- 2021:2024

# How far a value may be carried forward when a year has no observation.
# Health expenditure shares move slowly, so a year or two is defensible; five
# is not. Beyond this the weight is NA rather than a guess.
MAX_CARRY_FORWARD <- 3L

# Pull a longer run than the target window so that carry-forward has something
# to carry, and so the 2002-2017 reference period can be reproduced for
# validation.
FETCH_FROM <- 2002L
FETCH_TO <- 2024L

devtools::load_all(quiet = TRUE)

crosswalk <- local({
  e <- new.env(); load("data/recipient_crosswalk.rda", e)
  get("recipient_crosswalk", e)
})

# ---- verify the indicators before relying on them -------------------------
message("Verifying World Bank indicator codes ...")
for (nm in names(WB_INDICATORS)) {
  official <- wb_check_indicator(WB_INDICATORS[[nm]])
  message("  ", format(WB_INDICATORS[[nm]], width = 20), official)
}

message("Fetching World Bank indicators ", FETCH_FROM, "-", FETCH_TO, " ...")
panels <- lapply(names(WB_INDICATORS), function(nm) {
  d <- wb_fetch(WB_INDICATORS[[nm]], FETCH_FROM, FETCH_TO)
  d$indicator <- nm
  d
})
wb <- do.call(rbind, panels)
wb <- wb[!is.na(wb$iso3) & nzchar(wb$iso3), ]

# Wide, one row per economy-year.
wide <- stats::reshape(
  as.data.frame(wb[c("iso3", "year", "indicator", "value")]),
  idvar = c("iso3", "year"), timevar = "indicator", direction = "wide"
)
names(wide) <- sub("^value[.]", "", names(wide))

# Percentages to proportions, once, here.
for (nm in names(WB_INDICATORS)) wide[[nm]] <- wide[[nm]] / 100

wide$wra <- rowSums(wide[WB_WRA_BANDS], na.rm = FALSE)

gbs <- data.frame(
  iso3 = wide$iso3,
  year = wide$year,
  rh  = wide$gov_health_share * wide$female_share * wide$wra,
  mnh = 0,
  ch  = wide$gov_health_share *
    (wide$female_share * wide$u5_female + wide$male_share * wide$u5_male),
  stringsAsFactors = FALSE
)
gbs$weight <- gbs$rh + gbs$mnh + gbs$ch
gbs <- gbs[!is.na(gbs$weight), ]

stopifnot(
  # A weight is a share of a disbursement. Outside [0, 1] means a percentage
  # escaped the division above, or an indicator changed meaning.
  all(gbs$weight >= 0 & gbs$weight <= 1),
  # MNH is structurally zero for general budget support, not merely small.
  all(gbs$mnh == 0)
)
message("  general budget support: ", nrow(gbs), " economy-years computed, ",
        length(unique(gbs$iso3)), " economies, ",
        min(gbs$year), "-", max(gbs$year))

# ---- carry forward, flagged ----------------------------------------------
# A recipient-year with no observation takes the most recent earlier year that
# has one, and records which year that was. The flag is the point: an
# extrapolated weight and an observed one are otherwise indistinguishable, and
# World Bank health-expenditure coverage stops in 2023 (7 economies report
# 2024, against 203 for 2023), so most 2024 weights are carried.
carry_forward <- function(df, key, years, max_gap) {
  out <- lapply(split(df, df[[key]]), function(g) {
    g <- g[order(g$year), ]
    do.call(rbind, lapply(years, function(y) {
      avail <- g[g$year <= y, ]
      if (nrow(avail) == 0L) return(NULL)
      src <- avail[nrow(avail), ]
      if (y - src$year > max_gap) return(NULL)
      src$source_year <- src$year
      src$year <- y
      src
    }))
  })
  out <- do.call(rbind, out[!vapply(out, is.null, logical(1))])
  rownames(out) <- NULL
  out
}

gbs_t <- carry_forward(gbs, "iso3", TARGET_YEARS, MAX_CARRY_FORWARD)
message("  after carry-forward to ", min(TARGET_YEARS), "-", max(TARGET_YEARS),
        ": ", nrow(gbs_t), " rows, ",
        sum(gbs_t$source_year != gbs_t$year), " carried from an earlier year")

# ---- attach to OECD recipients -------------------------------------------
rows <- merge(
  crosswalk[c("recipient_code", "recipient_name", "iso3",
              "continent", "region", "subregion")],
  gbs_t, by = "iso3", all.x = TRUE
)
rows$purpose_code <- "51010"
rows$source <- ifelse(is.na(rows$weight), NA_character_, "own")

# ---- regional fallback, flagged ------------------------------------------
# A recipient with no source data of its own takes the mean of the weights of
# the recipients in its geographic group that do have data, for the same year.
# Tried narrowest first: subregion, then region, then continent.
#
# An unweighted mean is used deliberately. The recipients needing a fallback
# are small territories and OECD programmes, and a population-weighted mean
# would let the group's largest member stand in for a territory of a few
# thousand people. `source` records which group was used, so a substituted
# weight is never mistaken for an observed one.
fill_from_group <- function(rows, group_col, label) {
  need <- is.na(rows$weight)
  if (!any(need)) return(rows)
  donors <- rows[!is.na(rows$weight), ]
  key <- paste(donors[[group_col]], donors$year)
  grp <- tapply(donors$weight, key, mean, na.rm = TRUE)
  grp_rh <- tapply(donors$rh, key, mean, na.rm = TRUE)
  grp_ch <- tapply(donors$ch, key, mean, na.rm = TRUE)
  want <- paste(rows[[group_col]], rows$year)
  hit <- need & want %in% names(grp)
  rows$weight[hit] <- as.numeric(grp[want[hit]])
  rows$rh[hit] <- as.numeric(grp_rh[want[hit]])
  rows$ch[hit] <- as.numeric(grp_ch[want[hit]])
  rows$mnh[hit] <- 0
  rows$source[hit] <- label
  rows
}

# Recipients with no data of their own have no year rows at all after the
# merge, so the target years are laid out for them first.
missing <- unique(rows$recipient_code[is.na(rows$weight)])
if (length(missing) > 0L) {
  skeleton <- merge(
    crosswalk[crosswalk$recipient_code %in% missing,
              c("recipient_code", "recipient_name", "iso3",
                "continent", "region", "subregion")],
    data.frame(year = TARGET_YEARS), by = NULL
  )
  skeleton$rh <- NA_real_; skeleton$mnh <- NA_real_; skeleton$ch <- NA_real_
  skeleton$weight <- NA_real_; skeleton$source_year <- NA_integer_
  skeleton$purpose_code <- "51010"; skeleton$source <- NA_character_
  rows <- rbind(rows[!is.na(rows$weight), ], skeleton[names(rows)])
}

for (g in list(c("subregion", "regional (subregion)"),
               c("region", "regional (region)"),
               c("continent", "regional (continent)"))) {
  rows <- fill_from_group(rows, g[1], g[2])
}

rmnch_recipient_weights <- tibble::tibble(
  purpose_code   = rows$purpose_code,
  recipient_code = rows$recipient_code,
  recipient_name = rows$recipient_name,
  year           = as.integer(rows$year),
  universe       = factor("rmnch", levels = c("rmnch", "srhr", "fp")),
  rh             = rows$rh,
  mnh            = rows$mnh,
  ch             = rows$ch,
  weight         = rows$weight,
  source         = rows$source,
  source_year    = as.integer(rows$source_year)
)
rmnch_recipient_weights <- rmnch_recipient_weights[
  order(rmnch_recipient_weights$purpose_code,
        rmnch_recipient_weights$recipient_code,
        rmnch_recipient_weights$year),
]

stopifnot(
  !anyDuplicated(rmnch_recipient_weights[c("purpose_code", "recipient_code",
                                           "year")]),
  all(rmnch_recipient_weights$weight >= 0 &
        rmnch_recipient_weights$weight <= 1, na.rm = TRUE),
  # The components must reconstruct the total exactly, or one of them is not
  # being carried through the fallback.
  {
    w <- rmnch_recipient_weights
    ok <- is.na(w$weight) |
      abs((w$rh + w$mnh + w$ch) - w$weight) < 1e-9
    all(ok)
  },
  # Every weight is either observed or explicitly substituted; a weight with no
  # recorded provenance would be untraceable.
  all(is.na(rmnch_recipient_weights$weight) |
        !is.na(rmnch_recipient_weights$source))
)

message(
  "rmnch_recipient_weights: ", nrow(rmnch_recipient_weights), " rows",
  "\n  by source: ",
  paste(names(table(rmnch_recipient_weights$source, useNA = "ifany")),
        table(rmnch_recipient_weights$source, useNA = "ifany"),
        sep = "=", collapse = ", "),
  "\n  unresolved: ", sum(is.na(rmnch_recipient_weights$weight))
)

# ---- NOT YET BUILT: 12262, 12263, 13040 ----------------------------------
#
# The three disease codes need IHME Global Burden of Disease case NUMBERS, and
# GHDx has no unauthenticated API — every /gbd-results/api/ path returns the
# single-page-app HTML shell rather than data, so the extract cannot be
# fetched. It must be downloaded from the GBD Results Tool and placed under
# data-raw/gbd/, after which this script computes:
#
#   12262 malaria, measure = Incidence:
#     RH = 0; MNH = 0.15 (fixed, from the Countdown method);
#     CH = cases under 5, both sexes / cases all ages, both sexes
#   13040 HIV/AIDS, measure = Prevalence:
#     RH = cases in females 15-49 / cases all ages, both sexes; MNH = 0;
#     CH = cases under 5, both sexes / cases all ages, both sexes
#   12263 tuberculosis, measure = Prevalence:
#     RH = 0; MNH = 0;
#     CH = cases under 5, both sexes / cases all ages, both sexes
#
# The exact query is recorded in data-raw/gbd/README.md, including the one
# field the GBD Results Tool asks for first and whose name misleads: the GBD
# Estimate must be "Cause of death or injury", which despite sounding like
# mortality is the cause-level set under which Incidence and Prevalence live
# (IHME GBD Results Tool User Guide, Appendix B). Until the extract exists
# these three codes stay absent from this dataset and remain NA in
# `sector_weights`, so `muskoka(universe = "rmnch")` still refuses rather than
# returning a total missing three large sectors.

usethis::use_data(rmnch_recipient_weights, overwrite = TRUE, compress = "xz")
