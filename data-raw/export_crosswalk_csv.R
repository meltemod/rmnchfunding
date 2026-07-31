# Exports inst/extdata/recipient_crosswalk.csv: the identity and imputation
# crosswalk, as a plain file users can open without R.
#
#   Rscript data-raw/export_crosswalk_csv.R
#
# Run AFTER data-raw/recipient_crosswalk.R and
# data-raw/rmnch_recipient_weights.R, since it reads both.

# ---- why a CSV as well as a dataset --------------------------------------
#
# `recipient_crosswalk` is already bundled and is what the code uses. The CSV
# exists for a different audience: someone checking the method rather than
# running it. Three questions come up repeatedly and are answered nowhere
# else in one place:
#
#   * what is this country called in each of the three source systems?
#   * does it have its own data, or is its weight borrowed?
#   * if borrowed, from which geographic group?
#
# The last two vary by purpose code — a country can have disease data but no
# health-expenditure data — so the imputation source is given per code rather
# than once per country.

crosswalk <- local({ e <- new.env(); load("data/recipient_crosswalk.rda", e)
                     get("recipient_crosswalk", e) })
weights <- local({ e <- new.env(); load("data/rmnch_recipient_weights.rda", e)
                   get("rmnch_recipient_weights", e) })

codes <- sort(unique(weights$purpose_code))

# One column per purpose code, holding how that code's weight was obtained.
# Collapsed to a single value per recipient because the source is constant
# across years for a given recipient and code; asserted rather than assumed.
src <- lapply(codes, function(pc) {
  d <- weights[weights$purpose_code == pc, ]
  s <- tapply(d$source, d$recipient_code, function(x) {
    u <- unique(x)
    if (length(u) != 1L) {
      stop("Imputation source varies across years for a recipient under code ",
           pc, "; the CSV assumes one source per recipient and code.",
           call. = FALSE)
    }
    u
  })
  s[crosswalk$recipient_code]
})
names(src) <- paste0("source_", codes)

out <- data.frame(
  crosswalk[c("recipient_code", "recipient_name", "iso3", "wb_name",
              "gbd_location_name", "continent", "continent_name",
              "region", "region_name", "subregion", "subregion_name")],
  has_worldbank_data = !is.na(crosswalk$iso3),
  has_gbd_data = !is.na(crosswalk$gbd_location_name),
  no_data_reason = crosswalk$no_data_reason,
  as.data.frame(src, check.names = FALSE),
  stringsAsFactors = FALSE
)
out <- out[order(out$recipient_name), ]

stopifnot(
  nrow(out) == nrow(crosswalk),
  !anyDuplicated(out$recipient_code),
  # Every recipient must have a recorded source for every code, or the CSV
  # would imply a gap the dataset does not have.
  !anyNA(out[paste0("source_", codes)])
)

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
utils::write.csv(out, "inst/extdata/recipient_crosswalk.csv",
                 row.names = FALSE, na = "")

message(
  "inst/extdata/recipient_crosswalk.csv: ", nrow(out), " recipients, ",
  ncol(out), " columns",
  "\n  with own World Bank data: ", sum(out$has_worldbank_data),
  "; with own GBD data: ", sum(out$has_gbd_data),
  "\n  imputed for at least one code: ",
  sum(apply(out[paste0("source_", codes)], 1L,
            function(r) any(r != "own")))
)
