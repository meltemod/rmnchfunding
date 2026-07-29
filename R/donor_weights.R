#' Recover a donor's per-sector RMNCH weights from published totals
#'
#' The Muskoka 2 method sets the RMNCH share of four CRS purpose codes — 12262
#' (malaria control), 12263 (tuberculosis control), 13040 (STD control
#' including HIV/AIDS) and 51010 (general budget support-related aid) — per
#' donor country rather than globally, and the source table records them only
#' as `varies*`. This function recovers them for one donor by solving the
#' published RMNCH totals for the unknown weights.
#'
#' @details
#' For one donor, each published year gives one equation. Writing \eqn{w} for
#' the four unknown weights, \eqn{A} for that donor's disbursements in those
#' four codes (one row per year, one column per code), and \eqn{b} for what
#' the published total leaves unexplained once every *known* weight has been
#' applied:
#'
#' \deqn{A w = b}
#'
#' The caller is responsible for forming `b`: it is the published RMNCH total
#' minus the contribution of every purpose code whose weight is known from
#' [sector_weights], minus the imputed multilateral contribution from
#' [agency_weights]. Anything left over is what the four unknown weights must
#' account for.
#'
#' Weights are assumed **constant across years** for a given donor. That
#' assumption is what makes the problem tractable: it turns one equation per
#' year into repeated observations of the same unknowns, rather than a fresh
#' set of unknowns each year.
#'
#' @section Identifiability:
#' Three published years give three equations. Four unknown weights would
#' therefore be underdetermined — but only codes the donor actually disbursed
#' in are unknowns that matter, because a zero disbursement contributes
#' nothing whatever its weight. The effective count is the number of the four
#' codes with non-zero spending:
#'
#' \tabular{ll}{
#'   0 non-zero codes \tab nothing to identify \cr
#'   1-2 non-zero codes \tab overdetermined; solvable and checkable against
#'     the spare equations \cr
#'   3 non-zero codes \tab exactly determined \cr
#'   4 non-zero codes \tab underdetermined by one \cr
#' }
#'
#' So the gap bites only for donors spending in all four codes. For those,
#' this function returns `NA` weights with status `"underdetermined"` rather
#' than picking one point from the solution family — the same discipline used
#' throughout the package, that a number nobody has determined should not be
#' presented as a result. Adding a fourth year of published totals, from an
#' earlier edition of the report, is what resolves those donors.
#'
#' Rank deficiency has the same effect for a subtler reason: if a donor's
#' spending pattern across the codes is collinear between years, extra years
#' add no information and the system is underdetermined despite having enough
#' equations on paper.
#'
#' @section Rounding:
#' Published totals are rounded to two decimal places in millions of USD, so
#' `b` carries up to 0.005 of error per element. Because recovering \eqn{w}
#' involves inverting \eqn{A}, that error is amplified by the conditioning of
#' \eqn{A}: an ill-conditioned donor can produce wildly wrong weights from
#' correctly transcribed inputs. The returned `rounding_error_bound` is that
#' amplification made explicit — treat a bound of comparable size to the
#' weights themselves as a failed recovery, not a precise one.
#'
#' @param disbursements Numeric matrix of the donor's disbursements in the
#'   unknown-weight codes: one row per published year, one column per code,
#'   in the same units as `residual_totals`. Column names, if present, label
#'   the returned weights.
#' @param residual_totals Numeric vector, one element per year, of the
#'   published RMNCH total left unexplained by known weights. See Details.
#' @param lower,upper Bounds on a recovered weight. A weight is a share of a
#'   disbursement, so the default `[0, 1]` is a property of the quantity
#'   rather than a tuning choice.
#'
#' @return A list with components:
#' \describe{
#'   \item{weights}{Named numeric vector, one element per column of
#'     `disbursements`. `NA` where the weight is not identified.}
#'   \item{status}{Named character vector explaining each weight:
#'     `"identified"`, `"no_disbursement"` (the donor spent nothing in this
#'     code, so no weight is recoverable or needed) or `"underdetermined"`.}
#'   \item{n_years}{Number of equations used.}
#'   \item{n_unknown}{Number of codes with non-zero disbursement.}
#'   \item{rank}{Rank of the disbursement matrix restricted to those codes.}
#'   \item{condition}{Ratio of largest to smallest singular value, `Inf` if
#'     rank-deficient. Large values mean amplified rounding error.}
#'   \item{rmse}{Root mean squared residual of the fit, in the units of
#'     `residual_totals`. Zero to numerical precision when exactly
#'     determined; a large value when overdetermined is evidence that the
#'     constant-weights assumption or the inputs are wrong.}
#'   \item{rounding_error_bound}{Bound on the Euclidean error in `weights`
#'     induced by totals rounded to 0.005. `NA` when nothing is identified.}
#' }
#'
#' @keywords internal
#' @seealso [sector_weights] for the weights that are known globally.
#' @noRd
solve_donor_weights <- function(disbursements,
                                residual_totals,
                                lower = 0,
                                upper = 1) {
  if (!is.matrix(disbursements) || !is.numeric(disbursements)) {
    stop("`disbursements` must be a numeric matrix.", call. = FALSE)
  }
  if (!is.numeric(residual_totals)) {
    stop("`residual_totals` must be numeric.", call. = FALSE)
  }
  if (nrow(disbursements) != length(residual_totals)) {
    stop(
      "`disbursements` has ", nrow(disbursements), " row(s) but ",
      "`residual_totals` has ", length(residual_totals), " element(s); ",
      "there must be one row per published year.",
      call. = FALSE
    )
  }
  if (anyNA(disbursements) || anyNA(residual_totals)) {
    # An NA here would propagate into a weight that looks recovered. The
    # caller has to decide whether a missing year is dropped or filled.
    stop(
      "`disbursements` and `residual_totals` must not contain NA; ",
      "drop incomplete years before calling.",
      call. = FALSE
    )
  }
  if (!is.numeric(lower) || !is.numeric(upper) || length(lower) != 1L ||
        length(upper) != 1L || is.na(lower) || is.na(upper) || lower >= upper) {
    stop("`lower` and `upper` must be single numbers with `lower < upper`.",
         call. = FALSE)
  }

  codes <- colnames(disbursements)
  if (is.null(codes)) {
    codes <- paste0("V", seq_len(ncol(disbursements)))
  }

  weights <- stats::setNames(rep(NA_real_, length(codes)), codes)
  status <- stats::setNames(rep("no_disbursement", length(codes)), codes)

  # A code the donor never disbursed in contributes zero to every total
  # regardless of its weight, so it is neither recoverable nor needed. Keeping
  # it in the system would make the problem look harder than it is.
  active <- apply(disbursements, 2L, function(x) any(x != 0))

  out <- list(
    weights = weights,
    status = status,
    n_years = nrow(disbursements),
    n_unknown = sum(active),
    rank = 0L,
    condition = NA_real_,
    rmse = NA_real_,
    rounding_error_bound = NA_real_
  )

  if (!any(active)) {
    return(out)
  }

  a <- disbursements[, active, drop = FALSE]
  sv <- svd(a)$d
  # Relative tolerance on the singular values, scaled as R's own rank
  # decisions are, so that "small" means small relative to the largest
  # singular value rather than small in absolute disbursement units.
  tol <- max(dim(a)) * .Machine$double.eps * max(sv)
  rank <- sum(sv > tol)

  out$rank <- rank
  # Compared against the number of UNKNOWNS, not the number of singular
  # values: a matrix with fewer rows than columns yields only min(n, p)
  # singular values, all of which can be positive while the map from weights
  # to totals is still not injective. Conditioning on length(sv) would call
  # such a donor well conditioned when their weights are not recoverable at
  # all.
  out$condition <- if (rank < ncol(a)) Inf else max(sv) / min(sv)

  if (rank < sum(active)) {
    # Either too few years, or years that carry no independent information.
    # Both leave a family of solutions rather than a solution.
    out$status[active] <- "underdetermined"
    return(out)
  }

  # Bounded least squares. Solved as an optimisation rather than by a normal
  # equation because the bounds are part of the problem: an unconstrained
  # solve can return a share above 1 or below 0, which is not a weight.
  # L-BFGS-B is in base stats, so this costs no dependency.
  objective <- function(w) sum((a %*% w - residual_totals)^2)
  gradient <- function(w) as.vector(2 * crossprod(a, a %*% w - residual_totals))

  start <- tryCatch(
    pmin(pmax(qr.coef(qr(a), residual_totals), lower), upper),
    error = function(e) rep((lower + upper) / 2, ncol(a))
  )
  start[!is.finite(start)] <- (lower + upper) / 2

  fit <- stats::optim(
    par = start,
    fn = objective,
    gr = gradient,
    method = "L-BFGS-B",
    lower = lower,
    upper = upper,
    control = list(factr = 1e-12, pgtol = 0)
  )

  out$weights[active] <- fit$par
  out$status[active] <- "identified"
  out$rmse <- sqrt(sum((a %*% fit$par - residual_totals)^2) /
                     length(residual_totals))

  # Published totals are rounded to 0.005 either way. Propagated through the
  # pseudo-inverse, whose operator norm is 1 / smallest singular value, that
  # perturbs the recovered weights by at most this much in Euclidean norm.
  out$rounding_error_bound <-
    0.005 * sqrt(length(residual_totals)) / min(sv)

  out
}
