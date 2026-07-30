# Multilateral agency to OECD channel code crosswalk

Maps the agency names the Donors Delivering reports use, and therefore
[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)
uses, to the OECD CRS channel codes
[`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md)
queries.

## Usage

``` r
agency_channels
```

## Format

A data frame with 12 rows and 3 columns:

- agency:

  Agency name, matching
  [agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md)`$agency`.

- channel_code:

  OECD CRS channel code, five digits as character.

- channel_name:

  Official OECD name, as verified against the codelist.

## Source

Channel codes and names from OECD codelist `CL_CRS_CHANNEL`, verified
2026-07-29. Agency names from
[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md).

## Details

The crosswalk is explicit because matching on names would fail silently.
OECD's names differ from the reports' — "GAVI" is filed as "Global
Alliance for Vaccines and Immunization", "UNAIDS" as "Joint United
Nations Programme on HIV/AIDS" — and UNICEF's official name contains a
U+2019 right single quotation mark rather than an ASCII apostrophe. A
name join would drop UNICEF from every total and report nothing wrong.

`data-raw/agency_channels.R` re-checks every code against the live OECD
codelist, so a retired or renamed channel fails loudly instead of
quietly zeroing an agency.

## Choices worth knowing

- WHO maps to two codes:

  OECD splits the World Health Organisation into at least four channels:
  41307 assessed contributions, 41143 core voluntary contributions,
  41321 preparedness plan and 41702 non-core. The report gives the WHO
  one weight applied to core contributions, so 41307 and 41143 are
  summed and the non-core channels excluded. This is a choice made for
  the package rather than something the report states, and it affects
  every WHO figure.

- IDA is 44002 only:

  The HIPC Debt Initiative Trust Fund (44003) and the Multilateral Debt
  Relief Initiative (44007) are debt-relief vehicles rather than IDA's
  concessional lending, and are excluded.

- Bank versus Fund:

  The report names the African Development *Fund* (46003, not the
  Bank's 46002) but the Asian Development *Bank* (46004, not the Fund's
  46005). The asymmetry is the report's and is preserved.

## See also

[`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md),
[agency_weights](https://meltemod.github.io/rmnchfunding/reference/agency_weights.md).
