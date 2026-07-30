# World Bank API v2 access, used to build the general-budget-support component
# of the recipient-and-year RMNCH weights. Internal; nothing here is exported.
#
# The health-expenditure series originates from the WHO Global Health
# Expenditure Database and is redistributed by the World Bank; the population
# shares are World Bank / UN Population Division. Retrieving both from one API
# keeps the package to a single extra host and avoids a WDI package dependency.

WB_HOST <- "https://api.worldbank.org/v2"

# The indicators the general budget support weight is built from. Every code
# here was verified against the live World Bank catalogue rather than assumed;
# `data-raw/rmnch_recipient_weights.R` re-verifies them on each rebuild, so a
# retired or renamed series fails loudly instead of silently dropping a term.
WB_INDICATORS <- c(
  gov_health_share = "SH.XPD.GHED.GE.ZS",  # domestic general government health
                                           # expenditure, % of general
                                           # government expenditure
  female_share     = "SP.POP.TOTL.FE.ZS",  # female, % of total population
  male_share       = "SP.POP.TOTL.MA.ZS",  # male, % of total population
  u5_female        = "SP.POP.0004.FE.5Y",  # ages 0-4, % of female population
  u5_male          = "SP.POP.0004.MA.5Y",  # ages 0-4, % of male population
  wra_1519         = "SP.POP.1519.FE.5Y",  # women of reproductive age, in
  wra_2024         = "SP.POP.2024.FE.5Y",  # 5-year bands, each as a % of the
  wra_2529         = "SP.POP.2529.FE.5Y",  # female population. Summed to give
  wra_3034         = "SP.POP.3034.FE.5Y",  # the 15-49 share.
  wra_3539         = "SP.POP.3539.FE.5Y",
  wra_4044         = "SP.POP.4044.FE.5Y",
  wra_4549         = "SP.POP.4549.FE.5Y"
)

WB_WRA_BANDS <- c("wra_1519", "wra_2024", "wra_2529", "wra_3034",
                  "wra_3539", "wra_4044", "wra_4549")

#' Fetch one World Bank indicator for all economies
#'
#' @param indicator World Bank indicator code.
#' @param start,end Year range.
#' @return A tibble of `iso3`, `year`, `value`. Values are returned as the API
#'   gives them, i.e. as PERCENTAGES; the caller divides by 100.
#' @noRd
wb_fetch <- function(indicator, start, end) {
  req <- httr2::request(paste0(
    WB_HOST, "/country/all/indicator/", indicator
  ))
  req <- httr2::req_url_query(
    req,
    format = "json",
    date = paste0(start, ":", end),
    # One page. The World Bank paginates by default and a partial first page
    # would silently truncate the panel, so the page size is set above the
    # largest possible result (about 270 economies x 25 years) and the returned
    # totals are checked below.
    per_page = 20000
  )
  req <- httr2::req_user_agent(
    req, "rmnchfunding (https://github.com/meltemod/rmnchfunding)"
  )
  req <- httr2::req_retry(req, max_tries = 4L, retry_on_failure = TRUE)
  req <- httr2::req_timeout(req, 180)

  body <- httr2::resp_body_string(httr2::req_perform(req))
  parsed <- jsonlite::fromJSON(body, simplifyVector = FALSE)

  if (length(parsed) < 2L || is.null(parsed[[2]])) {
    msg <- tryCatch(parsed[[1]]$message[[1]]$value, error = function(e) NULL)
    stop("World Bank returned no data for indicator ", indicator,
         if (!is.null(msg)) paste0(":\n  ", msg) else ".", call. = FALSE)
  }

  header <- parsed[[1]]
  rows <- parsed[[2]]
  # The header reports how many observations exist. If it disagrees with what
  # arrived, the response was paginated after all and the panel is incomplete.
  if (!is.null(header$total) && header$total != length(rows)) {
    stop("World Bank returned ", length(rows), " rows for ", indicator,
         " but reports ", header$total, " in total; the response was ",
         "paginated and the panel would be incomplete.", call. = FALSE)
  }

  tibble::tibble(
    iso3 = vapply(rows, function(x) x$countryiso3code %||% NA_character_,
                  character(1)),
    year = as.integer(vapply(rows, function(x) x$date, character(1))),
    value = vapply(rows, function(x) {
      v <- x$value
      if (is.null(v)) NA_real_ else as.numeric(v)
    }, numeric(1))
  )
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

#' Confirm an indicator still exists in the World Bank catalogue
#'
#' Called when rebuilding the weights. A World Bank series that is retired or
#' renamed would otherwise return an empty panel, and an empty panel silently
#' zeroes a term of the weight rather than failing.
#'
#' @param indicator World Bank indicator code.
#' @return The indicator's official name, invisibly.
#' @noRd
wb_check_indicator <- function(indicator) {
  req <- httr2::request(paste0(WB_HOST, "/indicator/", indicator))
  req <- httr2::req_url_query(req, format = "json")
  req <- httr2::req_timeout(req, 90)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  parsed <- jsonlite::fromJSON(
    httr2::resp_body_string(httr2::req_perform(req)), simplifyVector = FALSE
  )
  if (length(parsed) < 2L || is.null(parsed[[2]]) || length(parsed[[2]]) == 0L) {
    stop("World Bank indicator ", indicator, " is not in the catalogue; it ",
         "may have been retired or renamed.", call. = FALSE)
  }
  invisible(parsed[[2]][[1]]$name)
}
