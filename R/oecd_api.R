# Internals shared by oecd_crs() and oecd_multi(). Nothing here is exported.
#
# ---- the endpoint ---------------------------------------------------------
# CRS and the multilateral-use table are NOT served from the host that serves
# the rest of the OECD's public SDMX data. They live under `dcd-public`, while
# everything else is under `public`. Requesting them from the wrong host does
# not 404 — it returns HTTP 500 "Object reference not set to an instance of an
# object" for every query, key and format, which reads like a broken request
# rather than a wrong address. This constant is the fix; do not "simplify" it
# to match the other host.

# Session cache for the deflator table, keyed by donor set. Not exported and
# not persisted: it exists to stop a loop of constant-price calls refetching
# the same small table and tripping OECD's rate limit.
.defl_cache <- new.env(parent = emptyenv())

OECD_DCD_HOST <- "https://sdmx.oecd.org/dcd-public/rest/data"
OECD_PUBLIC_HOST <- "https://sdmx.oecd.org/public/rest/data"
OECD_AGENCY <- "OECD.DCD.FSD"

# Dimension order of each dataflow's key. SDMX keys are POSITIONAL: a field in
# the wrong slot silently filters on the wrong dimension, and a key of the
# wrong length is rejected with HTTP 422. Both flows are named here so that
# callers pass named values and the position is computed, never counted by
# hand.
CRS_KEY_FIELDS <- c(
  "donor", "recipient", "sector", "measure", "channel", "modality",
  "flow_type", "price_base", "md_dim", "md_id", "unit_measure"
)
MULTI_KEY_FIELDS <- c(
  "donor", "recipient", "sector", "measure", "channel", "flow_type",
  "price_base", "md_dim", "md_id", "unit_measure"
)

#' Build a positional SDMX key
#'
#' @param fields Character vector naming the dataflow's dimensions in order.
#' @param ... Named values, each a character vector. Multiple values for one
#'   dimension are joined with `+`, which is SDMX's OR. Dimensions not named
#'   are left empty, which means "all".
#' @return A single string with `length(fields) - 1` dots.
#' @noRd
sdmx_key <- function(fields, ...) {
  vals <- list(...)
  unknown <- setdiff(names(vals), fields)
  if (length(unknown) > 0L) {
    stop("Not a dimension of this dataflow: ", paste(unknown, collapse = ", "),
         ".\n  Available: ", paste(fields, collapse = ", "), call. = FALSE)
  }
  parts <- vapply(fields, function(f) {
    v <- vals[[f]]
    if (is.null(v) || length(v) == 0L) return("")
    paste(as.character(v), collapse = "+")
  }, character(1))
  key <- paste(parts, collapse = ".")
  # Cheap guard against a future edit to the field vectors desynchronising
  # from the server's expectation. A wrong count is a 422 from OECD; better
  # to fail here, where the message can say what went wrong.
  stopifnot(length(gregexpr(".", key, fixed = TRUE)[[1]]) == length(fields) - 1L)
  key
}

