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
# 290120v2.xlsb (v1.4, 24 March 2020), doi:10.17037/DATA.00001526, CC BY-NC 3.0,
# accessed 2026-07-30. Not redistributed here; see data-raw/reference/README.md.
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

# Percentages to proportions, once, here. Count indicators are excluded:
# dividing a population by 100 would silently reweight every regional average.
for (nm in setdiff(names(WB_INDICATORS), WB_COUNT_INDICATORS)) {
  wide[[nm]] <- wide[[nm]] / 100
}

wide$wra <- rowSums(wide[WB_WRA_BANDS], na.rm = FALSE)

gbs <- data.frame(
  iso3 = wide$iso3,
  year = wide$year,
  # The denominator this weight is an average OVER, used only when a recipient
  # with no data borrows its region's figure. For general budget support the
  # components are population shares scaled by a spending ratio, so the
  # quantity being averaged is per-person and population is the right weight.
  denom = wide$pop_total,
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


# ---- disease codes 12262, 12263, 13040 ------------------------------------
#
# From IHME Global Burden of Disease case NUMBERS, by location, age, sex and
# year. The extract is not fetchable — GHDx has no unauthenticated API and the
# tool's data endpoint sits behind a Cloudflare challenge — so it is downloaded
# by hand and committed under data-raw/gbd/. See that directory's README for
# the exact query.
#
#   12262 malaria, Incidence:      RH = 0;   MNH = 0.15;  CH = <5 / all ages
#   13040 STD incl. HIV/AIDS, Prevalence:
#                                  RH = female 15-49 / all ages; MNH = 0;
#                                  CH = <5 / all ages
#   12263 tuberculosis, Prevalence: RH = 0;  MNH = 0;     CH = <5 / all ages
#
# ---- the GBD cause for 13040 ---------------------------------------------
#
# CRS 13040 is "STD control INCLUDING HIV/AIDS", so the matching GBD cause is
# the combined "HIV/AIDS and sexually transmitted infections", NOT "HIV/AIDS"
# alone. This was got wrong at first and the difference is large, because STI
# cases outnumber HIV cases by orders of magnitude and have a completely
# different demography.
#
# Afghanistan 2017, prevalence, against the published reference of
# RH 0.5409 / CH 0.000033:
#
#   HIV/AIDS alone      RH 0.2548   CH 0.0182    total 0.2729
#   HIV/AIDS + STIs     RH 0.5911   CH 0.0015    total 0.5926
#
# Both components identify the error. HIV alone halves RH, because HIV is not
# as concentrated in women 15-49 as STIs are; and it inflates CH roughly
# tenfold, because paediatric HIV from mother-to-child transmission is real
# whereas under-5 STI cases are almost nil.
#
# The distributions confirm it across all recipients and years: the reference
# RH is tight and high (IQR 0.098, floor 0.31), which is what an STI-dominated
# ratio looks like, while HIV alone swings from 0.04 to 0.58 with the shape of
# each country's epidemic.
#
# All ratios use "Both" sexes except the HIV RH numerator, which is female.
# MNH = 0.15 for malaria is a fixed constant from the Countdown method, not
# derived from the data.

MALARIA_MNH <- 0.15

gbd_files <- list.files("data-raw/gbd", pattern = "[.]zip$", full.names = TRUE)
gbd_csv <- list.files("data-raw/gbd", pattern = "[.]csv$", full.names = TRUE)

read_gbd <- function() {
  parts <- list()
  for (z in gbd_files) {
    inner <- utils::unzip(z, list = TRUE)$Name
    inner <- inner[grepl("[.]csv$", inner)]
    for (f in inner) {
      con <- unz(z, f)
      parts[[length(parts) + 1L]] <- utils::read.csv(con, stringsAsFactors = FALSE)
    }
  }
  for (f in gbd_csv) {
    parts[[length(parts) + 1L]] <- utils::read.csv(f, stringsAsFactors = FALSE)
  }
  if (length(parts) == 0L) return(NULL)
  out <- do.call(rbind, parts)
  message("  read ", length(parts), " GBD file(s)")

  # Overlapping downloads must fail rather than double-count. The extract has
  # to be split across files whenever it exceeds GBD's 100,000-row download
  # cap — 2002-2023 is about 162,000 rows — and it is easy to request
  # overlapping year ranges by accident. Every ratio would still be computed
  # from correctly paired numerator and denominator, so nothing would look
  # wrong; only the row counts would lie.
  keycols <- intersect(
    c("measure_name", "location_name", "sex_name", "age_name", "cause_name",
      "metric_name", "year"),
    names(out)
  )
  dup <- duplicated(out[keycols])
  if (any(dup)) {
    d <- out[dup, keycols, drop = FALSE]
    stop(
      sum(dup), " duplicated observation(s) across the GBD files in ",
      "data-raw/gbd/, e.g. ",
      paste(utils::head(apply(d, 1L, paste, collapse = " / "), 3L),
            collapse = "; "),
      ".\n  The files overlap. Remove the redundant download, or request ",
      "non-overlapping year ranges: the 100,000-row cap means 2002-2023 has ",
      "to be split, and it is easy to repeat a year by accident.",
      call. = FALSE
    )
  }

  # GBD has renamed these between rounds. Fail with what was actually found
  # rather than computing from whatever column happens to be there.
  need <- c("measure_name", "location_name", "sex_name", "age_name",
            "cause_name", "metric_name", "year", "val")
  missing <- setdiff(need, names(out))
  if (length(missing) > 0L) {
    stop("GBD extract is missing column(s): ", paste(missing, collapse = ", "),
         ".\n  Found: ", paste(names(out), collapse = ", "),
         "\n  See data-raw/gbd/README.md for the expected shape.",
         call. = FALSE)
  }
  out[out$metric_name == "Number", need]
}

gbd <- read_gbd()

# GBD keys by location NAME, and `recipient_crosswalk` carries the resolved
# spelling for each recipient. Identity mapping lives there and only there, so
# a GBD rename is fixed in one place rather than two.
gbd_code_of <- stats::setNames(crosswalk$recipient_code,
                               crosswalk$gbd_location_name)
gbd_code_of <- gbd_code_of[!is.na(names(gbd_code_of))]

disease_weights <- NULL
if (is.null(gbd)) {
  message("No GBD extract in data-raw/gbd/; codes 12262, 12263 and 13040 ",
          "will be absent. See data-raw/gbd/README.md.")
} else {
  message("Read GBD extract: ", nrow(gbd), " rows, years ",
          min(gbd$year), "-", max(gbd$year), ", ",
          length(unique(gbd$location_name)), " locations")

  # One cell per (location, year, cause, measure, sex, age).
  key <- function(cause, measure, sex, age) {
    d <- gbd[gbd$cause_name == cause & gbd$measure_name == measure &
               gbd$sex_name == sex & gbd$age_name == age, ]
    stats::setNames(d$val, paste(d$location_name, d$year))
  }
  zero_burden <- 0L
  ratio <- function(num, den) {
    common <- intersect(names(num), names(den))
    n <- num[common]; d <- den[common]
    # A zero denominator means the disease is ABSENT from that location-year:
    # GBD reports zero malaria incidence for 118 of its 204 locations in 2023,
    # malaria having been eliminated across most of the world. Zero cases means
    # zero child cases, so the child share is 0 and the weight reduces to the
    # fixed MNH constant. This is not the same as missing data and must not be
    # sent to the regional fallback — substituting a malarious neighbour's
    # child share into a malaria-free country would invent burden that is not
    # there. All of Europe is malaria-free, so a regional fallback could not
    # help those countries anyway.
    #
    # A zero denominator with a NON-zero numerator is impossible (a subset
    # cannot exceed its whole) and is left NA so that it surfaces rather than
    # being quietly treated as absence.
    out <- ifelse(d > 0, n / d, ifelse(n == 0, 0, NA_real_))
    zero_burden <<- zero_burden + sum(d == 0 & n == 0)
    stats::setNames(out, common)
  }

  # See the note above: 13040 needs the combined cause, not HIV alone.
  STD_CAUSE <- "HIV/AIDS and sexually transmitted infections"
  if (!STD_CAUSE %in% gbd$cause_name) {
    stop(
      "The GBD extract has no cause \"", STD_CAUSE, "\".\n",
      "  CRS 13040 is \"STD control including HIV/AIDS\", so it needs the ",
      "combined GBD cause, not \"HIV/AIDS\" alone.\n",
      "  Causes present: ", paste(sort(unique(gbd$cause_name)), collapse = ", "),
      "\n  Re-download with that cause selected; see data-raw/gbd/README.md.",
      call. = FALSE
    )
  }

  mal_den <- key("Malaria", "Incidence", "Both", "All ages")
  hiv_den <- key(STD_CAUSE, "Prevalence", "Both", "All ages")
  tb_den  <- key("Tuberculosis", "Prevalence", "Both", "All ages")

  mal_ch <- ratio(key("Malaria", "Incidence", "Both", "<5 years"), mal_den)
  hiv_ch <- ratio(key(STD_CAUSE, "Prevalence", "Both", "<5 years"), hiv_den)
  hiv_rh <- ratio(key(STD_CAUSE, "Prevalence", "Female", "15-49 years"),
                  hiv_den)
  tb_ch  <- ratio(key("Tuberculosis", "Prevalence", "Both", "<5 years"), tb_den)

  # The denominator each ratio was taken over. Carried through because the
  # regional fallback is a weighted mean, and a ratio of summed cases IS a
  # mean of country ratios weighted by their denominators:
  #
  #   sum(u5) / sum(all) == sum(all * CH) / sum(all)
  #
  # So weighting by all-age cases reproduces exactly what a regional aggregate
  # of the source data would give, while an unweighted mean would let a country
  # with almost no burden count as much as one carrying most of it.
  as_rows <- function(code, rh, mnh, ch, den) {
    ids <- names(ch)
    loc <- sub(" [0-9]{4}$", "", ids)
    yr <- as.integer(sub("^.* ", "", ids))
    data.frame(
      purpose_code = code,
      location_name = loc,
      year = yr,
      rh = if (length(rh) == 1L) rep(rh, length(ids)) else unname(rh[ids]),
      mnh = mnh,
      ch = unname(ch),
      denom = unname(den[ids]),
      stringsAsFactors = FALSE
    )
  }
  disease_weights <- rbind(
    as_rows("12262", 0, MALARIA_MNH, mal_ch, mal_den),
    as_rows("13040", hiv_rh, 0, hiv_ch, hiv_den),
    as_rows("12263", 0, 0, tb_ch, tb_den)
  )
  disease_weights$weight <-
    disease_weights$rh + disease_weights$mnh + disease_weights$ch

  # Map GBD location names onto OECD recipient codes, via the crosswalk.
  disease_weights$recipient_code <-
    unname(gbd_code_of[disease_weights$location_name])

  # Locations with no OECD recipient are dropped deliberately: GBD covers 204
  # countries including donors and high-income territories that are not ODA
  # recipients at all.
  dropped <- sort(unique(
    disease_weights$location_name[is.na(disease_weights$recipient_code)]
  ))
  disease_weights <- disease_weights[!is.na(disease_weights$recipient_code), ]
  message("  mapped ", length(unique(disease_weights$recipient_code)),
          " GBD locations to OECD recipients; dropped ", length(dropped),
          " that are not ODA recipients",
          "\n  zero-burden location-years (disease absent, child share 0): ",
          zero_burden)

  stopifnot(
    all(disease_weights$weight >= 0 & disease_weights$weight <= 1,
        na.rm = TRUE),
    # The fixed pieces of the method, asserted rather than assumed.
    all(disease_weights$mnh[disease_weights$purpose_code == "12262"] ==
          MALARIA_MNH),
    all(disease_weights$rh[disease_weights$purpose_code == "12262"] == 0),
    all(disease_weights$mnh[disease_weights$purpose_code == "13040"] == 0),
    all(disease_weights$rh[disease_weights$purpose_code == "12263"] == 0),
    all(disease_weights$mnh[disease_weights$purpose_code == "12263"] == 0)
  )
}

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

# The disease codes arrive keyed by recipient_code rather than iso3, and are
# carried forward and attached the same way, so that every code goes through
# one path and cannot diverge in how a gap is treated.
if (!is.null(disease_weights)) {
  dz <- disease_weights[!is.na(disease_weights$weight), ]
  dz$grp <- paste(dz$purpose_code, dz$recipient_code)
  dz_t <- carry_forward(dz, "grp", TARGET_YEARS, MAX_CARRY_FORWARD)
  dz_t$grp <- NULL
  dz_t$location_name <- NULL
  message("  disease codes after carry-forward: ", nrow(dz_t), " rows, ",
          sum(dz_t$source_year != dz_t$year), " carried from an earlier year")
  dz_t <- merge(
    crosswalk[c("recipient_code", "recipient_name", "iso3",
                "continent", "region", "subregion")],
    dz_t, by = "recipient_code"
  )
  rows <- rbind(rows[names(dz_t)], dz_t)
}
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
  # Average all THREE components, not two. MNH is zero for general budget
  # support and for tuberculosis, but a fixed 0.15 for malaria, so assuming
  # zero here would leave a substituted malaria row whose components no longer
  # sum to its total. Averaging is linear, so the summed means equal the mean
  # total exactly and the identity rh + mnh + ch == weight survives.
  #
  # BURDEN-WEIGHTED, by the denominator each ratio was taken over. This makes
  # the substituted value equal the ratio of summed cases across the group,
  # which is the quantity a regional aggregate of the source data reports and
  # what the published method's regional rows appear to contain. An unweighted
  # mean would let a country with almost no malaria pull the regional child
  # share as hard as one carrying tens of millions of cases.
  wmean <- function(x, w) {
    ok <- is.finite(x) & is.finite(w) & w > 0
    if (any(ok)) return(sum(x[ok] * w[ok]) / sum(w[ok]))
    # Every weight in the group is zero, which for a disease code means the
    # disease is absent from the whole group. Weighting by zero burden is
    # undefined, but the answer is not: no cases anywhere means a zero child
    # share, and a fixed component keeps its constant. Europe is entirely
    # malaria-free, so this is how Gibraltar and Kosovo get a malaria weight
    # at all. Falls back to the unweighted mean, which for a zero-burden group
    # is 0 for the derived components and the constant for MNH.
    flat <- is.finite(x)
    if (any(flat)) return(mean(x[flat]))
    NA_real_
  }
  grp_rh <- tapply(seq_len(nrow(donors)), key,
                   function(i) wmean(donors$rh[i], donors$denom[i]))
  grp_mnh <- tapply(seq_len(nrow(donors)), key,
                    function(i) wmean(donors$mnh[i], donors$denom[i]))
  grp_ch <- tapply(seq_len(nrow(donors)), key,
                   function(i) wmean(donors$ch[i], donors$denom[i]))
  want <- paste(rows[[group_col]], rows$year)
  hit <- need & want %in% names(grp_rh)
  rows$rh[hit] <- as.numeric(grp_rh[want[hit]])
  rows$mnh[hit] <- as.numeric(grp_mnh[want[hit]])
  rows$ch[hit] <- as.numeric(grp_ch[want[hit]])
  rows$weight[hit] <- rows$rh[hit] + rows$mnh[hit] + rows$ch[hit]
  rows$source[hit] <- label
  rows
}

