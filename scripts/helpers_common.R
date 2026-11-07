# Helper functions and constants shared by the numbered scripts.
# Load with: source("scripts/helpers_common.R", encoding = "UTF-8")

library(dplyr)
library(tidyr)

years_all <- 2000:2024
years_report <- c(2000, 2006, 2012, 2018, 2024)
base_year <- 2010

#' Country codes of the EU27 in Eurostat convention.
read_eu27 <- function() {
  countries <- sf::st_read("data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg", quiet = TRUE)
  countries$geo[countries$eu27]
}

#' Save a small table that the report reads.
#'
#' @param x A data frame.
#' @param name File name without extension.
#' @param dir Output directory.
#' @return `x`, invisibly.
save_report_table <- function(x, name, dir = "data/outputs/report") {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  saveRDS(x, file.path(dir, paste0(name, ".rds")))
  invisible(x)
}

#' Run a check that two sets of numbers agree, stop on failure, and return a row for the report.
#'
#' @param a,b Numbers that should agree.
#' @param label Description of the check.
#' @param tolerance Largest relative gap allowed.
#' @return A one-row tibble with the check, its largest relative gap and its tolerance.
record_check <- function(a, b, label, tolerance = 1e-6) {
  gap <- max(abs(a - b) / pmax(abs(b), 1e-9), na.rm = TRUE)
  if (gap > tolerance) stop("Check failed: ", label, ". Largest relative gap ", signif(gap, 3))
  tibble::tibble(check = label, largest_gap = gap, tolerance = tolerance)
}

#' Save a figure of the report.
save_figure <- function(plot, name, width = 7, height = 6) {
  dir.create("data/outputs/figures", showWarnings = FALSE, recursive = TRUE)
  ggplot2::ggsave(file.path("data/outputs/figures", paste0(name, ".png")), plot,
                  width = width, height = height, dpi = 200, bg = "white")
}

#' National values of each 100 m map, in the unit of the map.
#'
#' @param overuse Table from script 07.
#' @param value Table from script 08.
#' @param years Years to return.
#' @return Long table with geo, year, quantity and total.
national_map_values <- function(overuse, value, years) {
  overuse |>
    filter(year %in% years) |>
    left_join(select(value, geo, year, unit_value_eur_m3, deflator), by = c("geo", "year")) |>
    mutate(
      sustainable = pmin(removals, nai),
      # A thousand m3 at a unit value in euro per m3, in cents at 2010 prices.
      cents_per_1000m3 = unit_value_eur_m3 * 1000 * deflator * 100,
      flow_dm3 = nai * 1e6,
      sustainable_dm3 = sustainable * 1e6,
      overuse_dm3 = overuse_volume * 1e6,
      flow_eurocent2010 = nai * cents_per_1000m3,
      sustainable_eurocent2010 = sustainable * cents_per_1000m3,
      overuse_eurocent2010 = overuse_volume * cents_per_1000m3
    ) |>
    select(geo, year, flow_dm3:overuse_eurocent2010) |>
    pivot_longer(-c(geo, year), names_to = "quantity", values_to = "total")
}
