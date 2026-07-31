# How OECD recipients map to the source data, and where borrowed weights come from

Returns the crosswalk the package uses internally: each OECD recipient
alongside its World Bank and IHME GBD identifiers, its position in the
OECD DAC geographic hierarchy, and — for the four weights that vary by
recipient and year — whether its weight is its own or borrowed from a
geographic group.

## Usage

``` r
recipient_map(purpose_code = NULL, imputed_only = FALSE)
```

## Arguments

- purpose_code:

  Optionally one CRS purpose code. Given one, the result carries a
  single `source` column for that code; given `NULL` (default), one
  `source_<code>` column per code. Must be one of the four codes whose
  weight varies by recipient: `"12262"`, `"12263"`, `"13040"`,
  `"51010"`.

- imputed_only:

  Set `TRUE` to keep only recipients whose weight is borrowed — for
  `purpose_code`, or for any code when that is `NULL`.

## Value

A tibble with one row per OECD recipient:

- recipient_code, recipient_name:

  OECD identifiers.

- iso3, wb_name:

  World Bank identifiers, `NA` if absent.

- gbd_location_name:

  IHME GBD location name, `NA` if absent.

- continent, region, subregion:

  OECD DAC hierarchy codes.

- continent_name, region_name, subregion_name:

  The same as names. `NA` where that level does not exist.

- has_worldbank_data, has_gbd_data:

  Whether the recipient appears in each source.

- no_data_reason:

  Why a recipient is absent from the World Bank list, where that is
  known.

- source or source\_:

  `"own"`, or which geographic group the weight was borrowed from.

## Details

This joins two things that are otherwise separate.
[recipient_crosswalk](https://meltemod.github.io/rmnchfunding/reference/recipient_crosswalk.md)
has the identifiers and geography but nothing about imputation;
[rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md)
records the imputation but repeats every recipient once per year and
purpose code. What a reader checking the method usually wants is one row
per recipient, which is what this returns.

The same content ships as a plain file for use outside R:

    read.csv(system.file("extdata", "recipient_crosswalk.csv",
                         package = "rmnchfunding"))

## Three naming systems

No two of the sources spell countries the same way, and none is
reachable from another by plain string matching — Cote d'Ivoire differs
between all three in both its accent and its apostrophe. That is why the
mapping is stored rather than computed at the point of use.

`iso3` is `NA` where the World Bank has no record, and
`gbd_location_name` is `NA` where GBD does not cover the recipient
separately. Those are the recipients whose weights are borrowed.

## What "borrowed" means

A recipient absent from the source data takes the unweighted mean of the
weights of the recipients in its geographic group, for the same year,
trying the narrowest group first: subregion, then region, then
continent. The `source_*` columns record which was used.

The geography is the **OECD DAC** hierarchy, not UN M49 and not the
World Bank's regions; see
[recipient_crosswalk](https://meltemod.github.io/rmnchfunding/reference/recipient_crosswalk.md)
for how they differ and why it matters. Note that the hierarchy is
ragged, so `region_name` is `NA` for the fifteen European recipients,
whose continent is not subdivided.

## See also

[recipient_crosswalk](https://meltemod.github.io/rmnchfunding/reference/recipient_crosswalk.md)
and
[rmnch_recipient_weights](https://meltemod.github.io/rmnchfunding/reference/rmnch_recipient_weights.md)
for the underlying data.

## Examples

``` r
# the whole crosswalk
recipient_map()
#> # A tibble: 182 × 18
#>    recipient_code recipient_name      iso3  wb_name  gbd_location_name continent
#>    <chr>          <chr>               <chr> <chr>    <chr>             <chr>    
#>  1 AFG            Afghanistan         AFG   Afghani… Afghanistan       S        
#>  2 ALB            Albania             ALB   Albania  Albania           E        
#>  3 DZA            Algeria             DZA   Algeria  Algeria           F        
#>  4 AGO            Angola              AGO   Angola   Angola            F        
#>  5 AIA            Anguilla            NA    NA       NA                A        
#>  6 ATG            Antigua and Barbuda ATG   Antigua… Antigua and Barb… A        
#>  7 ARG            Argentina           ARG   Argenti… Argentina         A        
#>  8 ARM            Armenia             ARM   Armenia  Armenia           S        
#>  9 ABW            Aruba               ABW   Aruba    NA                A        
#> 10 AZE            Azerbaijan          AZE   Azerbai… Azerbaijan        S        
#> # ℹ 172 more rows
#> # ℹ 12 more variables: continent_name <chr>, region <chr>, region_name <chr>,
#> #   subregion <chr>, subregion_name <chr>, no_data_reason <chr>,
#> #   has_worldbank_data <lgl>, has_gbd_data <lgl>, source_12262 <chr>,
#> #   source_12263 <chr>, source_13040 <chr>, source_51010 <chr>

# which recipients borrow a malaria weight, and from where
recipient_map("12262", imputed_only = TRUE)[
  c("recipient_name", "continent_name", "source")
]
#> # A tibble: 19 × 3
#>    recipient_name           continent_name source              
#>    <chr>                    <chr>          <chr>               
#>  1 Anguilla                 America        regional (subregion)
#>  2 Aruba                    America        regional (subregion)
#>  3 British Virgin Islands   America        regional (subregion)
#>  4 Cayman Islands           America        regional (subregion)
#>  5 East African Community   Africa         regional (subregion)
#>  6 French Polynesia         Oceania        regional (region)   
#>  7 Gibraltar                Europe         regional (continent)
#>  8 Hong Kong (China)        Asia           regional (region)   
#>  9 Indus Basin              Asia           regional (region)   
#> 10 Kosovo                   Europe         regional (continent)
#> 11 Macau (China)            Asia           regional (region)   
#> 12 Mayotte                  Africa         regional (subregion)
#> 13 Mekong Delta             Asia           regional (region)   
#> 14 Montserrat               America        regional (subregion)
#> 15 New Caledonia            Oceania        regional (region)   
#> 16 Saint Helena             Africa         regional (subregion)
#> 17 Sint Maarten             America        regional (subregion)
#> 18 Turks and Caicos Islands America        regional (subregion)
#> 19 Wallis and Futuna        Oceania        regional (region)   

# look up how one recipient is identified across the three sources
m <- recipient_map()
m[m$recipient_code == "CIV",
  c("recipient_name", "wb_name", "gbd_location_name")]
#> # A tibble: 1 × 3
#>   recipient_name wb_name       gbd_location_name
#>   <chr>          <chr>         <chr>            
#> 1 Côte d’Ivoire  Cote d'Ivoire Côte d'Ivoire    
```
