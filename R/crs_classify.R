# Recipient classification schemes.
#
# OECD's 19 top-level recipient groupings are not one classification but
# several overlapping ones, plus a set of flags. Only some of them partition a
# donor's total, and which ones do is not deducible from the hierarchy — see
# the comment on CRS_SCHEMES below.

# Each scheme's members, as OECD recipient codes. The members of a scheme are
# meant to be mutually exclusive and jointly exhaustive, so their reported
# values sum to the same grand total as every other scheme. That claim is
# CHECKED at run time rather than trusted, because it does not follow from the
# codelist:
#
#   * The hierarchy's membership lists disagree with the reported aggregates.
#     In the data, INC_X includes DPGC_X; in the hierarchy, it does not list
#     DPGC_X as a child. Deriving members by walking the tree would therefore
#     produce a scheme whose parts do not add to the whole.
#
#   * The World Bank scheme's members reach outside DPGC. Eleven of its leaves
#     — Bulgaria, Czechia, Estonia, Hungary, Lithuania and others — are not
#     developing countries under DPGC at all. For most donors they carry no
#     disbursements and the sums agree anyway, but a donor who funded one would
#     get a World Bank total exceeding the geographic total.
#
# Hence: use OECD's own published aggregate values, and verify the sum.
CRS_SCHEMES <- list(
  geographic = c("A", "E", "F", "O", "S", "DPGC_X"),
  dac_income = c("LDC", "OLIC", "LMIC", "UMIC", "MADCT", "INC_X"),
  wb_income  = c("OLICWB", "LMICWB", "UMICWB", "HICSWB", "INCWB_X", "INC_X")
)

# The code that carries a scheme's unattributable remainder. Reported
# separately so a caller can tell "we know where this went" from "we do not".
CRS_SCHEME_RESIDUAL <- c(
  geographic = "DPGC_X", dac_income = "INC_X", wb_income = "INC_X"
)

# Deliberately absent from CRS_SCHEMES: HIPC, LLDC, SIDS, FSCAC, ACP, ALLMR
# and ALLR. These are not classifications but overlapping flags a country
# carries in addition to its place in every scheme above — Ethiopia is
# simultaneously in F, F6, F3, LDC, LLDC, OLICWB, HIPC and FSCAC. They do not
# partition anything, so `scheme` cannot name them.

