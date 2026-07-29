# Builds an exported dataset from its source, and records how.
#
#   Rscript data-raw/DATASET.R
#
# This directory is .Rbuildignore'd: it ships with the repository but not
# with the package. Users get the finished `data/*.rda`; only maintainers get
# the recipe. Keep the raw source file here too if it is small, or record
# exactly where it came from if it is not — a dataset whose provenance is
# undocumented cannot be updated by anyone but its author.

## Source: <URL or file, retrieved YYYY-MM-DD, licence>

example_data <- data.frame(
  id = 1:5,
  value = c(2, 4, 6, 8, 10)
)

# `overwrite = TRUE` because this script is expected to be re-run whenever
# the source updates. `compress = "xz"` keeps the tarball small; CRAN
# complains about data that is larger than it needs to be.
usethis::use_data(example_data, overwrite = TRUE, compress = "xz")

# Then document the dataset: create R/data.R with a roxygen block ending in
# the string "example_data", describing every column and its units.
