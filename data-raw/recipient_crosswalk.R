# Builds `recipient_crosswalk`: OECD CRS recipient codes joined to World Bank
# ISO3 codes, with each recipient's geographic ancestors.
#
#   Rscript data-raw/recipient_crosswalk.R
#
## Sources: OECD codes and hierarchy from `crs_recipients` and
## `crs_recipient_tree`; World Bank economy list from the World Bank API v2,
## https://api.worldbank.org/v2/country

# ---- what this is for ----------------------------------------------------
#
# The recipient-and-year RMNCH weights for CRS codes 12262, 12263, 13040 and
# 51010 are computed from World Bank and IHME data, which key by ISO3 and by
# GBD location name respectively, while CRS disbursements key by OECD recipient
# code. Nothing joins without a crosswalk, and a silent mismatch would drop a
# recipient's weight without dropping its disbursements.
#
# The geographic ancestor columns are here for the same table because the
# fallback for a recipient with no source data is its region's weight, which
# needs to know what its region is. A recipient has SEVERAL parents in OECD's
# hierarchy — income groups, fragility groupings and so on — so the geographic
# line has to be picked out deliberately rather than read off a parent column.

# Loaded from data/ rather than the namespace: data-raw scripts build the
# package's data and must run before the package is installed.
tree <- local({ e <- new.env(); load("data/crs_recipient_tree.rda", e)
                get("crs_recipient_tree", e) })
recips <- local({ e <- new.env(); load("data/crs_recipients.rda", e)
                  get("crs_recipients", e) })

# ---- the recipient universe ----------------------------------------------
# Leaves under DPGC. This deliberately excludes:
#   * aggregates, which are sums of other rows;
#   * the `_X` unallocated buckets, which are not places and have no
#     population or disease burden to compute a weight from;
#   * the multilateral organisations that also live in CL_AREA_ORG (IFAD,
#     UNDP, IDA and so on) — they are in the codelist because it covers areas
#     AND organisations, and they are not recipients in this sense.
descendants <- function(root) {
  cur <- root
  out <- character(0)
  repeat {
    ch <- tree$child_code[tree$parent_code %in% cur]
    new <- setdiff(ch, out)
    if (length(new) == 0L) break
    out <- c(out, new)
    cur <- new
  }
  out
}
under_dpgc <- descendants("DPGC")
leaves <- setdiff(under_dpgc, tree$parent_code)
universe <- recips[recips$recipient_code %in% leaves & !recips$is_unallocated, ]

# ---- geographic ancestors -------------------------------------------------
# The frontier of DPGC's subtree at each depth, as `crs_classify()` computes
# it: descend one step, and a branch that has already ended stands in for
# itself. Mapping a leaf to the frontier member that contains it gives its
# continent, region and subregion.
frontier <- function(level) {
  cur <- "DPGC"
  for (i in seq_len(level)) {
    nxt <- character(0)
    for (cd in cur) {
      ch <- tree$child_code[tree$parent_code == cd]
      nxt <- c(nxt, if (length(ch) == 0L) cd else ch)
    }
    cur <- unique(nxt)
  }
  cur
}
ancestor_at <- function(codes, level) {
  members <- frontier(level)
  # A frontier member covers itself and everything beneath it.
  cover <- lapply(members, function(m) c(m, descendants(m)))
  names(cover) <- members
  vapply(codes, function(cd) {
    hit <- members[vapply(cover, function(z) cd %in% z, logical(1))]
    # A leaf sits under exactly one member of a geographic frontier, since the
    # geographic tree does not overlap itself. More than one would mean the
    # frontier is not a partition after all.
    if (length(hit) != 1L) NA_character_ else hit
  }, character(1))
}

universe$continent <- ancestor_at(universe$recipient_code, 1L)
universe$region    <- ancestor_at(universe$recipient_code, 2L)
universe$subregion <- ancestor_at(universe$recipient_code, 3L)

