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


#' CRS recipient codes: which are aggregates, which are countries
#'
#' The OECD recipient codelist is hierarchical, and this records the part of
#' that structure [oecd_crs()] needs: whether a code stands for a group of
#' recipients or for a single one.
#'
#' @details
#' A CRS query with the recipient dimension left open returns aggregates and
#' individual countries as **sibling rows**. "Developing countries", "Africa"
#' and "Kenya" all come back together, so summing the rows counts Kenya once
#' as itself, again in its region, again in its continent and again in the
#' global total. Nothing in the response marks which rows are aggregates, and
#' the resulting total can be several times the true figure. This dataset is
#' how [oecd_crs()] strips them, without a network call on every query.
#'
#' @section The hierarchy is not a tree:
#' The top level holds overlapping *analytical groupings* rather than one
#' nesting: `DPGC` (developing countries) sits beside `LLDC` (landlocked least
#' developed), `SIDS` (small island states), `FSCAC` (fragile contexts), the
#' World Bank income groups (`OLICWB`, `LMICWB`, `UMICWB`, `HICSWB`) and
#' others. A country belongs to several at once, so codes have many parents
#' and recur at different depths — one code appears six times.
#'
#' Two consequences shape this table. It is keyed by **distinct code**, since a
#' walk emitting one row per visit yields 863 rows for 290 codes. And
#' `is_aggregate` means "has children *anywhere* in the hierarchy", because a
#' code that is a leaf of one grouping may parent members of another, and must
#' still not be summed alongside them.
#'
#' @format A data frame with 290 rows and 7 columns:
#' \describe{
#'   \item{recipient_code}{OECD recipient code. Unique.}
#'   \item{recipient_name}{Official OECD name, from codelist `CL_AREA_ORG`.
#'     Bundled so that a recipient absent from a donor's data can still be
#'     labelled — see the `complete` argument of [crs_classify()].}
#'   \item{n_children}{Most children the code has in any grouping.}
#'   \item{n_appearances}{How many groupings the code appears in.}
#'   \item{min_depth}{Shallowest depth at which it appears.}
#'   \item{is_aggregate}{`TRUE` if `n_children > 0`. 39 codes are aggregates
#'     and 251 are leaves. This is what de-duplication keys on.}
#'   \item{is_unallocated}{`TRUE` for OECD's 28 `_X` buckets, which hold
#'     spending not attributable to a country. See Leaves are not countries.}
#' }
#'
#' @section Leaves are not countries:
#' OECD reports the part of a donor's spending it cannot attribute to any one
#' country in `_X` buckets: `DPGC_X` "Developing countries unspecified",
#' `F6_X` "Sub-Saharan Africa unspecified", and so on for each region. These
#' have no members, so they are leaves — correctly, because unlike a region
#' they do not overlap the countries beside them and can safely be summed
#' alongside them.
#'
#' They are nonetheless not countries, and the distinction is large rather than
#' pedantic: for the United States in 2022 they are over 40% of the
#' disbursements this package fetches. `is_unallocated` marks them so a caller
#' can sum by country without them and sum a donor total with them.
#'
#' The flag is independent of `is_aggregate`. Two `_X` codes, `INC_X` and
#' `INCWB_X`, group the countries of unspecified income classification and so
#' do have members; they are aggregates as well as unallocated.
#'
#' @source Structure from OECD hierarchical codelist `HCL_DACRECIPIENTS`
#'   version 1.5; names from codelist `CL_AREA_ORG` version 1.6, which the
#'   hierarchy declares as its source. Retrieved 2026-07-30. Rebuild with
#'   `data-raw/crs_recipients.R`.
#'
#' @seealso [oecd_crs()], whose `recipients` argument uses this.
"crs_recipients"


