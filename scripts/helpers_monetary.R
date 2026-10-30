# Helper functions for documentation/methods/monetary-valuation/index.qmd
# Load with: source("scripts/helpers_monetary.R", encoding = "UTF-8")
# The rules reproduce the monetary step of the INCA plugin (woodprovision/__init__.py).

library(dplyr)
library(tidyr)

#' Fill the gaps of a country-by-year value with averages.
#'
#' 1. A country with some values takes the mean of its own values over `country_years`.
#' 2. A country with no values takes the EU mean over `eu_years`: first the mean of
#'    the countries within each year, then the mean of those yearly means.
#'
#' @param x Tibble with geo, year and `value` (NA where missing).
#' @param country_years Years used for the country mean.
#' @param eu_years Years used for the EU mean.
#' @return `x` with `value` completed and a `fill` column (observed, country_mean, eu_mean).
fill_with_means <- function(x, country_years, eu_years) {
  country_mean <- x |>
    filter(year %in% country_years) |>
    summarise(country_mean = mean(value, na.rm = TRUE), .by = geo) |>
    mutate(country_mean = if_else(is.nan(country_mean), NA_real_, country_mean))

  eu_mean <- x |>
    filter(year %in% eu_years) |>
    summarise(year_mean = mean(value, na.rm = TRUE), .by = year) |>
    summarise(eu_mean = mean(year_mean, na.rm = TRUE)) |>
    pull(eu_mean)

  x |>
    left_join(country_mean, by = "geo") |>
    mutate(
      fill = case_when(
        !is.na(value) ~ "observed",
        !is.na(country_mean) ~ "country_mean",
        .default = "eu_mean"
      ),
      value = case_when(
        !is.na(value) ~ value,
        !is.na(country_mean) ~ country_mean,
        .default = eu_mean
      )
    ) |>
    select(geo, year, value, fill)
}

#' Complete country-year grid with one value column.
#'
#' @param x Tibble with geo, year and the column named in `col`.
#' @param geos,years Countries and years the result must cover.
#' @param col Name of the value column.
#' @return Tibble with geo, year and `value`.
on_grid <- function(x, geos, years, col) {
  expand_grid(geo = geos, year = years) |>
    left_join(x |> select(geo, year, value = all_of(col)), by = c("geo", "year"))
}

#' Rebase an index so that `base_year` equals 1 and return a deflator table.
#'
#' Real value (prices of `base_year`) = nominal value * deflator.
#'
#' @param hicp Tibble with year and an index column.
#' @param index_col Name of the index column.
#' @param base_year Reference year for constant prices.
#' @return Tibble with year and `deflator`.
make_deflator <- function(hicp, index_col, base_year) {
  base_value <- hicp[[index_col]][hicp$year == base_year]
  stopifnot(length(base_value) == 1)
  tibble(year = hicp$year, deflator = base_value / hicp[[index_col]])
}