# ---- World Bank economies -------------------------------------------------
message("Fetching the World Bank economy list ...")
resp <- httr2::req_perform(httr2::req_url_query(
  httr2::request("https://api.worldbank.org/v2/country"),
  format = "json", per_page = 400
))
wb_raw <- jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE)[[2]]
wb <- data.frame(
  iso3 = vapply(wb_raw, function(x) x$id, character(1)),
  wb_name = vapply(wb_raw, function(x) x$name, character(1)),
  region_id = vapply(wb_raw, function(x) x$region$id, character(1)),
  stringsAsFactors = FALSE
)
# region_id "NA" marks World Bank AGGREGATES (income groups, world totals),
# not North America. Dropping them leaves actual economies.
wb <- wb[wb$region_id != "NA", ]

# ---- the join, and its exceptions ----------------------------------------
# OECD's alphabetic recipient codes are ISO3 for almost every country, so the
# join is on the code itself. The exceptions are enumerated rather than
# pattern-matched, so that a new mismatch appearing in a future OECD codelist
# fails the check below instead of being absorbed silently.
manual_iso3 <- c(
  # OECD uses XKV for Kosovo, the World Bank uses XKX. A real economy on both
  # sides, differing only in code.
  XKV = "XKX"
)

# Recipients the World Bank has no economy record for at all. Each is either a
# small territory outside the World Bank's country list or an OECD programme
# that is not a country. They get no World Bank data, and therefore fall back
# to their region's weight; recorded here so that "no data" is a documented
# status rather than an unexplained gap.
no_wb_data <- c(
  AIA   = "small territory, not a World Bank economy",
  COK   = "small territory, not a World Bank economy",
  MSR   = "small territory, not a World Bank economy",
  MYT   = "small territory, not a World Bank economy",
  NIU   = "small territory, not a World Bank economy",
  SHN   = "small territory, not a World Bank economy",
  TKL   = "small territory, not a World Bank economy",
  WLF   = "small territory, not a World Bank economy",
  EAC   = "OECD programme, not a country",
  INDUS = "OECD programme, not a country",
  MKNG  = "OECD programme, not a country",
  TWN   = "not in the World Bank economy list"
)

universe$iso3 <- ifelse(
  universe$recipient_code %in% names(manual_iso3),
  manual_iso3[universe$recipient_code],
  universe$recipient_code
)
universe$iso3[!universe$iso3 %in% wb$iso3] <- NA_character_
universe$wb_name <- wb$wb_name[match(universe$iso3, wb$iso3)]
universe$no_data_reason <- unname(no_wb_data[universe$recipient_code])

# ---- GBD location names ---------------------------------------------------
# The third identity system. GBD keys by location NAME, so it needs its own
# column rather than being matched at use time — a name join done inside the
# weights script would put half the identity mapping there and half here, and
# a spelling change would fail in a different place from the one that
# documents it.
#
# Most GBD names match an OECD or World Bank name outright. These do not, and
# are enumerated rather than fuzzy-matched.
#
# Cote d'Ivoire is the sharpest case: three sources, three spellings.
#   OECD        Cote d\u2019Ivoire   circumflex, curly apostrophe
#   World Bank  Cote d\u0027Ivoire   no circumflex, ASCII apostrophe
#   GBD         C\u00f4te d\u0027Ivoire   circumflex, ASCII apostrophe
# None of the three is reachable from another by a plain string match, which
# is why the GBD spelling is written here as an escape rather than pasted:
# pasting it invites an editor or locale to normalise it back to something
# that no longer matches.
gbd_name_to_code <- c(
  "Bolivia (Plurinational State of)"      = "BOL",
  "C\u00f4te d'Ivoire"                     = "CIV",
  "Democratic People's Republic of Korea" = "PRK",
  "Iran (Islamic Republic of)"            = "IRN",
  "Lao People's Democratic Republic"      = "LAO",
  "Micronesia (Federated States of)"      = "FSM",
  "Palestine"                             = "PSE",
  "Republic of Korea"                     = "KOR",
  "Republic of Moldova"                   = "MDA",
  "Taiwan"                                = "TWN",
  "United Republic of Tanzania"           = "TZA",
  "Venezuela (Bolivarian Republic of)"    = "VEN"
)

