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

# Level names per scheme. Level 0 is always the grand total; the last level is
# always terminal. Geography nests four deep, the income classifications one:
# their groups hold countries directly.
CRS_SCHEME_LEVELS <- list(
  geographic = c("total", "continent", "region", "subregion", "country"),
  dac_income = c("total", "tier", "country"),
  wb_income  = c("total", "group", "country")
)

#' Descend a set of codes one step down the hierarchy
#'
#' A branch that has already ended stands in for itself, so the result is a
#' FRONTIER rather than a depth slice. That is what keeps every level a
#' partition: Europe holds countries directly while Africa holds regions, so a
#' plain "all nodes at depth 2" would drop every European country.
#'
#' @noRd
descend_one <- function(codes, tree) {
  out <- lapply(codes, function(c) {
    ch <- tree$child_code[tree$parent_code == c]
    if (length(ch) == 0L) c else ch
  })
  unique(unlist(out, use.names = FALSE))
}

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
#' @section Levels:
#' Every level of every scheme sums to the same grand total, so a level is a
#' finer cut of the same money rather than a different quantity.
#'
#' A level is a **frontier**, not a depth slice: branches that have already
#' ended stand in for themselves. This matters because the hierarchy is ragged.
#' Africa divides into regions and then subregions, while Europe holds its
#' countries directly, so the geographic `"region"` level contains African
#' regions *and* European countries side by side. Taking "every node at depth
#' 2" instead would drop every European country and the level would not add up.
#'
#' The same applies to unallocated spending, which enters at whatever level it
#' was reported. `DPGC_X` appears from `"continent"` downwards, while
#' `F6_X` ("Sub-Saharan Africa unspecified") only appears once the cut reaches
#' the level at which it sits. A country-level cut therefore still contains
#' regional residuals; they are marked by `is_unallocated`.
#'
#' Groupings such as `HIPC`, `LLDC`, `SIDS` and `FSCAC` are **not** schemes.
#' They are overlapping flags — Ethiopia is in `F`, `F6`, `F3`, `LDC`, `LLDC`,
#' `OLICWB`, `HIPC` and `FSCAC` at once — and asking for one is an error.
#'
#' @param x A tibble from [oecd_crs()] with `recipients = "all"`.
#' @param scheme One of `"geographic"`, `"dac_income"`, `"wb_income"`.
#' @param level How far down the scheme to cut, either a level name or a
#'   number. `"geographic"` accepts `"total"`, `"continent"`, `"region"`,
#'   `"subregion"`, `"country"` (0 to 4); the income schemes accept `"total"`,
#'   `"tier"` or `"group"`, and `"country"` (0 to 2). Defaults to level 1, the
#'   scheme's own groups. See Levels.
#' @param by Additional columns to break the totals down by, e.g.
#'   `"purpose_code"` or `c("donor", "year")`. Defaults to `c("donor", "year")`.
#' @param complete Set `TRUE` to include every member of the level, filling
#'   those the donor did not fund with `0`. The default `FALSE` returns only
#'   members with data. See Completing a level.
#' @param tolerance Absolute tolerance, in millions, for the check that the
#'   scheme sums to OECD's reported grand total.
#'
#' @return A tibble of one row per grouping variable and scheme member, with
#'   `scheme`, `level`, `member`, `member_name`, `value`, `is_residual`,
#'   `is_unallocated` and `share`. Carries a `grand_total` attribute.
#'
#' @section Completing a level:
#' By default a level lists only the members the donor actually funded, so the
#' rows differ between donors and between years. `complete = TRUE` fills the
#' rest with `0`, giving the same rows every time — for the United States over
#' 2021 to 2024, 151 recipients appear in the data out of 207 in the hierarchy,
#' so 56 are added as explicit zeros.
#'
#' A zero and an absent row mean the same thing here, since OECD reports no row
#' for a recipient a donor did not fund. Completing therefore changes the shape
#' of the result but never a total.
#'
#' Note that membership of the World Bank income groups is a **current
#' snapshot**, and countries move between groups over time: Hungary was
#' upper-middle income in the 1990s, high income from 2007, briefly
#' upper-middle again in 2012 and 2013, and high income since 2014. That does
#' not affect the figures here, because levels 0 and 1 use OECD's own reported
#' aggregates and the country level returns one row per country rather than
#' countries grouped by tier — all three schemes enumerate the same country
#' set. It would matter if this package ever reported which countries belong to
#' a tier in a given year, which would need the World Bank's historical
#' classification rather than a codelist snapshot.
#'
#' @seealso [oecd_crs()], [crs_recipients].
#'
#' @examplesIf interactive()
#' d <- oecd_crs("USA", years = 2022, prices = "constant", base = 2023,
#'               recipients = "all")
#' crs_classify(d, "geographic")                      # continents
#' crs_classify(d, "geographic", level = "subregion")
#' crs_classify(d, "dac_income", level = "country")
#'
#' @export
crs_classify <- function(x,
                         scheme = c("geographic", "dac_income", "wb_income"),
                         level = 1L,
                         by = c("donor", "year"),
                         complete = FALSE,
                         tolerance = 0.5) {
  scheme <- match.arg(scheme)
  names_for_scheme <- CRS_SCHEME_LEVELS[[scheme]]
  max_level <- length(names_for_scheme) - 1L

  if (is.character(level)) {
    if (length(level) != 1L || !level %in% names_for_scheme) {
      stop("`level` must be one of: ",
           paste0("\"", names_for_scheme, "\"", collapse = ", "),
           ", or a number from 0 to ", max_level, ".", call. = FALSE)
    }
    level <- match(level, names_for_scheme) - 1L
  }
  level <- suppressWarnings(as.integer(level))
  if (length(level) != 1L || is.na(level) || level < 0L || level > max_level) {
    stop("`level` must be between 0 and ", max_level, " for scheme \"",
         scheme, "\", or one of: ",
         paste0("\"", names_for_scheme, "\"", collapse = ", "), ".",
         call. = FALSE)
  }

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

  # Level 0 is the grand total itself; level 1 is the scheme's own members;
  # deeper levels descend the frontier from there.
  members <- if (level == 0L) "DPGC" else CRS_SCHEMES[[scheme]]
  if (level > 1L) {
    tree <- rmnchfunding::crs_recipient_tree
    for (i in seq_len(level - 1L)) members <- descend_one(members, tree)
  }
  present <- intersect(members, x$recipient)
  if (length(present) == 0L) {
    stop("None of the ", scheme, " members appear in `x`.", call. = FALSE)
  }

  keep <- x[x$recipient %in% present, , drop = FALSE]
  grp <- c(by, "recipient")
  agg <- stats::aggregate(
    keep["value"], by = as.list(keep[grp]), FUN = sum, na.rm = TRUE
  )

  absent <- setdiff(members, present)

  if (isTRUE(complete) && length(absent) > 0L) {
    # OECD reports no row at all for a recipient a donor did not fund, so an
    # absent member and a zero mean the same thing. Filling them in gives the
    # same rows for every donor and year, which is what makes results
    # comparable across donors; it cannot change a total.
    combos <- unique(agg[by])
    filler <- merge(combos, data.frame(recipient = absent,
                                       stringsAsFactors = FALSE))
    filler$value <- 0
    agg <- rbind(agg[c(by, "recipient", "value")],
                 filler[c(by, "recipient", "value")])
  }

  # Label from the data where possible, and from the bundled codelist where the
  # member is absent from it — a zero-filled row with no name would not say
  # which country reported nothing.
  ur <- rmnchfunding::crs_recipients
  nm <- x$recipient_name[match(agg$recipient, x$recipient)]
  gap <- is.na(nm)
  nm[gap] <- ur$recipient_name[match(agg$recipient[gap], ur$recipient_code)]
  # Resolved before the tibble() call: inside it, `scheme` would resolve to the
  # column being created rather than to the argument.
  residual_code <- CRS_SCHEME_RESIDUAL[[scheme]]
  level_name <- names_for_scheme[level + 1L]
  out <- tibble::tibble(
    scheme      = scheme,
    level       = level_name,
    member      = agg$recipient,
    member_name = nm,
    value       = agg$value,
    is_residual = agg$recipient == residual_code
  )
  for (b in rev(by)) out[[b]] <- agg[[b]]
  # Unallocated rows are flagged here too: a country-level cut still contains
  # regional residuals, and a caller summing "by country" needs to see which
  # rows are not countries.
  out$is_unallocated <- ur$is_unallocated[match(out$member, ur$recipient_code)]
  out$is_unallocated[is.na(out$is_unallocated)] <- FALSE
  out <- out[c(by, "scheme", "level", "member", "member_name", "value",
               "is_residual", "is_unallocated")]

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
      "\n  The scheme definition and OECD's aggregates have diverged at level ",
      level, " (\"", level_name, "\"); the parts no longer make the whole.",
      # Name the two causes seen in practice, since neither is guessable from
      # the numbers alone.
      if (any(cmp$value_scheme[off] > cmp$value_dpgc[off])) {
        paste0(
          "\n  Scheme EXCEEDS the total, which means double counting. For ",
          "wb_income this is the known case: eleven of its members (Bulgaria, ",
          "Czechia, Estonia, Falkland Islands, Hungary, Latvia, Lithuania, ",
          "Poland, Romania, Russia, Slovakia) sit outside DPGC. They carry no ",
          "ODA, since they are not on the DAC List of ODA Recipients, so this ",
          "should not arise for `measure = \"100\"`, but another measure may ",
          "reach them."
        )
      } else {
        paste0(
          "\n  Scheme falls SHORT of the total, which means a member is ",
          "missing. The known case is a residual whose children OECD's ",
          "codelist does not list in full; see ?crs_recipient_tree for the ",
          "INC_X -> DPGC_X repair, and re-run data-raw/crs_recipient_tree.R ",
          "in case the hierarchy has moved."
        )
      },
      call. = FALSE
    )
  }

  grand <- sum(cmp$value_dpgc)
  out$share <- out$value / grand
  out <- out[order(out[[by[1]]], -out$value), ]
  attr(out, "grand_total") <- grand
  tibble::as_tibble(out)
}
