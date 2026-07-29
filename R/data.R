#' Sector weights for the revised Muskoka method
#'
#' The share of a disbursement in each OECD CRS purpose code that is
#' attributed to a funding universe. These coefficients, applied to CRS
#' bilateral flows, are one half of a Muskoka estimate; [agency_weights] is
#' the other.
#'
#' @format A data frame with 99 rows (33 purpose codes x 3 universes) and 4
#'   columns:
#' \describe{
#'   \item{purpose_code}{CRS five-digit purpose code, as character. Held as
#'     text so codes are never treated as numbers and never lose a leading
#'     digit when joined against a CRS extract.}
#'   \item{purpose_name}{Purpose code description.}
#'   \item{universe}{Factor with levels `"rmnch"`, `"srhr"`, `"fp"`.}
#'   \item{weight}{Share of the disbursement attributed to the universe, as a
#'     proportion in `[0, 1]` — not a percentage. `NA` where no weight has
#'     been agreed; see Unresolved weights.}
#' }
#'
#' @section Weights that vary by donor:
#' Four of the 99 weights are `NA`, all in the RMNCH universe. The source
#' table gives these as `varies*` rather than a single figure, because the
#' RMNCH share of these sectors is set **per donor country** rather than
#' globally:
#'
#' \describe{
#'   \item{12262}{Malaria control}
#'   \item{12263}{Tuberculosis control}
#'   \item{13040}{STD control including HIV/AIDS}
#'   \item{51010}{General budget support-related aid}
#' }
#'
#' They are `NA` here because a single column cannot hold a per-donor value,
#' not because they are unknown in principle. The donor-level weights are to
#' be derived from the published per-donor RMNCH totals in Annex 3 of the
#' source report, which requires the CRS disbursements those totals were
#' built from; until that derivation exists there is nowhere for the numbers
#' to live. `muskoka()` must therefore refuse to compute an RMNCH total
#' rather than treat these as zero — three of the four are large CRS sectors,
#' and a silent zero would understate every donor's result.
#'
#' The SRHR and family-planning universes are complete and unaffected.
#'
#' @source Donors Delivering for SRHR Report 2026, "Selected percentages per
#'   OECD DAC codes (as under the Muskoka 2, the Donors Delivering for SRHR,
#'   and the FP methodology)", pages 110-111.
#'   \url{https://donorsdelivering.report/wp-content/uploads/2026/06/DD_Report2026_Update.pdf}
#'
#'   RMNCH follows the Muskoka 2 methodology developed by the London School
#'   of Hygiene and Tropical Medicine; family planning follows the revised
#'   Muskoka methodology agreed at the 2012 London Summit; SRHR follows the
#'   Donors Delivering methodology. The three overlap by construction, so
#'   their totals must not be added together.
#'
#' @seealso [agency_weights] for the multilateral half of the estimate.
"sector_weights"


#' Multilateral agency weights for the revised Muskoka method
#'
#' The share of a multilateral agency's spending attributed to a funding
#' universe, given separately for each vintage of the methodology. Applied to
#' a provider's imputed share of an agency's outflows, these coefficients
#' give the multilateral half of a Muskoka estimate; [sector_weights] gives
#' the bilateral half.
#'
#' @format A data frame with 99 rows (11 agencies x 3 vintages x 3
#'   universes) and 4 columns:
#' \describe{
#'   \item{agency}{Multilateral agency or initiative, by display name.}
#'   \item{method_year}{Integer vintage of the methodology: 2022, 2023 or
#'     2024. See Vintages.}
#'   \item{universe}{Factor with levels `"rmnch"`, `"srhr"`, `"fp"`.}
#'   \item{weight}{Share of agency spending attributed to the universe, as a
#'     proportion in `[0, 1]` — not a percentage. `NA` where no weight has
#'     been agreed; see Unresolved weights.}
#' }
#'
#' @section Vintages:
#' `method_year` is the year of the **methodology**, not of the spending it
#' is applied to. The three sets of coefficients are successive revisions of
#' the same weights, and they can move sharply between revisions — UNAIDS
#' RMNCH goes from 0.00% in 2022 to 43.80% in 2023, and the Asian Development
#' Bank nearly doubles and then reverts. Reproducing a published figure
#' therefore requires the coefficients of the vintage that produced it,
#' whichever years of data it covered, which is why old vintages are kept
#' alongside rather than replaced.
#'
#' @section IDA and family planning:
#' IDA's family-planning weight is `0` in all three vintages, and the source
#' table marks it `0.00%*` where every other zero is written plainly. The
#' footnote explains why:
#'
#' \dQuote{Currently the Donors Delivering methodology does not count IDA
#' contributions to FP. However, as the revised Muskoka applies 1% to IDA,
#' and due to the continued relevance of this multilateral contribution to
#' FP, this will be reassessed for alignment in time for the next report.}
#'
#' The zero is therefore a deliberate methodological choice, not missing
#' information, and is stored as a plain `0`. The 1% alternative is not a
#' fourth vintage in this table — it belongs to the revised Muskoka method
#' rather than to a published Donors Delivering year — so `muskoka()` offers
#' it as the `ida` argument instead, applied at call time when
#' `universe = "fp"`. The default is `0`, matching this table and the
#' published report.
#'
#' Expect this to change: the footnote says it is under review for the next
#' report.
#'
#' @source Donors Delivering for SRHR Report 2026, "Selected percentages per
#'   OECD DAC codes (as under the Muskoka 2, the Donors Delivering for SRHR,
#'   and the FP methodology)", pages 110-111.
#'   \url{https://donorsdelivering.report/wp-content/uploads/2026/06/DD_Report2026_Update.pdf}
#'
#' @seealso [sector_weights] for the bilateral half of the estimate.
"agency_weights"