#' Fetch one SDMX-CSV request and return it as a tibble
#'
#' @param host,dataflow,version,key,start,end As per the OECD SDMX REST API.
#' @return A tibble of the labelled CSV response.
#' @noRd
oecd_fetch <- function(host, dataflow, version, key, start = NULL, end = NULL) {
  url <- paste0(host, "/", OECD_AGENCY, ",", dataflow, ",", version, "/", key)

  req <- httr2::request(url)
  req <- httr2::req_url_query(
    req,
    # Labels as well as codes: the codes are what we join on, the labels are
    # what makes a returned frame readable without a second lookup.
    format = "csvfilewithlabels",
    dimensionAtObservation = "AllDimensions",
    startPeriod = start,
    endPeriod = end
  )
  req <- httr2::req_user_agent(
    req, "rmnchfunding (https://github.com/meltemod/rmnchfunding)"
  )
  # OECD rate-limits, and a fetcher that walks several donors or years will hit
  # it. Throttling keeps a loop of calls under the limit rather than relying on
  # retries to dig out afterwards.
  req <- httr2::req_throttle(req, capacity = 20, fill_time_s = 60)
  # Retry transient failures with real backoff. 429 and 503 are worth waiting
  # out; a 422 is a malformed key and will never succeed, so it must not be
  # retried. `after` honours the server's Retry-After when it sends one.
  req <- httr2::req_retry(
    req,
    max_tries = 5L,
    retry_on_failure = TRUE,
    is_transient = function(resp) {
      httr2::resp_status(resp) %in% c(408L, 425L, 429L, 500L, 502L, 503L, 504L)
    },
    after = function(resp) {
      ra <- suppressWarnings(
        as.numeric(httr2::resp_header(resp, "Retry-After"))
      )
      # OECD sends `Retry-After: 0` with its 429s. Taken literally that means
      # retry immediately, which just trips the limit again and burns all the
      # tries in a few seconds. A zero or missing value returns NA, which is
      # how httr2 is told to fall back to its own exponential backoff — NULL
      # is rejected by req_retry().
      if (!is.na(ra) && ra > 0) min(ra, 120) else NA_real_
    }
  )
  req <- httr2::req_timeout(req, 300)
  # OECD answers an empty result with HTTP 404 and the body "NoRecordsFound".
  # That is a legitimate outcome — a donor may simply have funded nothing in
  # the requested sectors and years — not a failure, so 404 is allowed through
  # for the body check below to interpret. Any other 4xx/5xx still raises.
  req <- httr2::req_error(
    req, is_error = function(resp) {
      s <- httr2::resp_status(resp)
      s >= 400L && s != 404L
    }
  )

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_string(resp)

  if (!startsWith(body, "STRUCTURE")) {
    if (grepl("NoRecordsFound", body, fixed = TRUE)) {
      return(tibble::tibble())
    }
    stop("Unexpected response from OECD (HTTP ", httr2::resp_status(resp),
         "):\n  ", substr(body, 1L, 300L), call. = FALSE)
  }

  readr::read_csv(
    I(body),
    col_types = readr::cols(.default = readr::col_character()),
    # OECD's labelled CSV repeats some column names (policy-marker columns
    # share headers). The repair is fine — nothing here reads those columns —
    # but its message is noise on every call.
    name_repair = "unique_quiet",
    progress = FALSE
  )
}

#' Fetch OECD ODA deflators for a set of donors and a base year
#'
#' Deflators are per DONOR, not per recipient, and they differ a great deal
#' between donors — for 2022 rebased to 2023 they span roughly 83 to 124. Using
#' a DAC-wide average would therefore misstate individual donors by several
#' per cent, so the join is always on donor.
#'
#' @param donors Character vector of OECD donor codes.
#' @param base Base year as a length-one integer or character.
#' @return A tibble of `donor`, `year`, `deflator`.
#' @noRd
oecd_deflators <- function(donors, base) {
  # Cached for the session. The deflator table is small and every constant-price
  # call needs it, so a loop over donors or years would otherwise refetch the
  # same few hundred rows repeatedly and burn the rate limit.
  ck <- paste(sort(unique(donors)), collapse = "+")
  if (!is.null(.defl_cache[[ck]])) {
    raw <- .defl_cache[[ck]]
  } else {
    # This flow is on the ordinary public host, unlike CRS and MULTI.
    raw <- oecd_fetch(
      OECD_PUBLIC_HOST, "DSD_GDFF@DF_DEFL", "1.0",
      key = paste(c(ck, "", "", "", ""), collapse = ".")
    )
    .defl_cache[[ck]] <- raw
  }
  if (nrow(raw) == 0L) {
    stop("OECD returned no deflators for donor(s) ",
         paste(donors, collapse = ", "), ".", call. = FALSE)
  }
  out <- raw[raw$DEFL_BASE == as.character(base), ]
  if (nrow(out) == 0L) {
    stop("OECD publishes no deflators with base year ", base, ".\n",
         "  Available bases: ",
         paste(sort(unique(raw$DEFL_BASE)), collapse = ", "), call. = FALSE)
  }
  tibble::tibble(
    donor = out$DONOR,
    year = as.integer(out$TIME_PERIOD),
    deflator = as.numeric(out$OBS_VALUE)
  )
}

