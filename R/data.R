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
#' not because they are unknown in principle. The donor-level weights are
#' recovered from the published per-donor RMNCH totals by
#' `solve_donor_weights()`, which needs the CRS disbursements those totals
#' were built from; until that runs there is nowhere for the numbers to live.
#' `muskoka()` must therefore refuse to compute an RMNCH total rather than
#' treat these as zero — three of the four are large CRS sectors, and a silent
#' zero would understate every donor's result.
#'
#' Four unknown weights need four independent published years. The 2025 and
#' 2026 editions cover 2021-2023 and 2022-2024 respectively, so together they
#' supply them; see [agency_weights] for why the two editions cannot be freely
#' mixed while doing so.
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
#' universe, per spending year and per report edition. Applied to a provider's
#' imputed share of an agency's outflows, these coefficients give the
#' multilateral half of a Muskoka estimate; [sector_weights] gives the
#' bilateral half.
#'
#' @format A data frame with 198 rows (11 agencies x 3 spending years x 3
#'   universes x 2 report editions) and 5 columns:
#' \describe{
#'   \item{agency}{Multilateral agency or initiative, by display name.}
#'   \item{data_year}{Integer year of the **spending**: 2021 to 2024.}
#'   \item{universe}{Factor with levels `"rmnch"`, `"srhr"`, `"fp"`.}
#'   \item{weight}{Share of agency spending attributed to the universe, as a
#'     proportion in `[0, 1]` — not a percentage.}
#'   \item{report_edition}{Integer year of the **report** that published the
#'     weight: 2025 or 2026. See Two keys, not one.}
#' }
#'
#' @section Two keys, not one:
#' Unlike [sector_weights], these coefficients are not fixed constants, and
#' they need two keys rather than one.
#'
#' `data_year` is the year of the spending. The report calculates each weight
#' as the proportion of that multilateral's own disbursements in that year
#' which benefit the universe, so an agency's weight genuinely differs between
#' 2022 and 2023 because its disbursement mix differed.
#'
#' `report_edition` is the year of the report. Each edition recomputes the
#' weights for every year it covers — including years an earlier edition
#' already published — as the underlying multilateral data is revised. These
#' revisions are substantial, not cosmetic: of the 66 agency-year-universe
#' cells published in both the 2025 and 2026 editions, 31 changed. The Asian
#' Development Bank's 2023 RMNCH weight is 5.18% in the 2025 edition and
#' 13.42% in the 2026 edition.
#'
#' Both keys are load-bearing. **Take the weights and the published totals
#' from the same edition**: pairing one edition's totals with another's
#' weights produces a figure that reproduces neither report. The editions also
#' use different price bases — 2022 constant prices in 2025, 2023 constant
#' prices in 2026 — which is a second reason not to mix them without
#' deflating.
#'
#' The two editions between them cover four spending years, 2021 to 2024,
#' which is what makes the per-donor weights behind [sector_weights]'s `NA`
#' cells recoverable at all: four years of published totals against four
#' unknown weights.
#'
#' @section IDA and family planning:
#' IDA's family-planning weight is `0` everywhere. The 2026 edition marks it
#' `0.00%*` where every other zero is written plainly, and its footnote
#' explains why (the 2025 edition carries the plain zero, so the caveat is
#' new):
#'
#' \dQuote{Currently the Donors Delivering methodology does not count IDA
#' contributions to FP. However, as the revised Muskoka applies 1% to IDA,
#' and due to the continued relevance of this multilateral contribution to
#' FP, this will be reassessed for alignment in time for the next report.}
#'
#' The zero is therefore a deliberate methodological choice, not missing
#' information, and is stored as a plain `0`. The 1% alternative is not a row
#' in this table — it belongs to the revised Muskoka method rather than to any
#' published edition — so `muskoka()` offers it as the `ida` argument instead,
#' applied at call time when `universe = "fp"`. The default is `0`, matching
#' this table and the published report.
#'
#' Expect this to change: the footnote says it is under review for the next
#' edition.
#'
#' @source Donors Delivering for SRHR Report 2026, "Selected percentages per
#'   OECD DAC codes (as under the Muskoka 2, the Donors Delivering for SRHR,
#'   and the FP methodology)", pages 110-111.
#'   \url{https://donorsdelivering.report/wp-content/uploads/2026/06/DD_Report2026_Update.pdf}
#'
#'   Donors Delivering for SRHR Report 2025, same table, pages 104-105.
#'   \url{https://donorsdelivering.report/wp-content/uploads/2025/06/DDSRHR2025.pdf}
#'
#'   The sector table is identical in both editions, so [sector_weights]
#'   carries no edition key; only the multilateral weights were revised.
#'
#' @seealso [sector_weights] for the bilateral half of the estimate.
"agency_weights"
