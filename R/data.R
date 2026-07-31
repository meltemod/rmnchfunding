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
#' @section Weights that vary by recipient and year:
#' Four of the 99 weights are `NA`, all in the RMNCH universe. The source
#' table gives these as `varies*` rather than a single figure, because the
#' RMNCH share of these sectors is set **per recipient country and year**
#' rather than globally:
#'
#' \describe{
#'   \item{12262}{Malaria control}
#'   \item{12263}{Tuberculosis control}
#'   \item{13040}{STD control including HIV/AIDS}
#'   \item{51010}{General budget support-related aid}
#' }
#'
#' They are `NA` here because a single column cannot hold a value that varies
#' by recipient and year, not because they are unknown in principle. Muskoka2
#' computes them from open disease-burden and government-health-expenditure
#' data; the results live in [rmnch_recipient_weights] and are joined to a
#' disbursement on its recipient and year.
#'
#' Only 51010 is built so far. The three disease codes need an IHME Global
#' Burden of Disease extract that cannot be fetched automatically, so
#' `muskoka(universe = "rmnch")` still refuses to compute rather than return a
#' total missing three large CRS sectors. See `data-raw/gbd/README.md`.
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
#' which is the window `muskoka()` targets and the range over which
#' [rmnch_recipient_weights] is built.
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


