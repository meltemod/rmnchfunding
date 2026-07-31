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
CC BY-NC 3.0.

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
`"regional (continent)"` where it does not and the mean of its
geographic group was substituted. The narrowest available group is used.
Substitution affects recipients the World Bank has no record for — small
territories such as Niue and Tokelau, and OECD programmes such as the
Mekong Delta — listed with reasons in
[recipient_crosswalk](https://meltemod.github.io/rmnchfunding/reference/recipient_crosswalk.md).

The mean is unweighted deliberately: the recipients needing a fallback
are small, and a population-weighted mean would let a group's largest
member stand in for a territory of a few thousand people.

## Validation against the published method

The equations were re-run over the years the published Muskoka2
reference covers and compared with it. Exact agreement is not expected:
the reference was built from the GBD 2017 round and World Bank data as
it stood in 2018, while these weights use GBD 2023 and current World
Bank series. The check is whether the logic reproduces the reference's
structure and magnitudes.

|                              |      |      |                   |             |
|------------------------------|------|------|-------------------|-------------|
| Code                         | n    | corr | median abs. diff. | within 0.02 |
| 51010 general budget support | 2195 | 0.80 | 0.0023            | 94.2%       |
| 12263 tuberculosis           | 1008 | 0.81 | 0.0045            | 80.5%       |
| 12262 malaria                | 1008 | 0.86 | 0.0249            | 42.0%       |
| 13040 HIV/AIDS               | 1008 | 0.59 | 0.0856            | 16.2%       |

General budget support and tuberculosis reproduce the reference closely.
Malaria is moderate. **HIV agrees least well, and the divergence sits
entirely in its RH component** — the reproductive-health share, which is
the only component of any code that is itself derived from a sex-and-age
ratio rather than being zero or a fixed constant.

That was tested rather than assumed. All three plausible readings of the
RH formula were computed on identical rows: female 15-49 over both-sexes
all ages (the documented method, correlation 0.567), female all ages
over both-sexes all ages (0.536), and female 15-49 over both-sexes 15-49
(0.543). The alternatives bring the overall scale closer to the
reference but make both correlation and proximity worse, so no choice of
formula reconciles them. The documented formula is retained.

The most likely explanation is the GBD round: HIV prevalence by age and
sex was substantially revised between GBD 2017 and GBD 2023. Malaria and
tuberculosis pass through exactly the same code path and validate far
better, so the machinery is not in question. Treat HIV weights as the
least certain of the four, and re-check them if a future round moves
again.

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
