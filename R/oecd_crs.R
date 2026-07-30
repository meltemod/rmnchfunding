#' Fetch bilateral CRS disbursements for a donor
#'
#' Pulls a donor's disbursements from the OECD Creditor Reporting System for
#' the purpose codes the Muskoka method weights, broken down by recipient and
#' year. The result is what `muskoka()` applies [sector_weights] to, and is
#' also readable on its own as a picture of which recipient countries a donor
#' funded and by how much.
#'
#' @details
#' Recipient rows are de-duplicated by default. This matters more than it
#' sounds: a CRS query with the recipient dimension open returns aggregates
#' and countries as sibling rows, so "Developing countries", "Africa" and
#' "Kenya" all come back together and summing them counts Kenya four times.
#' Nothing in the response marks which rows are aggregates. See
#' [crs_recipients] and the `recipients` argument.
#'
#' De-duplicating is not the same as reducing to countries. OECD reports the
#' part of a donor's spending it cannot attribute to any one country in
#' `_X` buckets — "Developing countries unspecified", "Sub-Saharan Africa
#' unspecified" — which have no members and so are kept, correctly, since they
#' do not overlap anything. They are a large share of the total, so they are
#' flagged with `is_unallocated` rather than silently mixed in with countries
#' or silently dropped.
#'
#' @section Prices:
#' `prices = "current"` returns each year in that year's own prices. Nothing
#' is converted, and the function says so.
#'
#' `prices = "constant"` requires a `base` year, and the values are deflated
#' to it with OECD's own per-donor ODA deflators. The base is explicit rather
#' than inherited because **OECD rebases its constant series with each
#' release** — it is 2024 at the time of writing and was 2023 a few months
#' earlier — so code that trusted the default would silently change meaning
#' between releases. Deflators are per donor and vary widely between them, so
#' a DAC-wide average is not used.
#'
#' To reproduce a published Donors Delivering figure, match its edition's
#' base: 2022 for the 2025 edition, 2023 for the 2026 edition.
#'
#' @param donor OECD donor code, e.g. `"USA"`, `"GBR"`, `"4EU001"` for the EU
#'   institutions. One or more.
#' @param years Integer vector of years to fetch.
#' @param sectors CRS purpose codes as character. Defaults to the codes the
#'   Muskoka method weights, taken from [sector_weights] so the two cannot
#'   drift apart.
#' @param prices Either `"constant"` (needs `base`) or `"current"`.
#' @param base Base year for `prices = "constant"`; must not be given for
#'   `"current"`.
#' @param recipients Which recipient rows to keep. `"countries"` (default)
#'   keeps only non-aggregate codes and is the only setting whose rows can
#'   safely be summed. Note that this includes OECD's unallocated `_X` buckets
#'   ("Developing countries unspecified", "Sub-Saharan Africa unspecified" and
#'   so on) — they are not countries, but they hold real spending that is not
#'   attributable to one, and dropping them would understate the total. They
#'   are marked by `is_unallocated`; see below. `"aggregates"` keeps only
#'   aggregate codes. `"all"` keeps everything as OECD returned it, which is
#'   useful for checking a total against its parts but **must not be summed**.
#' @param measure CRS measure code. Defaults to `"100"`, Official Development
#'   Assistance.
#' @param flow_type CRS flow type. Defaults to `"D"`, disbursements.
#' @param quiet Set `TRUE` to suppress the message describing what was
#'   fetched and how it was priced.
#'
#' @return A tibble of one row per donor, recipient, purpose code and year:
#' \describe{
#'   \item{donor, donor_name}{Provider code and label.}
#'   \item{recipient, recipient_name}{Recipient code and label.}
#'   \item{purpose_code, purpose_name}{CRS purpose code and label.}
#'   \item{year}{Calendar year of the disbursement.}
#'   \item{value}{Disbursement in millions of USD, in the prices described by
#'     the `prices` and `base` attributes.}
#'   \item{is_aggregate}{Whether the recipient is an aggregate of other
#'     recipients. Always `FALSE` under the default `recipients` setting;
#'     retained so that a summed frame can be checked.}
#'   \item{is_unallocated}{Whether the row is one of OECD's `_X` buckets,
#'     holding spending not attributable to a country. Substantial: over 40%
#'     of United States disbursements in 2022. Sum without these for a
#'     country-attributable figure, and with them for a donor total.}
#' }
#' with attributes `prices`, `base_year` and `fetched_on`.
#'
#' A donor that funded nothing in the requested sectors and years returns **0
#' rows with those same columns**, and warns. That is a legitimate answer
#' rather than a failure — small providers routinely report no
#' reproductive-health disbursements at all — and erroring would abort any loop
#' over donors on its first sparse one.
#'
#' @seealso [oecd_multi()] for the multilateral half, [crs_recipients] for the
#'   aggregate/leaf distinction.
#'
#' @examplesIf interactive()
#' # Reproduce the price basis of the 2026 report edition
#' us <- oecd_crs("USA", years = 2022:2024, prices = "constant", base = 2023)
#'
#' # Which countries, and how much
#' aggregate(value ~ recipient_name, data = us, FUN = sum)
#'
#' @export
oecd_crs <- function(donor,
                     years,
                     sectors = NULL,
                     prices = c("constant", "current"),
                     base = NULL,
                     recipients = c("countries", "all", "aggregates"),
                     measure = "100",
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
  recipients <- match.arg(recipients)
  pb <- check_prices(prices, base)
  if (is.null(sectors)) sectors <- muskoka_purpose_codes()
  sectors <- as.character(sectors)

  key <- sdmx_key(
    CRS_KEY_FIELDS,
    donor = donor,
    sector = sectors,
    measure = measure,
    flow_type = flow_type,
    # Current prices always, then deflate here if asked. This is what lets any
    # base year be requested: OECD serves only whichever base the current
    # release uses, so asking it for constant prices would tie the result to
    # the release. It also means the arithmetic is the same code path for
    # every base, rather than a special case when the request happens to match.
    price_base = "V",
    # Summary rows, not microdata. Requesting both would return each figure
    # twice at different granularity.
    md_dim = "_T",
    # CHANNEL and MODALITY are hierarchical in the same way RECIPIENT is: left
    # open, each returns its `_T` total AND every component, at more than one
    # level of nesting — channel 10000-60000 beneath `_T`, modality B/C/D with
    # B03/C01/D01/D02 beneath those. A single donor-recipient-sector-year can
    # therefore come back as 30-odd rows whose sum is several times the true
    # figure. For a bilateral total by recipient, which is what this function
    # is for, the totals are what is wanted.
    channel = "_T",
    modality = "_T",
    # One currency, so that values are never summed across units.
    unit_measure = "USD"
  )

  raw <- oecd_fetch(
    OECD_DCD_HOST, "DSD_CRS@DF_CRS", "1.6", key,
    start = min(years), end = max(years)
  )
  if (nrow(raw) == 0L) {
    # A donor that funded nothing in the requested sectors and years is a
    # legitimate answer, not a failure — small providers routinely report no
    # reproductive-health disbursements at all. Erroring here would abort any
    # loop over donors on its first sparse one. An empty result of the right
    # shape lets downstream code keep working, and the warning stops it being
    # mistaken for a zero total that was actually computed.
    warning("OECD has no CRS records for donor(s) ",
            paste(donor, collapse = ", "), " in ", min(years), "-", max(years),
            " under the requested sectors; returning 0 rows.", call. = FALSE)
    return(empty_crs(pb))
  }

  out <- tibble::tibble(
    donor          = raw$DONOR,
    donor_name     = raw$Donor,
    recipient      = raw$RECIPIENT,
    recipient_name = raw$Recipient,
    purpose_code   = raw$SECTOR,
    purpose_name   = raw$Sector,
    year           = as.integer(raw$TIME_PERIOD),
    value          = as.numeric(raw$OBS_VALUE)
  )
  out <- out[out$year %in% years, ]

  # Guard against the both-price-series trap. Leaving price_base open returns
  # current AND constant rows stacked, which doubles every total silently. The
  # key above pins it, so this only fires if that changes.
  if (length(unique(raw$PRICE_BASE)) > 1L) {
    stop("OECD returned more than one price basis in a single response; ",
         "refusing to combine them.", call. = FALSE)
  }

  # Qualified with the package name so R CMD check can see the binding; the
  # dataset is lazy-loaded either way.
  recip <- rmnchfunding::crs_recipients
  idx <- match(out$recipient, recip$recipient_code)
  known <- recip$is_aggregate[idx]
  out$is_unallocated <- recip$is_unallocated[idx]
  # An unrecognised recipient code is treated as an aggregate for safety: if
  # OECD adds a grouping the bundled hierarchy has not seen, silently keeping
  # it in a "countries" result would inflate the sum, whereas dropping it
  # understates one row and is visible in the warning.
  if (anyNA(known)) {
    unknown <- sort(unique(out$recipient[is.na(known)]))
    warning(
      "Recipient code(s) absent from the bundled hierarchy, treated as ",
      "aggregates and excluded from `recipients = \"countries\"`: ",
      paste(unknown, collapse = ", "),
      "\n  Re-run data-raw/crs_recipients.R to refresh.", call. = FALSE
    )
    known[is.na(known)] <- TRUE
  }
  out$is_aggregate <- known

  out <- switch(
    recipients,
    countries = out[!out$is_aggregate, ],
    aggregates = out[out$is_aggregate, ],
    all = out
  )

  if (pb$prices == "constant") {
    out <- deflate_to_base(out, pb$base)
    out$deflator <- NULL
    out <- out[order(out$donor, out$year, out$purpose_code, out$recipient), ]
  } else {
    out <- out[order(out$donor, out$year, out$purpose_code, out$recipient), ]
  }
  out <- tibble::as_tibble(out)

  attr(out, "prices") <- pb$prices
  attr(out, "base_year") <- pb$base
  attr(out, "fetched_on") <- Sys.Date()

  if (!quiet) {
    message(
      "oecd_crs(): ", nrow(out), " rows, ",
      length(unique(out$recipient)),
      switch(recipients,
             countries = " recipient countries",
             aggregates = " recipient aggregates",
             " recipients (aggregates INCLUDED - do not sum)"),
      ", ", length(unique(out$purpose_code)), " purpose codes, ",
      min(out$year), "-", max(out$year), ".\n",
      if (pb$prices == "current") {
        paste0("  Values are in CURRENT prices: each year is expressed in ",
               "that year's own prices (", paste(range(out$year),
                                                 collapse = "-"), ").")
      } else {
        paste0("  Values are in CONSTANT ", pb$base, " prices, deflated with ",
               "OECD per-donor ODA deflators.")
      },
      "\n  Millions of USD."
    )
  }

  out
}
