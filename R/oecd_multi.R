#' Fetch a provider's core contributions to multilateral agencies
#'
#' Pulls a provider's use of the multilateral system from the OECD table of the
#' same name, restricted to the agencies the Muskoka method weights. The result
#' is what `muskoka()` applies [agency_weights] to, giving the multilateral half
#' of an estimate; [oecd_crs()] gives the bilateral half.
#'
#' @details
#' Only **core** contributions are returned by default. OECD splits this table
#' into core contributions to an agency (`measure = "10"`) and earmarked
#' contributions channelled through it (`"20"`). The Muskoka weights are
#' defined against core contributions, and adding the earmarked ones would
#' double-count spending that CRS already reports bilaterally by purpose code.
#'
#' Agencies are identified by OECD channel code, never by name — see
#' [agency_channels] for why, and for the World Health Organisation's two
#' codes, which are summed.
#'
#' @section Prices:
#' As [oecd_crs()]. `prices = "current"` leaves each year in its own prices;
#' `prices = "constant"` requires an explicit `base` year and deflates with
#' OECD's per-donor deflators. Use the same setting for both fetchers, or the
#' bilateral and multilateral halves of an estimate will not be comparable.
#'
#' @param donor OECD donor code(s), e.g. `"USA"`.
#' @param years Integer vector of years to fetch.
#' @param agencies Agency names as they appear in [agency_weights]. Defaults to
#'   all eleven. Names are validated against [agency_channels]; an unknown name
#'   is an error rather than an empty result.
#' @param prices Either `"constant"` (needs `base`) or `"current"`.
#' @param base Base year for `prices = "constant"`.
#' @param measure OECD measure code. Defaults to `"10"`, core contributions.
#'   Pass `"20"` for earmarked contributions through the agency, but see
#'   Details before combining them.
#' @param flow_type Defaults to `"D"`, disbursements.
#' @param quiet Set `TRUE` to suppress the summary message.
#'
#' @return A tibble of one row per donor, agency and year:
#' \describe{
#'   \item{donor, donor_name}{Provider code and label.}
#'   \item{agency}{Agency name as used by [agency_weights], so the two join
#'     directly.}
#'   \item{year}{Calendar year.}
#'   \item{value}{Core contribution in millions of USD, in the prices given by
#'     the `prices` and `base_year` attributes.}
#'   \item{n_channels}{How many OECD channel codes were summed into this row.
#'     `1` for every agency except the World Health Organisation, which can be
#'     `2` — it is `1` where a donor reported under only one of the WHO's two
#'     core channels in that year.}
#' }
#' with attributes `prices`, `base_year`, `measure` and `fetched_on`.
#'
#' @seealso [oecd_crs()], [agency_channels], [agency_weights].
#'
#' @examplesIf interactive()
#' oecd_multi("USA", years = 2022:2024, prices = "constant", base = 2023)
#'
#' @export
oecd_multi <- function(donor,
                       years,
                       agencies = NULL,
                       prices = c("constant", "current"),
                       base = NULL,
                       measure = "10",
                       flow_type = "D",
                       quiet = FALSE) {
  if (!is.character(donor) || length(donor) == 0L || anyNA(donor)) {
    stop("`donor` must be one or more OECD donor codes, e.g. \"USA\".",
         call. = FALSE)
  }
  years <- suppressWarnings(as.integer(years))
  if (length(years) == 0L || anyNA(years)) {
    stop("`years` must be one or more years, e.g. 2022:2024.", call. = FALSE)
  }
  pb <- check_prices(prices, base)

  map <- rmnchfunding::agency_channels
  if (!is.null(agencies)) {
    unknown <- setdiff(agencies, map$agency)
    if (length(unknown) > 0L) {
      stop("Unknown agency name(s): ", paste(unknown, collapse = ", "),
           ".\n  Names must match agency_weights$agency exactly; see ",
           "agency_channels for the full list.", call. = FALSE)
    }
    map <- map[map$agency %in% agencies, ]
  }

  key <- sdmx_key(
    MULTI_KEY_FIELDS,
    donor = donor,
    # RECIPIENT and SECTOR are hierarchical here exactly as they are in CRS,
    # and leaving them open multiplies every figure. For one donor, one agency
    # and one year OECD returns the same core contribution six times: under
    # RECIPIENT `DPGC` (developing countries, total) and `DPGC_X`
    # (unspecified), crossed with SECTOR `1000`, `998` and `99810` — three
    # nested levels of "unallocated". Summing gives six times the truth.
    #
    # A core contribution is made to the agency, not to a recipient or a
    # sector, so the totals are the only meaningful cell: DPGC and 1000.
    recipient = "DPGC",
    sector = "1000",
    measure = measure,
    channel = map$channel_code,
    flow_type = flow_type,
    price_base = "V",
    md_dim = "_T",
    unit_measure = "USD"
  )

  raw <- oecd_fetch(
    OECD_DCD_HOST, "DSD_MULTI@DF_MULTI", "1.6", key,
    start = min(years), end = max(years)
  )
  if (nrow(raw) == 0L) {
    stop("OECD returned no multilateral records for donor(s) ",
         paste(donor, collapse = ", "), " in ", min(years), "-", max(years),
         ".", call. = FALSE)
  }
  if (length(unique(raw$PRICE_BASE)) > 1L) {
    stop("OECD returned more than one price basis in a single response; ",
         "refusing to combine them.", call. = FALSE)
  }

  rows <- tibble::tibble(
    donor        = raw$DONOR,
    donor_name   = raw$Donor,
    channel_code = raw$CHANNEL,
    year         = as.integer(raw$TIME_PERIOD),
    value        = as.numeric(raw$OBS_VALUE)
  )
  rows <- rows[rows$year %in% years, ]
  rows$agency <- map$agency[match(rows$channel_code, map$channel_code)]

  # One cell per donor-channel-year. More than one means a hierarchical
  # dimension has come open again and the figures would be multiplied, which
  # must not be summed into a silently inflated total.
  dup <- duplicated(rows[c("donor", "channel_code", "year")])
  if (any(dup)) {
    stop("OECD returned ", sum(dup) + length(unique(rows$channel_code)),
         " rows where one per donor-agency-year was expected; a hierarchical ",
         "dimension is open and the values would be multiplied.",
         call. = FALSE)
  }

  # Every returned channel was requested, so an unmatched row means the key and
  # the crosswalk have gone out of step rather than that OECD sent something
  # extra. Fail rather than drop it from a total.
  if (anyNA(rows$agency)) {
    stop("OECD returned channel code(s) that were not requested: ",
         paste(sort(unique(rows$channel_code[is.na(rows$agency)])),
               collapse = ", "), call. = FALSE)
  }

  # Sum the WHO's two core channels into one agency row. Done before deflation
  # so the deflator is applied once per agency-year rather than per channel.
  agg <- stats::aggregate(
    value ~ donor + donor_name + agency + year, data = rows, FUN = sum
  )
  counts <- stats::aggregate(
    channel_code ~ donor + agency + year, data = rows,
    FUN = function(x) length(unique(x))
  )
  names(counts)[names(counts) == "channel_code"] <- "n_channels"
  out <- merge(agg, counts, by = c("donor", "agency", "year"), sort = FALSE)

  if (pb$prices == "constant") {
    out <- deflate_to_base(out, pb$base)
    out$deflator <- NULL
  }

  out <- out[order(out$donor, out$agency, out$year), ]
  out <- tibble::as_tibble(out[c(
    "donor", "donor_name", "agency", "year", "value", "n_channels"
  )])

  attr(out, "prices") <- pb$prices
  attr(out, "base_year") <- pb$base
  attr(out, "measure") <- measure
  attr(out, "fetched_on") <- Sys.Date()

  if (!quiet) {
    missing_agencies <- setdiff(map$agency, out$agency)
    message(
      "oecd_multi(): ", nrow(out), " rows, ",
      length(unique(out$agency)), " of ", length(unique(map$agency)),
      " agencies, ", min(out$year), "-", max(out$year), ".\n",
      "  Measure ", measure,
      if (identical(measure, "10")) " (core contributions)." else ".",
      "\n  ",
      if (pb$prices == "current") {
        paste0("Values are in CURRENT prices: each year in that year's own ",
               "prices (", paste(range(out$year), collapse = "-"), ").")
      } else {
        paste0("Values are in CONSTANT ", pb$base, " prices, deflated with ",
               "OECD per-donor ODA deflators.")
      },
      "\n  Millions of USD.",
      if (length(missing_agencies) > 0L) {
        paste0("\n  No records for: ", paste(missing_agencies, collapse = ", "),
               " (this donor may not contribute to them).")
      }
    )
  }

  out
}
