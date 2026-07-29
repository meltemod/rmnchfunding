# One-time development bootstrap. Run from the package root.
#
#   Rscript dev/00-setup.R
#
# Safe to re-run. This directory is .Rbuildignore'd, so nothing here reaches
# users — it exists to get a new machine (or a new collaborator) to the point
# where devtools::check() runs.
#
# It does NOT install the package's own dependencies as a side effect of
# guessing: those are declared in DESCRIPTION and installed from there.

if (!file.exists("DESCRIPTION")) {
  stop("Run this from the package root, not from dev/.", call. = FALSE)
}

repos <- "https://cloud.r-project.org"

# ---- R version ----------------------------------------------------------
# The package pins a MINOR development series, not an exact patch. Package
# binaries are not portable across minor versions (R's ABI changes, and CRAN
# ships a separate binary repository per minor release); patch releases are
# ABI-stable and safe to differ. This is a warning, not an error: a different
# series is slower, not wrong.
r_series <- paste(R.version$major,
                  strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1],
                  sep = ".")

if (r_series != "4.6") {
  warning(
    "This package is developed against R 4.6.x; you are running ",
    getRversion(), ".\n",
    "  Package installs may fall back to compiling from source.\n",
    "  If you use rig:  rig add 4.6 && rig default 4.6",
    call. = FALSE
  )
}

# ---- development tooling ------------------------------------------------
# Deliberately not listed in DESCRIPTION. Suggests: is for packages a USER
# might need (to run tests, build vignettes); devtools and roxygen2 are
# needed to develop the package, which is not the same thing, and listing
# them there would make every user install them.
tooling <- c(
  "devtools",
  "roxygen2",
  "testthat",
  "knitr",
  "rmarkdown",
  "pkgdown",
  "usethis"
)

missing <- tooling[!vapply(tooling, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  message("Installing development tooling: ", paste(missing, collapse = ", "))
  message("  (devtools pulls in a large tree; this can take several minutes)")
  install.packages(missing, repos = repos)
} else {
  message("Development tooling already present.")
}

# ---- documentation ------------------------------------------------------
# man/ and NAMESPACE are generated from the roxygen comments in R/. They are
# regenerated here rather than committed by hand so that a fresh clone cannot
# start out with documentation that disagrees with the code.
message("Generating man/ and NAMESPACE from roxygen comments ...")
roxygen2::roxygenise(load_code = roxygen2::load_source)

cat("\nSetup complete.\n",
    "  R:    ", as.character(getRversion()), "\n",
    "  Next: devtools::load_all(), then devtools::check()\n",
    sep = "")
