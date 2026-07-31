#' Look up the coefficients a report edition applies
#'
#' Returns the sector and agency weights for a given Donors Delivering edition
#' in one table, so that the numbers behind an estimate can be read directly
#' rather than assembled from [sector_weights] and [agency_weights] by hand.
#'
#' @details
#' A Muskoka estimate has two halves with two different coefficient tables:
#' bilateral CRS disbursements weighted by purpose code, and core
#' contributions weighted by agency. They are stored separately because they
#' are keyed differently — a sector weight is fixed across years, an agency
#' weight is not — and this function is the reader's view over both.
#'
#' @section Editions disagree, and it matters which you use:
#' Every edition recomputes its agency weights for all three years it covers,
#' including years an earlier edition already published, and the revisions are
#' large: of the 66 agency-years published in both the 2025 and 2026 editions,
#' 31 differ. Reproducing a published figure means matching its edition, and
#' its price base too — 2022 constant prices for the 2025 edition, 2023 for
#' the 2026.
#'
#' Sector weights are stable across editions by comparison. The only
#' differences are the nine values the 2025 and 2026 editions misprint, and
#' those are corrections rather than revisions: `weight` holds the figure that
#' reproduces the edition's own published totals, `weight_printed` what the
#' edition's table actually shows. See [sector_weights].
#'
#' @param report_edition Which edition's coefficients to return: `2023`,
#'   `2024`, `2025` or `2026`. Defaults to the most recent.
#' @param universe Optional filter: `"rmnch"`, `"srhr"` or `"fp"`. All three
#'   by default.
#' @param year Optional filter on the spending year, which applies to the
#'   multilateral half only. Bilateral rows have no year and are returned
#'   whatever this is set to, since their weight is the same in every year.
#' @param half Which half to return: `"both"` (default), `"bilateral"` or
#'   `"multilateral"`.
#'
#' @return A tibble of one row per coefficient:
#' \describe{
#'   \item{half}{`"bilateral"` or `"multilateral"`.}
#'   \item{item}{CRS purpose code, or agency name.}
#'   \item{item_name}{Purpose code description, or the agency name again.}
#'   \item{universe}{`"rmnch"`, `"srhr"` or `"fp"`.}
#'   \item{report_edition}{Edition the coefficient is taken from.}
#'   \item{data_year}{Spending year for multilateral rows; `NA` for bilateral,
#'     whose weights do not vary by year.}
#'   \item{weight}{The coefficient, as a proportion in `[0, 1]`. `NA` for the
#'     four RMNCH codes the source gives as `varies*`; see
#'     [rmnch_recipient_weights].}
#'   \item{weight_printed}{What the edition's own table prints. Differs from
#'     `weight` only for the nine misprinted sector values.}
#'   \item{is_misprint}{`TRUE` where the two differ.}
#' }
#'
#' @seealso [sector_weights] and [agency_weights] for the underlying tables,
#'   [muskoka2()] to apply them.
#'
#' @examples
#' # Everything the 2026 edition applies to SRHR
#' muskoka_weights(2026, universe = "srhr")
#'
#' # The nine values the 2026 table misprints
#' w <- muskoka_weights(2026)
#' w[w$is_misprint, c("item", "universe", "weight", "weight_printed")]
#'
#' # How one agency's SRHR weight was revised across editions
#' do.call(rbind, lapply(2023:2026, function(e) {
#'   x <- muskoka_weights(e, universe = "srhr", half = "multilateral")
#'   x[x$item == "UNFPA", ]
#' }))
#'
#' @export
muskoka_weights <- function(report_edition = 2026,
                            universe = NULL,
                            year = NULL,
                            half = c("both", "bilateral", "multilateral")) {
  half <- match.arg(half)
  sw <- rmnchfunding::sector_weights
  aw <- rmnchfunding::agency_weights

  editions <- sort(unique(sw$report_edition))
  report_edition <- suppressWarnings(as.integer(report_edition))
  if (length(report_edition) != 1L || is.na(report_edition) ||
        !report_edition %in% editions) {
    stop("`report_edition` must be one of: ", paste(editions, collapse = ", "),
         ".", call. = FALSE)
  }

  if (!is.null(universe)) {
    universe <- match.arg(universe, c("rmnch", "srhr", "fp"), several.ok = TRUE)
  } else {
    universe <- c("rmnch", "srhr", "fp")
  }

  bil <- sw[sw$report_edition == report_edition &
              as.character(sw$universe) %in% universe, ]
  bil <- tibble::tibble(
    half           = "bilateral",
    item           = bil$purpose_code,
    item_name      = bil$purpose_name,
    universe       = as.character(bil$universe),
    report_edition = bil$report_edition,
    data_year      = NA_integer_,
    weight         = bil$weight,
    weight_printed = bil$weight_printed,
    is_misprint    = bil$is_misprint
  )

  mul <- aw[aw$report_edition == report_edition &
              as.character(aw$universe) %in% universe, ]
  # A year outside the edition's coverage is a caller error worth naming
  # rather than an empty table, which reads as "this agency had no weight".
  if (!is.null(year)) {
    covered <- sort(unique(mul$data_year))
    bad <- setdiff(year, covered)
    if (length(bad) > 0L) {
      stop("The ", report_edition, " edition covers spending year(s) ",
           paste(covered, collapse = ", "), ", not ",
           paste(sort(bad), collapse = ", "), ".", call. = FALSE)
    }
    mul <- mul[mul$data_year %in% year, ]
  }
  mul <- tibble::tibble(
    half           = "multilateral",
    item           = mul$agency,
    item_name      = mul$agency,
    universe       = as.character(mul$universe),
    report_edition = mul$report_edition,
    data_year      = mul$data_year,
    weight         = mul$weight,
    weight_printed = mul$weight,
    is_misprint    = FALSE
  )

  out <- switch(half,
    both         = rbind(bil, mul),
    bilateral    = bil,
    multilateral = mul
  )
  out$universe <- factor(out$universe, levels = c("rmnch", "srhr", "fp"))
  out <- out[order(out$half, out$universe, out$item, out$data_year), ]
  rownames(out) <- NULL
  out
}