# Every purpose code must cover every recipient and every target year, so the
# full grid is laid out first and the gaps filled from geography. Done per
# code, since a recipient may have data for one code and not another — a
# country with no malaria burden still has government health expenditure.
rows <- rows[!is.na(rows$weight), ]
codes_present <- unique(rows$purpose_code)
full <- do.call(rbind, lapply(codes_present, function(pc) {
  have <- rows[rows$purpose_code == pc, ]
  grid <- merge(
    crosswalk[c("recipient_code", "recipient_name", "iso3",
                "continent", "region", "subregion")],
    data.frame(year = TARGET_YEARS), by = NULL
  )
  grid$purpose_code <- pc
  gap <- !paste(grid$recipient_code, grid$year) %in%
    paste(have$recipient_code, have$year)
  skeleton <- grid[gap, ]
  if (nrow(skeleton) == 0L) return(have)
  skeleton$rh <- NA_real_; skeleton$mnh <- NA_real_; skeleton$ch <- NA_real_
  # `denom` must be present, not merely absent-and-ignored: the skeleton is
  # rbind-ed to the rows that have data, and a missing column here silently
  # drops the denominators from the whole frame, leaving the weighted fallback
  # with nothing to weight by and every substituted weight NA.
  skeleton$denom <- NA_real_
  skeleton$weight <- NA_real_; skeleton$source_year <- NA_integer_
  skeleton$source <- NA_character_
  out <- rbind(have[names(skeleton)], skeleton)
  for (g in list(c("subregion", "regional (subregion)"),
                 c("region", "regional (region)"),
                 c("continent", "regional (continent)"))) {
    out <- fill_from_group(out, g[1], g[2])
  }
  out
}))
rows <- full

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

# ---- provenance of the disease extract ------------------------------------
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