#' Convert current-price values to constant prices of a given base year
#'
#' `constant(year, base) = current(year) * 100 / deflator(donor, year, base)`
#'
#' Verified against OECD's own constant-price series: for the United States,
#' code 13020, 2022, current 15.136917 deflated by 94.096006 gives 16.086673
#' against OECD's published 16.086674.
#'
#' @param x A tibble with `donor`, `year` and `value` columns.
#' @param base Base year.
#' @return `x` with `value` converted, and a `deflator` column added.
#' @noRd
deflate_to_base <- function(x, base) {
  defl <- oecd_deflators(unique(x$donor), base)
  out <- merge(x, defl, by = c("donor", "year"), all.x = TRUE, sort = FALSE)

  # A missing deflator must not silently pass through as an undeflated value.
  # OECD stops extending older bases, so a base that exists for one year may
  # be absent for another: base 2022 covers 2021 onwards but base 2020 does
  # not reach 2022.
  gaps <- unique(out[is.na(out$deflator), c("donor", "year")])
  if (nrow(gaps) > 0L) {
    stop(
      "No deflator with base ", base, " for:\n",
      paste0("  ", gaps$donor, " ", gaps$year, collapse = "\n"),
      "\n  OECD does not extend older bases to all years; try a later base.",
      call. = FALSE
    )
  }

  out$value <- out$value * 100 / out$deflator
  tibble::as_tibble(out)
}

#' The CRS purpose codes the Muskoka method uses
#'
#' Taken from [sector_weights] rather than repeated, so the fetchers and the
#' weights cannot drift apart.
#'
#' @noRd
muskoka_purpose_codes <- function() {
  sort(unique(as.character(rmnchfunding::sector_weights$purpose_code)))
}

#' Validate the prices/base argument pair shared by both fetchers
#'
#' @return A list of `prices` and `base`, `base` being `NULL` for current.
#' @noRd
check_prices <- function(prices, base) {
  prices <- match.arg(prices, c("constant", "current"))

  if (prices == "current") {
    if (!is.null(base)) {
      stop("`base` applies only to `prices = \"constant\"`.\n",
           "  Current prices express each year in that year's own prices, so ",
           "there is no base year.", call. = FALSE)
    }
    return(list(prices = prices, base = NULL))
  }

  if (is.null(base)) {
    stop("`prices = \"constant\"` needs a `base` year, e.g. base = 2023.\n",
         "  OECD rebases its own constant series with each release, so the ",
         "base is stated explicitly here rather than inherited.",
         call. = FALSE)
  }
  base <- suppressWarnings(as.integer(base))
  if (length(base) != 1L || is.na(base)) {
    stop("`base` must be a single year, e.g. base = 2023.", call. = FALSE)
  }
  list(prices = prices, base = base)
}

# Zero-row results with the full column schema, so that a donor with no data
# flows through the same downstream code as one with data. Defined here rather
# than inline so the two fetchers cannot drift from their own documented
# return shapes.

#' @noRd
empty_crs <- function(pb) {
  out <- tibble::tibble(
    donor = character(0), donor_name = character(0),
    recipient = character(0), recipient_name = character(0),
    purpose_code = character(0), purpose_name = character(0),
    year = integer(0), value = numeric(0),
    is_aggregate = logical(0), is_unallocated = logical(0)
  )
  attr(out, "prices") <- pb$prices
  attr(out, "base_year") <- pb$base
  attr(out, "fetched_on") <- Sys.Date()
  out
}

#' @noRd
empty_multi <- function(pb, measure) {
  out <- tibble::tibble(
    donor = character(0), donor_name = character(0), agency = character(0),
    year = integer(0), value = numeric(0), n_channels = integer(0)
  )
  attr(out, "prices") <- pb$prices
  attr(out, "base_year") <- pb$base
  attr(out, "measure") <- measure
  attr(out, "fetched_on") <- Sys.Date()
  out
}
