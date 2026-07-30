# Builds `crs_recipients`: which CRS recipient codes are aggregates, which are
# individual countries. This is what makes it possible to sum bilateral
# disbursements without double counting.
#
#   Rscript data-raw/crs_recipients.R
#
## Source: OECD hierarchical codelist HCL_DACRECIPIENTS 1.5, fetched live
## below. Retrieval date is recorded in the message this script prints; the
## dataset is rebuilt by re-running it.

# ---- why this dataset exists ---------------------------------------------
#
# A CRS query with the recipient dimension left open returns aggregates and
# individual countries in the SAME response, as sibling rows: "Developing
# countries" appears alongside "Africa", which appears alongside "Kenya".
# Summing the rows counts Kenya once as itself, again inside its region,
# again inside its continent and again inside the global total. Nothing in
# the response marks which rows are aggregates, so the sum is wrong by a
# large and silent factor.
#
# The recipient codelist is hierarchical, so the distinction is recoverable:
# a code that has children is an aggregate. Bundling that means `oecd_crs()`
# can drop aggregates without a network call on every query.
#
# ---- the hierarchy is NOT a tree -----------------------------------------
#
# Its top level holds overlapping ANALYTICAL GROUPINGS, not one nesting:
# DPGC (developing countries) sits beside LLDC (landlocked least developed),
# SIDS (small island states), FSCAC (fragile contexts), the World Bank income
# groups (OLICWB, LMICWB, UMICWB, HICSWB) and others. A country appears under
# several of them at once, so a code has many parents and the same code
# recurs at different depths in different groupings.
#
# Two consequences, both load-bearing:
#
#   * There is no single `parent_code`, and a walk that emits one row per
#     visit counts codes repeatedly. This dataset is keyed by DISTINCT code.
#   * "Aggregate" must mean "has children ANYWHERE in the hierarchy", not
#     "has children in its own branch". A code that is a leaf of one grouping
#     and a parent in another is still an aggregate and must not be summed
#     alongside its members.

url <- paste0(
  "https://sdmx.oecd.org/public/rest/hierarchicalcodelist/",
  "OECD.DCD.FSD/HCL_DACRECIPIENTS/1.5?references=none"
)

message("Fetching recipient hierarchy from OECD ...")
doc <- xml2::read_xml(url)
ns <- xml2::xml_ns(doc)

# Every visit to a code, with how many children it had at that visit. One
# code can appear many times; that is collapsed below.
visits <- new.env(parent = emptyenv())
visits$rows <- list()

walk <- function(node, depth) {
  for (hc in xml2::xml_find_all(node, "./structure:HierarchicalCode", ns)) {
    code <- xml2::xml_attr(xml2::xml_find_first(hc, ".//Ref"), "id")
    kids <- xml2::xml_find_all(hc, "./structure:HierarchicalCode", ns)
    visits$rows[[length(visits$rows) + 1L]] <- list(
      code = code, n_children = length(kids), depth = depth
    )
    if (length(kids) > 0L) walk(hc, depth + 1L)
  }
}

hier <- xml2::xml_find_first(doc, ".//structure:Hierarchy", ns)
if (is.na(hier)) stop("No Hierarchy element found; has the codelist moved?")
walk(hier, 0L)

code <- vapply(visits$rows, `[[`, character(1), "code")
nkid <- vapply(visits$rows, `[[`, integer(1), "n_children")
dep <- vapply(visits$rows, `[[`, integer(1), "depth")

codes <- sort(unique(code))
crs_recipients <- tibble::tibble(
  recipient_code = codes,
  # Max over visits: a code counts as an aggregate if it parents members in
  # ANY grouping, so the maximum is the right collapse, not the first or the
  # minimum.
  n_children     = vapply(codes, function(k) max(nkid[code == k]), integer(1)),
  n_appearances  = vapply(codes, function(k) sum(code == k), integer(1)),
  min_depth      = vapply(codes, function(k) min(dep[code == k]), integer(1))
)
crs_recipients$is_aggregate <- crs_recipients$n_children > 0L

