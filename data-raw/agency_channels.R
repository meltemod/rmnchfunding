# Builds `agency_channels`: the crosswalk from the multilateral agency names
# used by the Donors Delivering reports to OECD CRS channel codes.
#
#   Rscript data-raw/agency_channels.R
#
## Source: agency names from `agency_weights`; channel codes and official
## names from the OECD codelist CL_CRS_CHANNEL, fetched live below to verify
## that every code still exists and still carries the name recorded here.

library(tibble)

# ---- why a crosswalk, and why it is not a join on names ------------------
#
# `agency_weights` names agencies as the report prints them. OECD names them
# differently, and matching on the strings at run time would fail silently:
#
#   report "GAVI"           OECD "Global Alliance for Vaccines and Immunization"
#   report "UNAIDS"         OECD "Joint United Nations Programme on HIV/AIDS"
#   report "UNICEF"         OECD "United Nations Children's Fund"
#
# The UNICEF name is the sharpest case: OECD writes it with U+2019 RIGHT
# SINGLE QUOTATION MARK, not an ASCII apostrophe. A name join would drop
# UNICEF from every total and report nothing wrong. Hence explicit codes,
# checked against the live codelist by this script.
#
# ---- one agency, several channel codes -----------------------------------
#
# The mapping is one-to-many, which is why this is its own table rather than
# a column on `agency_weights`.

agency_channels <- tribble(
  ~agency,                     ~channel_code, ~channel_name,
  "GAVI",                             "47122", "Global Alliance for Vaccines and Immunization",
  "Global Fund",                      "47045", "Global Fund to Fight AIDS, Tuberculosis and Malaria",
  "IDA",                              "44002", "International Development Association",
  "UNFPA",                            "41119", "United Nations Population Fund",
  "UNICEF",                           "41122", "United Nations Children’s Fund",
  "UNAIDS",                           "41110", "Joint United Nations Programme on HIV/AIDS",
  "UNRWA",                            "41130", "United Nations Relief and Works Agency for Palestine Refugees in the Near East",
  "World Food Programme",             "41140", "World Food Programme",
  "World Health Organisation",        "41307", "World Health Organisation - assessed contributions",
  "World Health Organisation",        "41143", "World Health Organisation - core voluntary contributions account",
  "Asian Development Bank",           "46004", "Asian Development Bank",
  "African Development Fund",         "46003", "African Development Fund"
)

# ---- decisions recorded --------------------------------------------------
#
# WHO — two codes, deliberately. OECD splits the WHO into at least four
#   channels: 41307 assessed contributions, 41143 core voluntary
#   contributions account, 41321 Strategic Preparedness and Response Plan and
#   41702 non-core. The report gives the WHO a single weight applied to core
#   contributions, so the two core channels (41307 + 41143) are summed and
#   the non-core ones excluded. This is a methodological choice made for the
#   package, not something the report states; it materially affects every WHO
#   figure and should be revisited if the report ever specifies otherwise.
#
# IDA — 44002 only. OECD also lists 44003 (Heavily Indebted Poor Countries
#   Debt Initiative Trust Fund) and 44007 (Multilateral Debt Relief
#   Initiative). Those are debt-relief vehicles rather than IDA's own
#   concessional lending, and are excluded.
#
# African Development Fund is 46003, NOT the African Development Bank
#   (46002); the report names the Fund. Likewise the Asian Development BANK
#   is 46004, not the Asian Development Fund (46005) — the report names the
#   Bank there. The asymmetry is the report's, and is preserved rather than
#   tidied.

stopifnot(
  !anyDuplicated(agency_channels$channel_code),
  all(grepl("^[0-9]{5}$", agency_channels$channel_code)),
  # Only the WHO is expected to map to more than one channel. A second
  # multi-code agency appearing here should be a deliberate edit.
  {
    multi <- names(which(table(agency_channels$agency) > 1L))
    identical(multi, "World Health Organisation")
  }
)

# ---- verify against the live OECD codelist -------------------------------
# The point is not to fetch the names but to fail if a code has disappeared
# or been renamed under us. A silently retired channel code would quietly
# zero out an agency's multilateral contribution.
message("Verifying channel codes against OECD CL_CRS_CHANNEL ...")
doc <- xml2::read_xml(paste0(
  "https://sdmx.oecd.org/dcd-public/rest/codelist/",
  "OECD.DCD.FSD/CL_CRS_CHANNEL/latest"
))
ns <- xml2::xml_ns(doc)
live_nodes <- xml2::xml_find_all(doc, ".//structure:Code", ns)
live <- stats::setNames(
  vapply(live_nodes, function(n) {
    xml2::xml_text(xml2::xml_find_first(n, "./common:Name", ns))
  }, character(1)),
  vapply(live_nodes, xml2::xml_attr, character(1), "id")
)

missing <- setdiff(agency_channels$channel_code, names(live))
if (length(missing) > 0L) {
  stop("Channel codes no longer in the OECD codelist: ",
       paste(missing, collapse = ", "), call. = FALSE)
}
renamed <- agency_channels[live[agency_channels$channel_code] !=
                             agency_channels$channel_name, ]
if (nrow(renamed) > 0L) {
  warning(
    "OECD has renamed ", nrow(renamed), " channel(s). Update channel_name:\n",
    paste0("  ", renamed$channel_code, ": ",
           live[renamed$channel_code], collapse = "\n"),
    call. = FALSE
  )
}

message(
  "agency_channels: ", nrow(agency_channels), " codes for ",
  length(unique(agency_channels$agency)), " agencies",
  " (all verified against ", length(live), " live channel codes)"
)

usethis::use_data(agency_channels, overwrite = TRUE, compress = "xz")
