#' Estimate a provider's RMNCH, SRHR or family-planning funding
#'
#' Applies the revised Muskoka method to a provider's OECD data: bilateral CRS
#' disbursements weighted by purpose code, plus core contributions to
#' multilateral agencies weighted by agency. Returns one row per provider and
#' year.
#'
#' @details
#' Two halves are fetched and weighted separately.
#'
#' **Bilateral.** [oecd_crs()] returns disbursements by recipient, purpose code
#' and year. Twenty-nine of the thirty-three purpose codes carry a single
#' global weight from [sector_weights]. The other four — 12262 malaria, 12263
#' tuberculosis, 13040 STD including HIV/AIDS and 51010 general budget support
#' — have an RMNCH weight that varies by recipient and year, taken from
#' [rmnch_recipient_weights] and joined on the disbursement's own recipient and
#' year. For SRHR and family planning those four have global weights like any
#' other code, so the join applies only to `universe = "rmnch"`.
#'
#' **Multilateral.** [oecd_multi()] returns core contributions by agency and
#' year, weighted by [agency_weights] for the matching agency, spending year
#' and report edition.
#'
#' @section The three universes do not add up:
#' RMNCH, SRHR and family planning overlap by construction — the same
#' disbursement contributes to more than one. Adding two results together
#' double counts, and the source reports say so explicitly. Estimate and
#' report them separately.
#'
#' @section Choosing an edition and a price base:
#' `report_edition` selects the coefficient vintage for both halves. Each
#' edition recomputes its agency weights for every year it covers, and the
#' revisions are large: the Asian Development Bank's 2023 RMNCH weight is 5.18%
#' in the 2025 edition and 13.42% in the 2026 edition. Reproducing a published
#' figure means matching its edition, and matching its price base too — 2022
#' constant prices for the 2025 edition, 2023 for the 2026.
#'
#' Sector weights barely move between editions; the nine values the 2025 and
#' 2026 editions misprint are corrected here in every edition, because they
#' are errata rather than revisions and each edition's own published totals
#' are reproduced by the corrected figure. See [sector_weights].
#'
#' @param donor OECD donor code, e.g. `"USA"`. One or more.
#' @param years Integer vector of years.
#' @param universe One of `"rmnch"`, `"srhr"`, `"fp"`.
#' @param prices `"constant"` (needs `base`) or `"current"`. Passed to both
#'   fetchers, so the two halves are always on the same basis.
#' @param base Base year for `prices = "constant"`.
#' @param report_edition Which edition's coefficients to apply: `2023`,
#'   `2024`, `2025` or `2026`. Selects both halves — sector weights and agency
#'   weights — so an estimate never mixes editions. Defaults to the most
#'   recent. [muskoka_weights()] shows what a given edition applies.
#' @param ida Only meaningful for `universe = "fp"`. `0` (default) applies the
#'   published Donors Delivering treatment, which does not count IDA
#'   contributions to family planning; `1` applies the revised Muskoka 1%
#'   instead. See [agency_weights].
#' @param detail Set `TRUE` to return the weighted rows rather than the
#'   provider-year totals, for checking where an estimate comes from.
#' @param quiet Set `TRUE` to suppress the summary message.
#'
#' @return With `detail = FALSE` (default), a tibble of one row per provider
#'   and year:
#' \describe{
#'   \item{donor, donor_name}{Provider.}
#'   \item{year}{Calendar year.}
#'   \item{universe}{Which universe was estimated.}
#'   \item{bilateral}{Weighted CRS disbursements, millions of USD.}
#'   \item{multilateral}{Weighted core contributions, millions of USD.}
#'   \item{total}{The two summed.}
#' }
#' with attributes `prices`, `base_year`, `report_edition`, `ida` and
#' `fetched_on`.
#'
#' With `detail = TRUE`, the underlying rows: every disbursement or
#' contribution with the weight applied to it, its `weight_source`, and the
#' weighted value.
#'
#' @seealso [oecd_crs()] and [oecd_multi()] for the inputs, [muskoka_weights()]
#'   to read the coefficients an edition applies, [sector_weights],
#'   [rmnch_recipient_weights] and [agency_weights] for the tables themselves.
#'
#' @examplesIf interactive()
#' # United States RMNCH, on the 2026 edition's basis
#' muskoka2("USA", years = 2022:2024, prices = "constant", base = 2023)
#'
#' # Family planning with the revised Muskoka treatment of IDA
#' muskoka2("USA", years = 2022, prices = "current", universe = "fp", ida = 1)
#'
#' # Where an estimate comes from
#' muskoka2("USA", years = 2022, prices = "current", detail = TRUE)
#'
#' @export
muskoka2 <- function(donor,
                     years,
                     universe = c("rmnch", "srhr", "fp"),
                     prices = c("constant", "current"),
                     base = NULL,
                     report_edition = 2026,
                     ida = c(0, 1),
                     detail = FALSE,
                     quiet = FALSE) {
  universe <- match.arg(universe)
  pb <- check_prices(prices, base)

  editions <- intersect(
    sort(unique(rmnchfunding::agency_weights$report_edition)),
    sort(unique(rmnchfunding::sector_weights$report_edition))
  )
  report_edition <- suppressWarnings(as.integer(report_edition))
  if (length(report_edition) != 1L || is.na(report_edition) ||
        !report_edition %in% editions) {
    stop("`report_edition` must be one of: ", paste(editions, collapse = ", "),
         ".", call. = FALSE)
  }

  ida <- suppressWarnings(as.numeric(ida[1]))
  if (is.na(ida) || !ida %in% c(0, 1)) {
    stop("`ida` must be 0 or 1.", call. = FALSE)
  }
  if (ida != 0 && universe != "fp") {
    stop("`ida` applies only to `universe = \"fp\"`.\n",
         "  It selects between the published 0% and the revised Muskoka 1% ",
         "for IDA's family-planning weight; neither affects RMNCH or SRHR.",
         call. = FALSE)
  }

  # ---- bilateral ----------------------------------------------------------
  crs <- oecd_crs(donor, years, prices = pb$prices, base = pb$base,
                  quiet = TRUE)
  bil <- tibble::tibble()
  if (nrow(crs) > 0L) {
    sw <- rmnchfunding::sector_weights
    sw <- sw[as.character(sw$universe) == universe &
               sw$report_edition == report_edition,
             c("purpose_code", "weight")]
    crs$weight <- sw$weight[match(crs$purpose_code, sw$purpose_code)]
    crs$weight_source <- "sector_weights"

    # The four varying codes, for RMNCH only. Their sector weight is NA by
    # construction — a table with one weight per code cannot express a value
    # that differs by recipient and year — so the join must succeed for every
    # such row or the estimate would silently drop them.
    if (universe == "rmnch") {
      rw <- rmnchfunding::rmnch_recipient_weights
      k <- match(
        paste(crs$purpose_code, crs$recipient, crs$year),
        paste(rw$purpose_code, rw$recipient_code, rw$year)
      )
      hit <- !is.na(k)
      crs$weight[hit] <- rw$weight[k[hit]]
      crs$weight_source[hit] <- paste0("recipient-year (", rw$source[k[hit]], ")")
    }

    if (anyNA(crs$weight)) {
      gaps <- unique(crs[is.na(crs$weight), c("purpose_code", "recipient", "year")])
      stop(
        "No ", universe, " weight for ", nrow(gaps),
        " disbursement row(s), e.g.\n",
        paste0("  code ", utils::head(gaps$purpose_code, 3),
               ", recipient ", utils::head(gaps$recipient, 3),
               ", ", utils::head(gaps$year, 3), collapse = "\n"),
        "\n  Refusing rather than treating a missing weight as zero, which ",
        "would understate the total with no sign that anything was missing.",
        call. = FALSE
      )
    }
    crs$weighted <- crs$value * crs$weight
    bil <- crs
  }

  # ---- multilateral -------------------------------------------------------
  mul <- suppressWarnings(
    oecd_multi(donor, years, prices = pb$prices, base = pb$base, quiet = TRUE)
  )
  if (nrow(mul) > 0L) {
    aw <- rmnchfunding::agency_weights
    aw <- aw[as.character(aw$universe) == universe &
               aw$report_edition == report_edition, ]
    k <- match(paste(mul$agency, mul$year), paste(aw$agency, aw$data_year))
    mul$weight <- aw$weight[k]
    mul$weight_source <- paste0("agency_weights (", report_edition, ")")

    # The revised Muskoka treatment of IDA, applied at call time rather than
    # stored: 1% belongs to that method rather than to any published edition.
    if (universe == "fp" && ida == 1) {
      is_ida <- mul$agency == "IDA"
      mul$weight[is_ida] <- 0.01
      mul$weight_source[is_ida] <- "revised Muskoka (ida = 1)"
    }

    # A year outside the edition's coverage has no weight. That is a real
    # limitation rather than a bug — the 2025 edition stops at 2023 — so it
    # names the years rather than silently dropping them.
    if (anyNA(mul$weight)) {
      bad <- sort(unique(mul$year[is.na(mul$weight)]))
      stop(
        "The ", report_edition, " edition has no multilateral weights for ",
        "year(s) ", paste(bad, collapse = ", "), ".\n",
        "  It covers ", paste(range(aw$data_year), collapse = "-"),
        ". Use a different `report_edition`, or restrict `years`.",
        call. = FALSE
      )
    }
    mul$weighted <- mul$value * mul$weight
  }

  if (detail) {
    out <- rbind(
      if (nrow(bil) > 0L) tibble::tibble(
        donor = bil$donor, year = bil$year, half = "bilateral",
        item = bil$purpose_code, item_name = bil$purpose_name,
        recipient = bil$recipient, value = bil$value, weight = bil$weight,
        weight_source = bil$weight_source, weighted = bil$weighted
      ),
      if (nrow(mul) > 0L) tibble::tibble(
        donor = mul$donor, year = mul$year, half = "multilateral",
        item = mul$agency, item_name = mul$agency,
        recipient = NA_character_, value = mul$value, weight = mul$weight,
        weight_source = mul$weight_source, weighted = mul$weighted
      )
    )
    attr(out, "universe") <- universe
    attr(out, "prices") <- pb$prices
    attr(out, "base_year") <- pb$base
    attr(out, "report_edition") <- report_edition
    attr(out, "ida") <- ida
    attr(out, "fetched_on") <- Sys.Date()
    return(out)
  }

  grid <- expand.grid(donor = unique(donor), year = sort(unique(years)),
                      stringsAsFactors = FALSE)
  sum_by <- function(d, col) {
    if (nrow(d) == 0L) return(rep(0, nrow(grid)))
    s <- stats::aggregate(d[[col]], by = list(donor = d$donor, year = d$year),
                          FUN = sum, na.rm = TRUE)
    v <- s$x[match(paste(grid$donor, grid$year), paste(s$donor, s$year))]
    ifelse(is.na(v), 0, v)
  }
  nm <- if (nrow(bil) > 0L) {
    bil$donor_name[match(grid$donor, bil$donor)]
  } else if (nrow(mul) > 0L) {
    mul$donor_name[match(grid$donor, mul$donor)]
  } else rep(NA_character_, nrow(grid))

  out <- tibble::tibble(
    donor = grid$donor,
    donor_name = nm,
    year = as.integer(grid$year),
    universe = universe,
    bilateral = sum_by(bil, "weighted"),
    multilateral = sum_by(mul, "weighted")
  )
  out$total <- out$bilateral + out$multilateral
  out <- out[order(out$donor, out$year), ]

  attr(out, "prices") <- pb$prices
  attr(out, "base_year") <- pb$base
  attr(out, "report_edition") <- report_edition
  attr(out, "ida") <- ida
  attr(out, "fetched_on") <- Sys.Date()

  if (!quiet) {
    message(
      "muskoka2(): ", toupper(universe), ", ",
      paste(range(out$year), collapse = "-"), ", ",
      length(unique(out$donor)), " provider(s).\n",
      "  multilateral weights from the ", report_edition, " edition",
      if (universe == "fp") paste0("; ida = ", ida) else "",
      ".\n  ",
      if (pb$prices == "current") {
        "Values in CURRENT prices, each year in its own."
      } else {
        paste0("Values in CONSTANT ", pb$base, " prices.")
      },
      " Millions of USD.\n",
      "  RMNCH, SRHR and FP overlap by construction; do not add them together."
    )
  }
  out
}