#' RMNCH weights that vary by recipient and year
#'
#' The RMNCH share of four CRS purpose codes is not a global constant. Muskoka2
#' computes it per **recipient country and year** from open disease-burden and
#' government-health-expenditure data, so the weight applied to a disbursement
#' depends on where and when it was spent.
#'
#' @details
#' The four codes are 12262 (malaria control), 12263 (tuberculosis control),
#' 13040 (STD control including HIV/AIDS) and 51010 (general budget
#' support-related aid). The published tables mark them `varies*` and
#' [sector_weights] holds them as `NA`, because a table with one weight per
#' code cannot express a per-recipient, per-year value.
#'
#' Each weight is the sum of three components — reproductive health, maternal
#' and newborn health, and child health — which are kept as separate columns so
#' a total can be read back to its parts:
#'
#' \deqn{weight = RH + MNH + CH}
#'
#' For general budget support, with \eqn{g} the government health expenditure
#' share, \eqn{fem} and \eqn{mal} the population sex shares, \eqn{wra} the
#' 15--49 share of the female population and \eqn{u5f}, \eqn{u5m} the under-5
#' shares:
#'
#' \deqn{RH = g \times fem \times wra}
#' \deqn{MNH = 0}
#' \deqn{CH = g \times (fem \times u5f + mal \times u5m)}
#'
#' @section Provenance of each weight:
#' Two columns record where a weight came from, because an observed weight, an
#' extrapolated one and a substituted one are otherwise indistinguishable.
#'
#' `source_year` is the year the underlying data was observed, and applies to
#' own-data rows. A regional substitute is a mean over group members whose own
#' source years may differ, so it has no single observation year and carries
#' `NA` rather than an invented one. Where `source_year` differs from `year`,
#' the value was carried forward: World Bank health-expenditure
#' coverage effectively stops in 2023 — 203 economies report 2023 against 7 for
#' 2024 — so most 2024 weights are carried. Carrying is capped at three years,
#' beyond which the weight is `NA` rather than a guess.
#'
#' `source` is `"own"` where the recipient has its own data, or
#' `"regional (subregion)"`, `"regional (region)"` or `"regional (continent)"`
#' where it does not and the mean of its geographic group was substituted. The
#' narrowest available group is used. Substitution affects recipients the World
#' Bank has no record for — small territories such as Niue and Tokelau, and
#' OECD programmes such as the Mekong Delta — listed with reasons in
#' [recipient_crosswalk].
#'
#' The mean is unweighted deliberately: the recipients needing a fallback are
#' small, and a population-weighted mean would let a group's largest member
#' stand in for a territory of a few thousand people.
#'
#' @section Validation against the published method:
#' The equations were re-run over the years the published Muskoka2 reference
#' covers and compared with it. Exact agreement is not expected: the reference
#' was built from the GBD 2017 round and World Bank data as it stood in 2018,
#' while these weights use GBD 2023 and current World Bank series. The check is
#' whether the logic reproduces the reference's structure and magnitudes.
#'
#' | Code | n | corr | median abs. diff. | within 0.02 |
#' |---|---:|---:|---:|---:|
#' | 51010 general budget support | 2195 | 0.80 | 0.0023 | 94.2% |
#' | 12263 tuberculosis | 1008 | 0.81 | 0.0045 | 80.5% |
#' | 12262 malaria | 1008 | 0.86 | 0.0249 | 42.0% |
#' | 13040 HIV/AIDS | 1008 | 0.59 | 0.0856 | 16.2% |
#'
#' General budget support and tuberculosis reproduce the reference closely.
#' Malaria is moderate. **HIV agrees least well, and the divergence sits
#' entirely in its RH component** — the reproductive-health share, which is the
#' only component of any code that is itself derived from a sex-and-age
#' ratio rather than being zero or a fixed constant.
#'
#' That was tested rather than assumed. All three plausible readings of the RH
#' formula were computed on identical rows: female 15-49 over both-sexes all
#' ages (the documented method, correlation 0.567), female all ages over
#' both-sexes all ages (0.536), and female 15-49 over both-sexes 15-49 (0.543).
#' The alternatives bring the overall scale closer to the reference but make
#' both correlation and proximity worse, so no choice of formula reconciles
#' them. The documented formula is retained.
#'
#' The most likely explanation is the GBD round: HIV prevalence by age and sex
#' was substantially revised between GBD 2017 and GBD 2023. Malaria and
#' tuberculosis pass through exactly the same code path and validate far
#' better, so the machinery is not in question. Treat HIV weights as the least
#' certain of the four, and re-check them if a future round moves again.
#'
#' @section Coverage:
#' Disease weights are built from GBD 2023, which covers 1990-2023, so 2024 is
#' carried forward from 2023. General budget support comes from World Bank
#' series that effectively stop in 2023 for government health expenditure.
#'
#' @format A data frame with 728 rows and 11 columns:
#' \describe{
#'   \item{purpose_code}{CRS five-digit purpose code, as character.}
#'   \item{recipient_code}{OECD recipient code, joining to [crs_recipients].}
#'   \item{recipient_name}{Recipient name.}
#'   \item{year}{Year the weight applies to.}
#'   \item{universe}{Factor, always `"rmnch"` here.}
#'   \item{rh, mnh, ch}{The three components, as proportions. They sum to
#'     `weight` exactly.}
#'   \item{weight}{Share of the disbursement attributed to RMNCH, as a
#'     proportion in `[0, 1]`.}
#'   \item{source}{`"own"` or which geographic group was substituted.}
#'   \item{source_year}{Year the underlying data was observed.}
#' }
#'
#' @source Method: Dingle A, Schäferhoff M, Borghi J, Lewis Sabin M, Arregoces
#'   L, Martinez-Alvarez M, Pitt C. "Estimates of aid for reproductive,
#'   maternal, newborn, and child health: findings from application of the
#'   Muskoka2 method, 2002-17." The Lancet Global Health 2020; 8(3): e374-e386.
#'   \doi{10.1016/S2214-109X(20)30005-X}, supplementary appendix I.2 and I.3.
#'
#'   Values decoded from the accompanying data collection,
#'   `Muskoka2-290120v2.xlsb` (v1.4, 24 March 2020),
#'   \doi{10.17037/DATA.00001526}, CC BY-NC 3.0.
#'
#'   General budget support inputs: World Bank API v2, indicators
#'   `SH.XPD.GHED.GE.ZS` (originating from the WHO Global Health Expenditure
#'   Database), `SP.POP.TOTL.FE.ZS`, `SP.POP.TOTL.MA.ZS`, `SP.POP.0004.FE.5Y`,
#'   `SP.POP.0004.MA.5Y` and the seven female 5-year bands 15-19 to 45-49.
#'   Retrieved 2026-07-30.
#'
#'   Disease inputs, when built: IHME Global Burden of Disease Results Tool,
#'   \url{https://ghdx.healthdata.org/gbd-results-tool}, CC BY-NC 4.0.
#'
#' @seealso [sector_weights] for the codes whose weight is a global constant,
#'   [recipient_crosswalk] for how recipients map to source data.
"rmnch_recipient_weights"


