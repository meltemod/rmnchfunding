#' How OECD recipients map to the source data, and where borrowed weights come
#' from
#'
#' Returns the crosswalk the package uses internally: each OECD recipient
#' alongside its World Bank and IHME GBD identifiers, its position in the OECD
#' DAC geographic hierarchy, and — for the four weights that vary by recipient
#' and year — whether its weight is its own or borrowed from a geographic
#' group.
#'
#' @details
#' This joins two things that are otherwise separate. [recipient_crosswalk] has
#' the identifiers and geography but nothing about imputation;
#' [rmnch_recipient_weights] records the imputation but repeats every recipient
#' once per year and purpose code. What a reader checking the method usually
#' wants is one row per recipient, which is what this returns.
#'
#' The same content ships as a plain file for use outside R:
#'
#' ```r
#' read.csv(system.file("extdata", "recipient_crosswalk.csv",
#'                      package = "rmnchfunding"))
#' ```
#'
#' @section Three naming systems:
#' No two of the sources spell countries the same way, and none is reachable
#' from another by plain string matching — Cote d'Ivoire differs between all
#' three in both its accent and its apostrophe. That is why the mapping is
#' stored rather than computed at the point of use.
#'
#' `iso3` is `NA` where the World Bank has no record, and `gbd_location_name`
#' is `NA` where GBD does not cover the recipient separately. Those are the
#' recipients whose weights are borrowed.
#'
#' @section What "borrowed" means:
#' A recipient absent from the source data takes the unweighted mean of the
#' weights of the recipients in its geographic group, for the same year, trying
#' the narrowest group first: subregion, then region, then continent. The
#' `source_*` columns record which was used.
#'
#' The geography is the **OECD DAC** hierarchy, not UN M49 and not the World
#' Bank's regions; see [recipient_crosswalk] for how they differ and why it
#' matters. Note that the hierarchy is ragged, so `region_name` is `NA` for the
#' fifteen European recipients, whose continent is not subdivided.
#'
#' @param purpose_code Optionally one CRS purpose code. Given one, the result
#'   carries a single `source` column for that code; given `NULL` (default),
#'   one `source_<code>` column per code. Must be one of the four codes whose
#'   weight varies by recipient: `"12262"`, `"12263"`, `"13040"`, `"51010"`.
#' @param imputed_only Set `TRUE` to keep only recipients whose weight is
#'   borrowed — for `purpose_code`, or for any code when that is `NULL`.
#'
#' @return A tibble with one row per OECD recipient:
#' \describe{
#'   \item{recipient_code, recipient_name}{OECD identifiers.}
#'   \item{iso3, wb_name}{World Bank identifiers, `NA` if absent.}
#'   \item{gbd_location_name}{IHME GBD location name, `NA` if absent.}
#'   \item{continent, region, subregion}{OECD DAC hierarchy codes.}
#'   \item{continent_name, region_name, subregion_name}{The same as names.
#'     `NA` where that level does not exist.}
#'   \item{has_worldbank_data, has_gbd_data}{Whether the recipient appears in
#'     each source.}
#'   \item{no_data_reason}{Why a recipient is absent from the World Bank list,
#'     where that is known.}
#'   \item{source or source_<code>}{`"own"`, or which geographic group the
#'     weight was borrowed from.}
#' }
#'
#' @seealso [recipient_crosswalk] and [rmnch_recipient_weights] for the
#'   underlying data.
#'
#' @examples
#' # the whole crosswalk
#' recipient_map()
#'
#' # which recipients borrow a malaria weight, and from where
#' recipient_map("12262", imputed_only = TRUE)[
#'   c("recipient_name", "continent_name", "source")
#' ]
#'
#' # look up how one recipient is identified across the three sources
#' m <- recipient_map()
#' m[m$recipient_code == "CIV",
#'   c("recipient_name", "wb_name", "gbd_location_name")]
#'
#' @export
recipient_map <- function(purpose_code = NULL, imputed_only = FALSE) {
  cw <- rmnchfunding::recipient_crosswalk
  w <- rmnchfunding::rmnch_recipient_weights
  codes <- sort(unique(w$purpose_code))

  if (!is.null(purpose_code)) {
    if (length(purpose_code) != 1L || !purpose_code %in% codes) {
      stop("`purpose_code` must be one of: ",
           paste(codes, collapse = ", "),
           ".\n  These are the four codes whose RMNCH weight varies by ",
           "recipient; every other code has a single global weight in ",
           "`sector_weights`.", call. = FALSE)
    }
    codes <- purpose_code
  }
  if (!is.logical(imputed_only) || length(imputed_only) != 1L ||
        is.na(imputed_only)) {
    stop("`imputed_only` must be TRUE or FALSE.", call. = FALSE)
  }

  out <- cw
  out$has_worldbank_data <- !is.na(cw$iso3)
  out$has_gbd_data <- !is.na(cw$gbd_location_name)

  # The imputation source is constant across years for a given recipient and
  # code, so it collapses to one value. Asserted rather than assumed: were it
  # to vary, a single column would be silently reporting one year's provenance
  # as though it covered all of them.
  srcs <- lapply(codes, function(pc) {
    d <- w[w$purpose_code == pc, ]
    s <- tapply(d$source, d$recipient_code, function(x) {
      u <- unique(x)
      if (length(u) != 1L) {
        stop("The imputation source varies across years for a recipient ",
             "under code ", pc, "; it cannot be reduced to one column.",
             call. = FALSE)
      }
      u
    })
    as.vector(s[out$recipient_code])
  })
  names(srcs) <- if (length(codes) == 1L) "source" else paste0("source_", codes)
  for (nm in names(srcs)) out[[nm]] <- srcs[[nm]]

  if (imputed_only) {
    borrowed <- Reduce(`|`, lapply(names(srcs), function(nm) {
      !is.na(out[[nm]]) & out[[nm]] != "own"
    }))
    out <- out[borrowed, , drop = FALSE]
  }

  out <- out[order(out$recipient_name), ]
  tibble::as_tibble(out)
}
