# RMNCH weights that vary by recipient and year

The RMNCH share of four CRS purpose codes is not a global constant.
Muskoka2 computes it per **recipient country and year** from open
disease-burden and government-health-expenditure data, so the weight
applied to a disbursement depends on where and when it was spent.

## Usage

``` r
rmnch_recipient_weights
```

## Format

A data frame with 728 rows and 11 columns:

- purpose_code:

  CRS five-digit purpose code, as character.

- recipient_code:

  OECD recipient code, joining to
  [crs_recipients](https://meltemod.github.io/rmnchfunding/reference/crs_recipients.md).

- recipient_name:

  Recipient name.

- year:

  Year the weight applies to.

- universe:

  Factor, always `"rmnch"` here.

- rh, mnh, ch:

  The three components, as proportions. They sum to `weight` exactly.

- weight:

  Share of the disbursement attributed to RMNCH, as a proportion in
  `[0, 1]`.

- source:

  `"own"` or which geographic group was substituted.

- source_year:

  Year the underlying data was observed.

## Source

Method: Dingle A, Schäferhoff M, Borghi J, Lewis Sabin M, Arregoces L,
Martinez-Alvarez M, Pitt C. "Estimates of aid for reproductive,
maternal, newborn, and child health: findings from application of the
Muskoka2 method, 2002-17." The Lancet Global Health 2020; 8(3):
e374-e386.
[doi:10.1016/S2214-109X(20)30005-X](https://doi.org/10.1016/S2214-109X%2820%2930005-X)
, supplementary appendix I.2 and I.3.

Values decoded from the accompanying data collection,
`Muskoka2-290120v2.xlsb` (v1.4, 24 March 2020),
[doi:10.17037/DATA.00001526](https://doi.org/10.17037/DATA.00001526) ,
CC BY-NC 3.0. Accessed 2026-07-30.

That workbook is **not redistributed with this package**: it is 187 MB
and CC BY-NC 3.0 rather than MIT. Anyone wanting to inspect the method
at source can download it from the DOI above. It is a binary `.xlsb`,
which `readxl` and `openxlsx` do not read; Python's `pyxlsb` does.
Nothing in the build depends on it.

General budget support inputs: World Bank API v2, indicators
`SH.XPD.GHED.GE.ZS` (originating from the WHO Global Health Expenditure
Database), `SP.POP.TOTL.FE.ZS`, `SP.POP.TOTL.MA.ZS`,
`SP.POP.0004.FE.5Y`, `SP.POP.0004.MA.5Y` and the seven female 5-year
bands 15-19 to 45-49. Retrieved 2026-07-30.

Disease inputs, when built: IHME Global Burden of Disease Results Tool,
<https://ghdx.healthdata.org/gbd-results-tool>, CC BY-NC 4.0.

## Details

The four codes are 12262 (malaria control), 12263 (tuberculosis
control), 13040 (STD control including HIV/AIDS) and 51010 (general
budget support-related aid). The published tables mark them `varies*`
and
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
holds them as `NA`, because a table with one weight per code cannot
express a per-recipient, per-year value.

Each weight is the sum of three components — reproductive health,
maternal and newborn health, and child health — which are kept as
separate columns so a total can be read back to its parts:

\$\$weight = RH + MNH + CH\$\$

For general budget support, with \\g\\ the government health expenditure
share, \\fem\\ and \\mal\\ the population sex shares, \\wra\\ the 15–49
share of the female population and \\u5f\\, \\u5m\\ the under-5 shares:

\$\$RH = g \times fem \times wra\$\$ \$\$MNH = 0\$\$ \$\$CH = g \times
(fem \times u5f + mal \times u5m)\$\$

## Provenance of each weight

Two columns record where a weight came from, because an observed weight,
an extrapolated one and a substituted one are otherwise
indistinguishable.

`source_year` is the year the underlying data was observed, and applies
to own-data rows. A regional substitute is a mean over group members
whose own source years may differ, so it has no single observation year
and carries `NA` rather than an invented one. Where `source_year`
differs from `year`, the value was carried forward: World Bank
health-expenditure coverage effectively stops in 2023 — 203 economies
report 2023 against 7 for 2024 — so most 2024 weights are carried.
Carrying is capped at three years, beyond which the weight is `NA`
rather than a guess.

`source` is `"own"` where the recipient has its own data, or
`"regional (subregion)"`, `"regional (region)"` or
`"regional (continent)"` where it does not and its geographic group's
figure was substituted. The narrowest available group is used.
Substitution affects recipients the sources have no record for — small
territories such as Niue and Tokelau, and OECD programmes such as the
Mekong Delta — listed with reasons in
[recipient_crosswalk](https://meltemod.github.io/rmnchfunding/reference/recipient_crosswalk.md).

## How a substituted weight is computed

The group figure is a **burden-weighted** mean of its members, weighted
by the denominator each member's ratio was taken over: all-age case
counts for the three disease codes, total population for general budget
support.

That is not an arbitrary choice. A ratio of summed cases across a group
is identically a mean of member ratios weighted by their denominators:

\$\$rac{\sum u5_i}{\sum all_i} = rac{\sum (all_i imes CH_i)}{\sum
all_i}\$\$

so weighting this way makes a substituted value equal what an aggregate
of the source data over that group would report — which is what the
published method's regional rows appear to contain. An unweighted mean
would let a country with almost no malaria pull a regional child share
as hard as one carrying tens of millions of cases. For tuberculosis in
the Caribbean the two differ by 38%.

Weighting is applied to each component separately, so `rh + mnh + ch`
still equals `weight` exactly.

## The substitution group is OECD, deliberately

The group a borrowed weight is drawn from is always an **OECD DAC**
grouping — the same hierarchy
[`crs_classify()`](https://meltemod.github.io/rmnchfunding/reference/crs_classify.md)
uses and the same one CRS disbursements are organised by. It is never a
GBD or World Bank region, even though the weights themselves are
computed from GBD and World Bank data.

This is a deliberate departure from the published method, which does the
opposite. Muskoka2's own working sheet assigns recipients that GBD does
not cover separately to a GBD *region* — Anguilla to "Caribbean", Cook
Islands to "Oceania" — and takes that region's aggregate ratio. Since a
regional aggregate is a ratio of summed cases, their substituted value
is burden-weighted, which is why this package weights the same way.

Where it differs is the group's membership. A GBD region contains every
country in it, ODA recipient or not: GBD's "Caribbean" includes Puerto
Rico. An OECD group contains only recipients, so a substituted weight is
an average over the same universe the disbursements come from.

Two further reasons for keeping the grouping OECD throughout. It avoids
carrying two different regional taxonomies inside one package, where a
recipient could sit in one region for classification and another for
imputation. And the published mapping contains at least two assignments
that contradict its own region column — Wallis and Futuna, a Pacific
territory, assigned to the Caribbean, and Mayotte, off the African
coast, assigned to Oceania — which would be inherited wholesale by
adopting it.

The cost is that substituted weights for those recipients will not
reproduce the published figures exactly. That affects 26 of 182
recipients, all small, and `source` marks every one of them.

Where every member of a group has zero burden the weights are all zero
and a weighted mean is undefined, but the answer is not: no cases
anywhere means a zero child share, and a fixed component keeps its
constant. Europe is entirely malaria-free, which is how Gibraltar and
Kosovo get a malaria weight of exactly 0.15, the MNH constant alone.

## The malaria constant is unconditional

Malaria's MNH component is 0.15 for every country and year, with no
endemicity condition — all 1,232 malaria MNH cells in the published
reference carry it. So a recipient with no recorded malaria has a weight
of exactly 0.15, the constant alone.

Zeroing the constant where there is no burden was tested against the
reference and is **worse**: agreement within 0.10 falls from 83.2% to
59.1%, because not one of the 713 zero-burden reference values falls
below 0.15. The published method never assigns a malaria weight under
the constant, so 0.15 is already below the reference there rather than
above it.

[`vignette("rmnchfunding")`](https://meltemod.github.io/rmnchfunding/articles/rmnchfunding.md)
gives the full comparison and the two lines needed to construct the
variant for a sensitivity analysis. It is documented rather than
implemented, to avoid offering a switch that would quietly break
comparability with the published series.

## Validation against the published method

The equations were re-run over 2005-2017, the overlap between the GBD
extract and the published Muskoka2 reference, and compared recipient by
recipient. Exact agreement is not expected: the reference was built from
the GBD 2017 round and World Bank data as it stood in 2018, while these
weights use GBD 2023 and current World Bank series. The check is whether
the logic reproduces the reference, with the residual attributable to
the inputs.

`ratio` is the median of ours over the reference, so 1.000 means the two
agree in level; the columns after it are the share of recipient-years
falling within that absolute distance.

|                               |      |       |                  |        |        |        |
|-------------------------------|------|-------|------------------|--------|--------|--------|
| code                          | n    | ratio | median abs. diff | \<0.01 | \<0.05 | \<0.10 |
| 51010 general budget support  | 1789 | 1.002 | 0.0024           | 83.1%  | 99.7%  | 99.9%  |
| 12263 tuberculosis            | 1872 | 0.985 | 0.0043           | 68.2%  | 96.0%  | 100.0% |
| 12262 malaria, all            | 1872 | 0.964 | 0.0245           | 35.4%  | 68.2%  | 83.2%  |
| 12262 malaria, burden present | 1159 | 1.000 | 0.0072           | 56.3%  | 90.7%  | 95.5%  |
| 13040 STD incl. HIV/AIDS      | 1872 | 1.031 | 0.0306           | 15.3%  | 69.2%  | 96.4%  |

Budget support and tuberculosis reproduce the reference closely, both
within 1.5% in level and essentially all recipient-years within 0.05.

Malaria reads worse than it is. Split by whether GBD 2023 records any
malaria at all, the 1,159 country-years with burden match the reference
in level **exactly** — median ratio 1.000, median difference 0.0072. The
remaining 713 are country-years where the 2023 round reports no malaria
but the 2017 round still did: elimination and re-estimated history, not
a disagreement about the method. There this package returns the MNH
constant alone, 0.15, against a reference median of 0.227.

STD including HIV/AIDS is the loosest of the four and should be treated
as the least certain. It is nonetheless much improved: computed from
GBD's narrow `HIV/AIDS` cause rather than the combined
`HIV/AIDS and sexually transmitted infections`, it sat at a ratio near
0.75 with 16.2% within 0.02, and the error ran one way in almost every
case. It is now 1.031, roughly symmetric — above the reference in 60% of
cases, below in 40% — with 96.4% inside 0.10 and a worst case of 0.184.
That shape, a broad symmetric cluster with a short tail, is what revised
inputs produce rather than a formula error.

A plausible reason it is the loosest: 13040 is the only code whose
weight is dominated by a **sex-and-age** ratio, the share of cases in
women aged 15-49. Malaria and tuberculosis depend only on an age ratio,
and GBD's tuberculosis age structure barely moved between rounds. HIV
and STI estimates by sex and age are among the most heavily modelled
quantities GBD produces.

What this does **not** validate is the regional substitution: recipients
that need it are largely absent from the reference's country sheets, and
the ten that do appear draw on a "Recipients & regions" mapping that is
not in the published extract. A definitive separation of method from
vintage would need a GBD 2017-round extract to run this code against the
reference's own inputs.

## Coverage

Disease weights are built from GBD 2023, which covers 1990-2023, so 2024
is carried forward from 2023. General budget support comes from World
Bank series that effectively stop in 2023 for government health
expenditure.

## See also

[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
for the codes whose weight is a global constant,
[recipient_crosswalk](https://meltemod.github.io/rmnchfunding/reference/recipient_crosswalk.md)
for how recipients map to source data.