#' OECD recipients mapped to World Bank codes and geographic groups
#'
#' Joins OECD CRS recipient codes to World Bank ISO3 codes, and records each
#' recipient's continent, region and subregion. Both are needed to build
#' [rmnch_recipient_weights]: the first to reach the source data, the second to
#' substitute a regional weight where a recipient has none.
#'
#' @details
#' OECD's alphabetic recipient codes are ISO3 for almost every country, so the
#' join is on the code itself, with exceptions enumerated rather than
#' pattern-matched. Kosovo is the one genuine code difference — OECD `XKV`
#' against World Bank `XKX`.
#'
#' Twelve recipients have no World Bank record at all and carry a
#' `no_data_reason`: eight small territories outside the World Bank's economy
#' list, three OECD programmes that are not countries (East African Community,
#' Indus Basin, Mekong Delta), and Chinese Taipei. These are the recipients
#' whose weights come from a regional substitute.
#'
#' The build script fails if any recipient is neither matched nor given a
#' reason, so a gap in the weights is always a recorded decision rather than an
#' accident.
#'
#' @section What is excluded:
#' Only leaves under `DPGC` are here. That drops aggregates, the `_X`
#' unallocated buckets — which are not places and have no population to compute
#' a weight from — and the multilateral organisations that also live in OECD's
#' `CL_AREA_ORG` codelist, which covers areas *and* organisations.
#'
#' @format A data frame with 182 rows and 12 columns:
#' \describe{
#'   \item{recipient_code}{OECD recipient code.}
#'   \item{recipient_name}{OECD recipient name.}
#'   \item{iso3}{World Bank ISO3 code, or `NA` where there is no record.}
#'   \item{wb_name}{World Bank economy name, for checking the match by eye.}
#'   \item{gbd_location_name}{IHME GBD location name. GBD keys by name rather
#'     than code, so the spelling is resolved here rather than at use time.}
#'   \item{continent, region, subregion}{Geographic ancestor codes, from the
#'     same frontier logic [crs_classify()] uses.}
#'   \item{continent_name, region_name, subregion_name}{The same, as names —
#'     `F6` and `S4_S7` are not legible on their own.}
#'   \item{no_data_reason}{Why a recipient has no World Bank match, or `NA`.}
#' }
#'
#' @section Three naming systems:
#' Each source names countries differently, and none of the three is reachable
#' from another by plain string matching. Cote d'Ivoire is the sharpest case,
#' where the three spellings differ in both the accent and the apostrophe:
#'
#' \describe{
#'   \item{OECD}{"Cote" with a circumflex, and a curly (typographic)
#'     apostrophe}
#'   \item{World Bank}{"Cote" with no circumflex, and an ASCII apostrophe}
#'   \item{GBD}{"Cote" with a circumflex, and an ASCII apostrophe}
#' }
#'
#' This is why all three spellings are columns of one table rather than being
#' matched where they are used: a rename in any source then fails in the place
#' that documents the mapping, not somewhere downstream.
#'
#' @section Exported as a CSV:
#' A flat copy, with the imputation source for each purpose code added, ships
#' at `inst/extdata/recipient_crosswalk.csv` for readers checking the method
#' without running R:
#'
#' ```r
#' read.csv(system.file("extdata", "recipient_crosswalk.csv",
#'                      package = "rmnchfunding"))
#' ```
#'
#' @source OECD codes and hierarchy from [crs_recipients] and
#'   [crs_recipient_tree]; World Bank economy list from
#'   \url{https://api.worldbank.org/v2/country}, retrieved 2026-07-30.
#'
#' @seealso [rmnch_recipient_weights], [crs_recipients].
"recipient_crosswalk"
