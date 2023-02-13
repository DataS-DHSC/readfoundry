
<!-- README.md is generated from README.Rmd. Please edit that file -->

# readfoundry

readfoundry provides a simple wrapper to Foundry to aid in the
development of RAPs within DHSC.

readfoundry can be used to either run raw SparkSQL on the Foundry SQL
server or can be used with `dbplyr` to enable generation of SQL.

## Installation

You can install the development version of readfoundry like so:

``` r
remotes::install_github("DataS-DHSC/readfoundry")
```

## Usage

To use the package you will need the path to the dataset you want to
query as well as a BEARER token from your Foundry session that has
permission to export this dataset. This token can then be saved in your
projects `.Renviron` file under the key “BEARER” (see examples below).

To then run raw SQL call:

``` r
fapi <- readfoundry::FoundryReader$new(Sys.getenv("BEARER"))

sql_query <- 
  paste(
    "SELECT",
    "*",
    "FROM \"/path/to/dataset\"",
    "WHERE metric_name IN ('example', 'metric', 'names')"
  )
  
df <- fapi$run_query(sql_query)
```

To use the `dbplyr` wrapper start your pipe chain with a call to
`fapi$get_dataset("path/to/dataset")` and when you have finished
transforming your data collect the results by calling `fapi$collect()`,
e.g.:

``` r
fapi <- readfoundry::FoundryReader$new(Sys.getenv("BEARER"))

df <- fapi$get_dataset("path/to/dataset") %>%
  filter(metric_name == "example_name") %>%
  fapi$collect()
```

### Notes

SparkSQL uses single quotes for values with the exception of double
quotes around dataset path. Back ticks are also not supported for
variable names.

For more info on the SQL functions available see [Palantir Spark SQL
Reference](https://www.palantir.com/docs/foundry/transforms-sql/spark-reference/)

To change the log level of the wrapper use:

``` r
futile.logger::flog.threshold(
  futile.logger::INFO,
  name = fapi$get_log_name()
)
```