#' Multilateral agency to OECD channel code crosswalk
#'
#' Maps the agency names the Donors Delivering reports use, and therefore
#' [agency_weights] uses, to the OECD CRS channel codes [oecd_multi()] queries.
#'
#' @details
#' The crosswalk is explicit because matching on names would fail silently.
#' OECD's names differ from the reports' — "GAVI" is filed as "Global Alliance
#' for Vaccines and Immunization", "UNAIDS" as "Joint United Nations Programme
#' on HIV/AIDS" — and UNICEF's official name contains a U+2019 right single
#' quotation mark rather than an ASCII apostrophe. A name join would drop
#' UNICEF from every total and report nothing wrong.
#'
#' `data-raw/agency_channels.R` re-checks every code against the live OECD
#' codelist, so a retired or renamed channel fails loudly instead of quietly
#' zeroing an agency.
#'
#' @section Choices worth knowing:
#' \describe{
#'   \item{WHO maps to two codes}{OECD splits the World Health Organisation
#'     into at least four channels: 41307 assessed contributions, 41143 core
#'     voluntary contributions, 41321 preparedness plan and 41702 non-core.
#'     The report gives the WHO one weight applied to core contributions, so
#'     41307 and 41143 are summed and the non-core channels excluded. This is
#'     a choice made for the package rather than something the report states,
#'     and it affects every WHO figure.}
#'   \item{IDA is 44002 only}{The HIPC Debt Initiative Trust Fund (44003) and
#'     the Multilateral Debt Relief Initiative (44007) are debt-relief
#'     vehicles rather than IDA's concessional lending, and are excluded.}
#'   \item{Bank versus Fund}{The report names the African Development *Fund*
#'     (46003, not the Bank's 46002) but the Asian Development *Bank* (46004,
#'     not the Fund's 46005). The asymmetry is the report's and is preserved.}
#' }
#'
#' @format A data frame with 12 rows and 3 columns:
#' \describe{
#'   \item{agency}{Agency name, matching [agency_weights]`$agency`.}
#'   \item{channel_code}{OECD CRS channel code, five digits as character.}
#'   \item{channel_name}{Official OECD name, as verified against the codelist.}
#' }
#'
#' @source Channel codes and names from OECD codelist `CL_CRS_CHANNEL`,
#'   verified 2026-07-29. Agency names from [agency_weights].
#'
#' @seealso [oecd_multi()], [agency_weights].
"agency_channels"


#' CRS recipient hierarchy edges
#'
#' The parent-child edges of the OECD recipient hierarchy. This is what allows
#' a classification to be cut at a chosen level by [crs_classify()].
#'
#' @details
#' An edge list rather than a parent column on [crs_recipients], because the
#' hierarchy is not a tree: its top level holds overlapping analytical
#' groupings, so a code has several parents.
#'
#' @section One local repair:
#' OECD's codelist does not describe its own reported aggregates exactly. In
#' the published data `INC_X` ("countries unallocated by income") includes
#' `DPGC_X` ("developing countries unspecified"); in the codelist, `DPGC_X` is
#' not among `INC_X`'s children.
#'
#' The edge `INC_X -> DPGC_X` is therefore added here to match the data. It is
#' not cosmetic: without it, cutting an income classification at country level
#' descends `INC_X` through the codelist and drops `DPGC_X` entirely. For the
#' United States in 2022 that is 7,766.8 million — 32% of the donor's total —
#' and the country level would silently fail to match the tier level above it.
#' The shortfall was measured as exactly `DPGC_X`'s value.
#'
#' The edge creates no double count: `DPGC_X` is the geographic residual, and
#' an income scheme's only route to it is through `INC_X`.
#'
#' `data-raw/crs_recipient_tree.R` reports if OECD ever adds the edge itself,
#' at which point the repair becomes redundant and should be removed.
#'
#' @format A data frame with 845 rows and 2 columns:
#' \describe{
#'   \item{parent_code}{OECD recipient code of the parent.}
#'   \item{child_code}{OECD recipient code of the child.}
#' }
#'
#' @source OECD hierarchical codelist `HCL_DACRECIPIENTS` version 1.5,
#'   retrieved 2026-07-30, plus the one repair described above. Rebuild with
#'   `data-raw/crs_recipient_tree.R`.
#'
#' @seealso [crs_classify()], [crs_recipients].
"crs_recipient_tree"
