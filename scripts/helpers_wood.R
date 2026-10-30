# Helper functions for documentation/methods/wood-provision/index.qmd
# Load with: source("scripts/helpers_wood.R", encoding = "UTF-8")
# Each function does one small job so the document reads as a sequence of short steps.

library(dplyr)
library(tidyr)
library(terra)

# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------

#' Build a complete country-by-year series from a primary and a fallback source.
#'
#' Rule (same as the INCA plugin, `load_for_vol_efa`):
#' 1. use the primary series where it was reported ("reported");
#' 2. otherwise use the fallback series ("fallback");
#' 3. remaining gaps take the mean of the nearest earlier and later values of the
#'    same country ("interpolated"); gaps at either end repeat the nearest value
#'    ("carried").
#'
#' @param primary,fallback Long tables with columns geo, year and `value_col`.
#' @param geos,years Countries and years that the result must cover.
#' @param value_col Name of the value column in both inputs.
#' @return A tibble with geo, year, value and source (an ordered factor).
fill_series <- function(primary, fallback, geos, years, value_col = "thousand_m3") {
  source_levels <- c("reported", "fallback", "interpolated", "carried", "missing")

  expand_grid(geo = geos, year = years) |>
    left_join(
      primary |> select(geo, year, primary = all_of(value_col)),
      by = c("geo", "year")
    ) |>
    left_join(
      fallback |> select(geo, year, fallback = all_of(value_col)),
      by = c("geo", "year")
    ) |>
    mutate(
      first_pass = coalesce(primary, fallback),
      source = case_when(
        !is.na(primary) ~ "reported",
        !is.na(fallback) ~ "fallback",
        .default = NA_character_
      )
    ) |>
    arrange(geo, year) |>
    group_by(geo) |>
    mutate(
      before = first_pass,
      after = first_pass
    ) |>
    fill(before, .direction = "down") |>
    fill(after, .direction = "up") |>
    ungroup() |>
    mutate(
      value = case_when(
        !is.na(first_pass) ~ first_pass,
        !is.na(before) & !is.na(after) ~ (before + after) / 2,
        .default = coalesce(before, after)
      ),
      source = case_when(
        !is.na(source) ~ source,
        !is.na(before) & !is.na(after) ~ "interpolated",
        !is.na(value) ~ "carried",
        .default = "missing"
      ),
      source = factor(source, levels = source_levels)
    ) |>
    select(geo, year, value, source)
}

#' Compare removals with net annual increment.
#'
#' Overuse occurs when removals exceed the NAI (client instruction 2).
#'
#' @param nai,removals Tables with geo, year and value (thousand m3).
#' @return One row per country and year with the balance, the ratio and the flag.
check_overuse <- function(nai, removals) {
  nai |>
    select(geo, year, nai = value, nai_source = source) |>
    left_join(
      removals |> select(geo, year, removals = value, removals_source = source),
      by = c("geo", "year")
    ) |>
    mutate(
      balance = nai - removals,
      removals_to_nai = removals / nai,
      overuse = removals > nai,
      overuse_volume = pmax(removals - nai, 0)
    )
}

# ---------------------------------------------------------------------------
# Spatial disaggregation
# ---------------------------------------------------------------------------

#' Rasterise the country polygons on the grid of a template raster.
#'
#' @param countries A SpatVector with a character column `geo`.
#' @param template A SpatRaster that defines the grid.
#' @return A list with `raster` (integer country ids per cell) and `ids` (a tibble
#'   that links each id to its country code).
make_country_ids <- function(countries, template) {
  countries$id <- seq_len(nrow(countries))
  grid <- rasterize(countries, template, field = "id")
  list(
    raster = grid,
    ids = tibble(id = countries$id, geo = countries$geo)
  )
}

#' Sum the weights of each country once, so every year can reuse the result.
#'
#' @param weight A SpatRaster of non-negative weights.
#' @param country_ids Output of `make_country_ids()`.
#' @return A tibble with geo and weight_sum.
country_weight_sums <- function(weight, country_ids) {
  zonal(weight, country_ids$raster, fun = "sum", na.rm = TRUE) |>
    setNames(c("id", "weight_sum")) |>
    left_join(country_ids$ids, by = "id") |>
    select(geo, weight_sum)
}

#' Spread country totals over a weight raster.
#'
#' Each cell receives `total * weight / weight_sum` for its country, so the cells of
#' a country add up to the national total (conservation of the sum).
#'
#' @param totals A tibble with geo and value (the national totals).
#' @param weight A SpatRaster of weights.
#' @param country_ids Output of `make_country_ids()`.
#' @param weight_sums Output of `country_weight_sums()`.
#' @return A SpatRaster with the same units as `totals$value`.
spread_totals <- function(totals, weight, country_ids, weight_sums) {
  per_weight <- country_ids$ids |>
    left_join(weight_sums, by = "geo") |>
    left_join(totals |> select(geo, value), by = "geo") |>
    mutate(factor = if_else(weight_sum > 0, value / weight_sum, NA_real_)) |>
    filter(!is.na(factor))

  factor_raster <- classify(
    country_ids$raster,
    rcl = as.matrix(per_weight[, c("id", "factor")]),
    others = NA
  )
  weight * factor_raster
}

# ---------------------------------------------------------------------------
# Presentation and export
# ---------------------------------------------------------------------------

#' Format a data frame as a flextable that works in HTML and Word.
#'
#' @param x A data frame.
#' @param digits Decimals for numeric columns.
#' @param font_size Font size in points.
#' @return A flextable.
show_table <- function(x, digits = 1, font_size = 9) {
  flextable::flextable(x) |>
    flextable::colformat_double(digits = digits, big.mark = ",") |>
    flextable::colformat_int(big.mark = "") |>
    flextable::fontsize(size = font_size, part = "all") |>
    flextable::autofit()
}

#' Save a table as rds, csv and xlsx in one call.
#'
#' @param x A data frame.
#' @param name File name without extension.
#' @param dir Output directory.
#' @return The three file paths, invisibly.
export_table <- function(x, name, dir = "data/outputs/results") {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  paths <- file.path(dir, paste0(name, c(".rds", ".csv", ".xlsx")))
  saveRDS(x, paths[1])
  readr::write_csv(x, paths[2])
  writexl::write_xlsx(x, paths[3])
  invisible(paths)
}