#' Total a donor's disbursements by recipient classification
#'
#' OECD classifies recipients several ways at once — geographically, by the DAC
#' List income tier, and by World Bank income group. Each is a different cut of
#' the same money, so each sums to the same total. This returns one of those
#' cuts.
#'
#' @details
#' Pass the result of [oecd_crs()] called with `recipients = "all"`, since the
#' aggregate rows are what this reads. Calling it on a default (`"countries"`)
#' result is an error rather than a silently empty answer.
#'
#' The figures are OECD's own published aggregates, not re-derived by summing
#' countries into groups. That is deliberate: OECD's hierarchical codelist does
#' not exactly describe its reported aggregates — `INC_X` includes `DPGC_X` in
#' the data but not in the codelist — so a scheme built by walking the tree
#' would not add up. Using the published aggregates and checking the total
#' instead means a disagreement surfaces as an error rather than a wrong
#' number.
#'
#' @section Schemes:
#' \describe{
#'   \item{`"geographic"`}{Africa, America, Asia, Europe, Oceania, plus
#'     `DPGC_X` for spending not attributable to any continent.}
#'   \item{`"dac_income"`}{The DAC List of ODA Recipients tiers: least
#'     developed countries, other low income, lower-middle income,
#'     upper-middle income, more advanced developing countries, plus `INC_X`
#'     for spending not attributable to an income tier. Note that **LDC is a
#'     tier of this scheme**, not a separate universe: it is a cut of the same
#'     total, which is why it must not be added to a geographic figure.}
#'   \item{`"wb_income"`}{The World Bank income classification, which is a
#'     genuinely different scheme from `"dac_income"`: it has no least-
#'     developed tier, adds a high-income group, and carries `INCWB_X` for
#'     countries the World Bank does not classify.}
#' }
#'
#' Groupings such as `HIPC`, `LLDC`, `SIDS` and `FSCAC` are **not** schemes.
#' They are overlapping flags — Ethiopia is in `F`, `F6`, `F3`, `LDC`, `LLDC`,
#' `OLICWB`, `HIPC` and `FSCAC` at once — and asking for one is an error.
#'
#' @param x A tibble from [oecd_crs()] with `recipients = "all"`.
#' @param scheme One of `"geographic"`, `"dac_income"`, `"wb_income"`.
#' @param by Additional columns to break the totals down by, e.g.
#'   `"purpose_code"` or `c("donor", "year")`. Defaults to `c("donor", "year")`.
#' @param tolerance Absolute tolerance, in millions, for the check that the
#'   scheme sums to OECD's reported grand total.
#'
#' @return A tibble of one row per grouping variable and scheme member, with
#'   `scheme`, `member`, `member_name`, `value`, `is_residual` and `share`.
#'   Carries a `grand_total` attribute.
#'
#' @seealso [oecd_crs()], [crs_recipients].
#'
#' @examplesIf interactive()
#' d <- oecd_crs("USA", years = 2022, prices = "constant", base = 2023,
#'               recipients = "all")
#' crs_classify(d, "geographic")
#' crs_classify(d, "dac_income")
#'
#' @export
crs_classify <- function(x,
                         scheme = c("geographic", "dac_income", "wb_income"),
                         by = c("donor", "year"),
                         tolerance = 0.5) {
  scheme <- match.arg(scheme)

  if (!is.data.frame(x) || !all(c("recipient", "value") %in% names(x))) {
    stop("`x` must be a data frame from oecd_crs().", call. = FALSE)
  }
  if (!"DPGC" %in% x$recipient) {
    stop("`x` has no DPGC row, so there is no total to classify against.\n",
         "  Call oecd_crs() with `recipients = \"all\"`; the default drops ",
         "the aggregate rows this function reads.", call. = FALSE)
  }
  bad_by <- setdiff(by, names(x))
  if (length(bad_by) > 0L) {
    stop("`by` names column(s) not in `x`: ", paste(bad_by, collapse = ", "),
         call. = FALSE)
  }

  members <- CRS_SCHEMES[[scheme]]
  present <- intersect(members, x$recipient)
  if (length(present) == 0L) {
    stop("None of the ", scheme, " members appear in `x`.", call. = FALSE)
  }

  keep <- x[x$recipient %in% present, , drop = FALSE]
  grp <- c(by, "recipient")
  agg <- stats::aggregate(
    keep["value"], by = as.list(keep[grp]), FUN = sum, na.rm = TRUE
  )

  # A member absent from the data means that member had no disbursements, not
  # that it is missing: reported as zero rather than dropped, so the scheme has
  # the same shape whichever donor it is applied to.
  absent <- setdiff(members, present)

  nm <- x$recipient_name[match(agg$recipient, x$recipient)]
  # Resolved before the tibble() call: inside it, `scheme` would resolve to the
  # column being created rather than to the argument.
  residual_code <- CRS_SCHEME_RESIDUAL[[scheme]]
  out <- tibble::tibble(
    scheme      = scheme,
    member      = agg$recipient,
    member_name = nm,
    value       = agg$value,
    is_residual = agg$recipient == residual_code
  )
  for (b in rev(by)) out[[b]] <- agg[[b]]
  out <- out[c(by, "scheme", "member", "member_name", "value", "is_residual")]

  # ---- the check that makes this trustworthy ----
  # Every scheme is a cut of the same money, so it must reproduce OECD's own
  # reported DPGC total. A mismatch means the scheme definition and OECD's
  # aggregates have diverged, and the safe response is to say so rather than
  # return parts that do not make a whole.
  totals <- stats::aggregate(
    x[x$recipient == "DPGC", "value"],
    by = as.list(x[x$recipient == "DPGC", by]), FUN = sum
  )
  got <- stats::aggregate(out["value"], by = as.list(out[by]), FUN = sum)
  cmp <- merge(totals, got, by = by, suffixes = c("_dpgc", "_scheme"))
  off <- abs(cmp$value_dpgc - cmp$value_scheme) > tolerance
  if (any(off)) {
    stop(
      "The ", scheme, " scheme does not sum to OECD's reported total:\n",
      paste0("  ", apply(cmp[off, by, drop = FALSE], 1L, paste,
                         collapse = " "),
             ": scheme ", round(cmp$value_scheme[off], 2),
             " vs DPGC ", round(cmp$value_dpgc[off], 2),
             " (off by ", round(cmp$value_scheme[off] - cmp$value_dpgc[off], 2),
             ")", collapse = "\n"),
      if (length(absent) > 0L) {
        paste0("\n  Members absent from the data: ",
               paste(absent, collapse = ", "), ".")
      },
      "\n  This means the scheme definition and OECD's aggregates have ",
      "diverged; the parts no longer make the whole.",
      call. = FALSE
    )
  }

  grand <- sum(cmp$value_dpgc)
  out$share <- out$value / grand
  out <- out[order(out[[by[1]]], -out$value), ]
  attr(out, "grand_total") <- grand
  tibble::as_tibble(out)
}
