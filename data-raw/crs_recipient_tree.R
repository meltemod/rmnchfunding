# Builds `crs_recipient_tree`: the parent-child edges of the CRS recipient
# hierarchy, which is what lets a classification be cut at a chosen level.
#
#   Rscript data-raw/crs_recipient_tree.R
#
## Source: OECD hierarchical codelist HCL_DACRECIPIENTS 1.5, fetched live.

# ---- why an edge list rather than a parent column -------------------------
# The hierarchy is not a tree (see data-raw/crs_recipients.R): its top level
# holds overlapping analytical groupings, so a code has several parents. An
# edge list is the only honest shape. `crs_recipients` stays one row per code
# for the aggregate/leaf question; this holds the structure.

url <- paste0(
  "https://sdmx.oecd.org/public/rest/hierarchicalcodelist/",
  "OECD.DCD.FSD/HCL_DACRECIPIENTS/1.5?references=none"
)

message("Fetching recipient hierarchy from OECD ...")
doc <- xml2::read_xml(url)
ns <- xml2::xml_ns(doc)

edges <- new.env(parent = emptyenv())
edges$p <- character(0)
edges$c <- character(0)

walk <- function(node, parent) {
  for (hc in xml2::xml_find_all(node, "./structure:HierarchicalCode", ns)) {
    code <- xml2::xml_attr(xml2::xml_find_first(hc, ".//Ref"), "id")
    if (!is.null(parent)) {
      edges$p <- c(edges$p, parent)
      edges$c <- c(edges$c, code)
    }
    walk(hc, code)
  }
}
walk(xml2::xml_find_first(doc, ".//structure:Hierarchy", ns), NULL)

crs_recipient_tree <- unique(tibble::tibble(
  parent_code = edges$p,
  child_code  = edges$c
))

# ---- one repair, and why it is necessary ---------------------------------
#
# The codelist does not describe OECD's own reported aggregates exactly. In the
# published data, INC_X ("countries unallocated by income") includes DPGC_X
# ("developing countries unspecified"); in the codelist, DPGC_X is not among
# INC_X's 27 children.
#
# Left alone, that gap is not cosmetic. Cutting an income classification at
# country level descends INC_X into its codelist children and so drops DPGC_X
# entirely — for the United States in 2022 that is 7,766.8 million, 32% of the
# donor's total, and the level would silently fail to add up to the level above
# it. Measured: the shortfall is exactly DPGC_X's value, to the cent.
#
# The edge is therefore added to match the data rather than the codelist. It
# creates no double count, because DPGC_X is not otherwise reachable from any
# income group: it is the geographic residual, and the income scheme's only
# route to it is through INC_X.
repair <- tibble::tibble(parent_code = "INC_X", child_code = "DPGC_X")
already <- any(
  crs_recipient_tree$parent_code == "INC_X" &
    crs_recipient_tree$child_code == "DPGC_X"
)
if (already) {
  message(
    "NOTE: OECD now lists DPGC_X under INC_X; the local repair is redundant ",
    "and can be removed."
  )
} else {
  crs_recipient_tree <- rbind(crs_recipient_tree, repair)
}

crs_recipient_tree <- crs_recipient_tree[order(
  crs_recipient_tree$parent_code, crs_recipient_tree$child_code
), ]
rownames(crs_recipient_tree) <- NULL

stopifnot(
  nrow(crs_recipient_tree) > 500L,
  !anyDuplicated(crs_recipient_tree),
  # No code is its own parent, and no edge points nowhere.
  all(crs_recipient_tree$parent_code != crs_recipient_tree$child_code),
  !anyNA(crs_recipient_tree),
  # The repair must be present, since every income classification cut below
  # tier level depends on it.
  any(crs_recipient_tree$parent_code == "INC_X" &
        crs_recipient_tree$child_code == "DPGC_X"),
  # Anchors on the geographic spine.
  any(crs_recipient_tree$parent_code == "DPGC" &
        crs_recipient_tree$child_code == "F"),
  any(crs_recipient_tree$parent_code == "F" &
        crs_recipient_tree$child_code == "F6")
)

message(
  "crs_recipient_tree: ", nrow(crs_recipient_tree), " edges, ",
  length(unique(crs_recipient_tree$parent_code)), " parents, ",
  length(unique(crs_recipient_tree$child_code)), " children",
  "\n  includes 1 local repair: INC_X -> DPGC_X",
  "\n  retrieved: ", as.character(Sys.Date())
)

usethis::use_data(crs_recipient_tree, overwrite = TRUE, compress = "xz")