gbd_names <- character(0)
gbd_files <- list.files("data-raw/gbd", pattern = "[.]zip$", full.names = TRUE)
if (length(gbd_files) > 0L) {
  for (z in gbd_files) {
    inner <- utils::unzip(z, list = TRUE)$Name
    for (f in inner[grepl("[.]csv$", inner)]) {
      d <- utils::read.csv(unz(z, f), stringsAsFactors = FALSE)
      gbd_names <- union(gbd_names, d$location_name)
    }
  }
}
# Resolve each recipient to the GBD spelling: try its own name, then the World
# Bank name, then the explicit variants.
resolve_gbd <- function(code, oecd, wb) {
  if (!is.na(oecd) && oecd %in% gbd_names) return(oecd)
  if (!is.na(wb) && wb %in% gbd_names) return(wb)
  hit <- names(gbd_name_to_code)[gbd_name_to_code == code]
  hit <- hit[hit %in% gbd_names]
  if (length(hit) > 0L) return(hit[1])
  NA_character_
}
universe$gbd_location_name <- mapply(
  resolve_gbd, universe$recipient_code, universe$recipient_name,
  universe$wb_name, USE.NAMES = FALSE
)

# Readable geography, so the exported crosswalk is legible without a second
# lookup: the hierarchy codes alone (F6, A5, S4_S7) mean nothing to a reader.
nm <- stats::setNames(recips$recipient_name, recips$recipient_code)
universe$continent_name <- unname(nm[universe$continent])
universe$region_name    <- unname(nm[universe$region])
universe$subregion_name <- unname(nm[universe$subregion])

recipient_crosswalk <- tibble::tibble(
  recipient_code    = universe$recipient_code,
  recipient_name    = universe$recipient_name,
  iso3              = universe$iso3,
  wb_name           = universe$wb_name,
  gbd_location_name = universe$gbd_location_name,
  continent         = universe$continent,
  continent_name    = universe$continent_name,
  region            = universe$region,
  region_name       = universe$region_name,
  subregion         = universe$subregion,
  subregion_name    = universe$subregion_name,
  no_data_reason    = universe$no_data_reason
)
recipient_crosswalk <- recipient_crosswalk[
  order(recipient_crosswalk$recipient_code),
]

# ---- fail loudly on anything unaccounted for ------------------------------
unmatched <- recipient_crosswalk$recipient_code[
  is.na(recipient_crosswalk$iso3) & is.na(recipient_crosswalk$no_data_reason)
]
if (length(unmatched) > 0L) {
  stop(
    "Recipient(s) with no World Bank match and no recorded reason: ",
    paste(unmatched, collapse = ", "),
    ".\n  Add each to `manual_iso3` (if the codes merely differ) or to ",
    "`no_wb_data` (if the World Bank genuinely has no record), so that every ",
    "gap in the weights is a documented decision rather than an accident.",
    call. = FALSE
  )
}

stopifnot(
  !anyDuplicated(recipient_crosswalk$recipient_code),
  nrow(recipient_crosswalk) > 150L,
  # Every recipient must have a geographic line, or the regional fallback has
  # nothing to fall back to.
  !anyNA(recipient_crosswalk$continent),
  !anyNA(recipient_crosswalk$region),
  !anyNA(recipient_crosswalk$subregion),
  # Anchors, including the one code whose OECD and World Bank spellings differ.
  recipient_crosswalk$iso3[recipient_crosswalk$recipient_code == "KEN"] == "KEN",
  recipient_crosswalk$iso3[recipient_crosswalk$recipient_code == "XKV"] == "XKX",
  is.na(recipient_crosswalk$iso3[recipient_crosswalk$recipient_code == "TWN"]),
  # No recipient may be both matched and marked as having no data.
  !any(!is.na(recipient_crosswalk$iso3) &
         !is.na(recipient_crosswalk$no_data_reason))
)

message(
  "recipient_crosswalk: ", nrow(recipient_crosswalk), " recipients, ",
  sum(!is.na(recipient_crosswalk$iso3)), " matched to World Bank ISO3, ",
  sum(is.na(recipient_crosswalk$iso3)), " without World Bank data",
  "\n  continents: ", length(unique(recipient_crosswalk$continent)),
  ", regions: ", length(unique(recipient_crosswalk$region)),
  ", subregions: ", length(unique(recipient_crosswalk$subregion)),
  "\n  retrieved: ", as.character(Sys.Date())
)

usethis::use_data(recipient_crosswalk, overwrite = TRUE, compress = "xz")