# ---- leaves that are not countries ---------------------------------------
# A leaf is not the same thing as a country. OECD suffixes unallocated buckets
# with `_X`: DPGC_X "Developing countries unspecified", F6_X "Sub-Saharan
# Africa unspecified", and so on for every region. These have no children, so
# the aggregate test treats them as leaves — correctly, because they do NOT
# double count against their members: they hold precisely the spending that
# could not be attributed to a country.
#
# So they must stay in a total, but they are not countries, and the difference
# is not marginal: for the United States in 2022 they are over 40% of the
# disbursements this package fetches. Flagged rather than dropped, so a caller
# summing by country knows what is and is not attributable.
#
# The flag is descriptive and independent of `is_aggregate`: two `_X` codes,
# INC_X and INCWB_X, group the countries of unspecified income classification
# and so do have members. Dedup keys on `is_aggregate` alone; this flag only
# says whether a row's spending is attributable to a country.
crs_recipients$is_unallocated <- grepl("_X$", crs_recipients$recipient_code)

# ---- names ----------------------------------------------------------------
# Names come from CL_AREA_ORG, the codelist the hierarchy declares as its
# source (the hierarchy itself carries only code references). They are bundled
# so that a recipient absent from a donor's data can still be labelled: a
# zero-filled row with no name is far less useful than one that says which
# country reported nothing.
message("Fetching recipient names from CL_AREA_ORG ...")
cl <- xml2::read_xml(paste0(
  "https://sdmx.oecd.org/public/rest/codelist/OECD.DCD.FSD/CL_AREA_ORG/1.6"
))
cl_ns <- xml2::xml_ns(cl)
cl_nodes <- xml2::xml_find_all(cl, ".//structure:Code", cl_ns)
nm <- stats::setNames(
  vapply(cl_nodes, function(n) {
    xml2::xml_text(xml2::xml_find_first(n, "./common:Name", cl_ns))
  }, character(1)),
  vapply(cl_nodes, xml2::xml_attr, character(1), "id")
)
crs_recipients$recipient_name <- unname(nm[crs_recipients$recipient_code])

crs_recipients <- crs_recipients[c(
  "recipient_code", "recipient_name", "n_children", "n_appearances",
  "min_depth", "is_aggregate", "is_unallocated"
)]
rownames(crs_recipients) <- NULL

stopifnot(
  # Keyed by distinct code — the property the whole dataset depends on.
  !anyDuplicated(crs_recipients$recipient_code),
  nrow(crs_recipients) > 200L,
  any(crs_recipients$is_aggregate),
  any(!crs_recipients$is_aggregate),
  # Known anchors. DPGC is the developing-countries root and must be an
  # aggregate; a few well-known countries must be leaves. If OECD restructures
  # the codelist such that these flip, the dedup rule needs re-examining
  # rather than silently changing behaviour.
  crs_recipients$is_aggregate[crs_recipients$recipient_code == "DPGC"],
  all(!crs_recipients$is_aggregate[
    crs_recipients$recipient_code %in% c("KEN", "IND", "ETH", "BGD")
  ]),
  # The overlap is real, not an artefact: some codes appear more than once.
  any(crs_recipients$n_appearances > 1L),
  # Almost every `_X` bucket is a leaf, but two are not: INC_X and INCWB_X
  # group the countries whose income classification is unspecified, so they
  # have members and are genuine aggregates. Pinned by name rather than
  # forbidden, so a third one appearing is caught here instead of quietly
  # entering a "countries" result and double counting against its members.
  # Set comparison, not sorted: collation of "_" against letters is
  # locale-dependent, so a sorted comparison passes or fails by locale.
  setequal(
    crs_recipients$recipient_code[
      crs_recipients$is_unallocated & crs_recipients$is_aggregate
    ],
    c("INC_X", "INCWB_X")
  ),
  crs_recipients$is_unallocated[crs_recipients$recipient_code == "DPGC_X"],
  !crs_recipients$is_unallocated[crs_recipients$recipient_code == "KEN"],
  # Every code must be named, or a zero-filled row would carry NA where a
  # country name belongs.
  !anyNA(crs_recipients$recipient_name),
  crs_recipients$recipient_name[crs_recipients$recipient_code == "KEN"] == "Kenya"
)

message(
  "crs_recipients: ", nrow(crs_recipients), " distinct codes, ",
  sum(crs_recipients$is_aggregate), " aggregates, ",
  sum(!crs_recipients$is_aggregate), " leaves (of which ",
  sum(crs_recipients$is_unallocated), " unallocated \"_X\" buckets)",
  "\n  total visits across overlapping groupings: ", length(code),
  " (max appearances for one code: ", max(crs_recipients$n_appearances), ")",
  "\n  all ", nrow(crs_recipients), " named from CL_AREA_ORG",
  "\n  retrieved: ", as.character(Sys.Date())
)

usethis::use_data(crs_recipients, overwrite = TRUE, compress = "xz")
