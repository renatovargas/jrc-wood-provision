# Value the physical accounts and write the results workbook.
#
# Why    : this is the calculation on tables that follows the physical accounts, and it runs in seconds.
# Inputs : data/outputs/results/wood_nai_faws_country_year.rds and wood_overuse_country_year.rds (script 07)
#          data/inputs/eurostat/for_sup_cp_p1tr.rds, for_basic_rw_exports.rds and hicp_eu27.rds (script 02)
#          data/inputs/weights/weight_by_nuts.rds (script 06)
#          data/inputs/params/inca_part3_timber_annex.csv (script 04)
# Outputs: data/outputs/results/wood_value_country_year.rds
#          data/outputs/results/wood_provision_results.xlsx, the workbook by NUTS level
#          data/outputs/report/      small tables for the report
#          data/outputs/figures/wood_unit_value.png
# Method : The unit value of the increment is the unit value of roundwood exports divided by the ratio of export
#          to timber unit values, with outliers removed and gaps filled with country and EU means. Value is the
#          physical quantity times the unit value, in current prices and in constant 2010 prices.
#          The script stops if a check fails.
# Run    : source("scripts/08_build_monetary_accounts.R", encoding = "UTF-8"), from the project root.

source("scripts/helpers_common.R", encoding = "UTF-8")
source("scripts/helpers_monetary.R", encoding = "UTF-8")
source("scripts/helpers_results.R", encoding = "UTF-8")
library(ggplot2)

# Windows of the means that fill gaps: the whole series for a country, and recent years for the EU, where
# coverage is better.
country_years <- 2000:2023
eu_years <- 2012:2023

# Member states and export points that the INCA tool removes as outliers.
tool_timber_outliers <- c("HR", "FI", "EL", "PT", "SE")
tool_export_outliers <- tibble(geo = c("DK", "EL"), year = c(2014L, 2006L))
# The price of roundwood includes harvesting and transport, so it cannot sit below the value of the standing tree.
# Among the Member States left after the tool list, no ratio falls between 13 and 1 000, so any upper bound in that
# range gives the same result.
ratio_bounds <- c(1, 100)
# An export unit value more than this many times away from the median of its country is treated as an error.
export_fold <- 3

eu27 <- read_eu27()
overuse <- readRDS("data/outputs/results/wood_overuse_country_year.rds")
nuts_weights <- readRDS("data/inputs/weights/weight_by_nuts.rds")
annex <- read.csv("data/inputs/params/inca_part3_timber_annex.csv")
hicp <- readRDS("data/inputs/eurostat/hicp_eu27.rds")
exports <- readRDS("data/inputs/eurostat/for_basic_rw_exports.rds")

nai <- readRDS("data/outputs/results/wood_nai_faws_country_year.rds") |>
  on_grid(eu27, years_all, "nai_faws_1000m3")
timber_reported <- readRDS("data/inputs/eurostat/for_sup_cp_p1tr.rds") |>
  on_grid(eu27, years_all, "value_mio_eur")

# Unit value of roundwood exports, with error points removed.
exports_all <- exports |>
  filter(geo %in% eu27) |>
  mutate(unit_value = if_else(exports_ths_m3 > 0, exports_ths_eur / exports_ths_m3, NA_real_)) |>
  group_by(geo) |>
  mutate(country_median = median(if_else(unit_value > 0, unit_value, NA_real_), na.rm = TRUE)) |>
  ungroup() |>
  mutate(
    relative = unit_value / country_median,
    removed = !is.na(unit_value) & (relative > export_fold | relative < 1 / export_fold)
  )
export_points_removed <- bind_rows(
  exports_all |> filter(removed) |> select(geo, year),
  tool_export_outliers
) |>
  distinct()

unit_value_exports <- exports_all |>
  anti_join(export_points_removed, by = c("geo", "year")) |>
  on_grid(eu27, years_all, "unit_value")

# Timber value screened step by step. The tool list comes first, so the screen by ratio sees what remains.
ratio_of <- function(timber) {
  nai |>
    rename(nai = value) |>
    left_join(rename(timber, timber = value), by = c("geo", "year")) |>
    left_join(rename(unit_value_exports, exports = value), by = c("geo", "year")) |>
    mutate(
      nai_uv = if_else(nai > 0, 1000 * timber / nai, NA_real_),
      value = exports / nai_uv,
      value = if_else(is.finite(value), value, NA_real_)
    )
}
ratio_before <- ratio_of(timber_reported)
ratio_after_list <- ratio_of(mutate(timber_reported, value = if_else(geo %in% tool_timber_outliers, NA_real_, value)))
screen <- ratio_after_list |>
  filter(!is.na(value)) |>
  summarise(n_observed = n(), median_ratio = median(value), min_ratio = min(value), max_ratio = max(value), .by = geo)
screened_out <- screen |>
  filter(median_ratio < ratio_bounds[1] | median_ratio > ratio_bounds[2]) |>
  pull(geo)

ratio_final <- ratio_of(mutate(timber_reported, value = if_else(geo %in% c(tool_timber_outliers, screened_out), NA_real_, value))) |>
  mutate(value = if_else(value < ratio_bounds[1] | value > ratio_bounds[2], NA_real_, value)) |>
  select(geo, year, value)

unit_value_exports_filled <- fill_with_means(unit_value_exports, country_years, eu_years)
ratio_filled <- fill_with_means(ratio_final, country_years, eu_years)

unit_value <- unit_value_exports_filled |>
  select(geo, year, export_uv = value) |>
  left_join(select(ratio_filled, geo, year, ratio = value, ratio_fill = fill), by = c("geo", "year")) |>
  mutate(unit_value_eur_m3 = export_uv / ratio)

deflator <- make_deflator(hicp, "hicp_2015", base_year)

monetary <- nai |>
  rename(nai_1000m3 = value) |>
  left_join(unit_value, by = c("geo", "year")) |>
  mutate(value_mio_eur_current = nai_1000m3 * unit_value_eur_m3 / 1000) |>
  left_join(deflator, by = "year") |>
  mutate(value_mio_eur_constant = value_mio_eur_current * deflator) |>
  transmute(
    geo, year, nai_1000m3,
    export_uv_eur_m3 = export_uv,
    ratio_export_to_timber = ratio,
    ratio_source = ratio_fill,
    unit_value_eur_m3, value_mio_eur_current, deflator, value_mio_eur_constant
  )

# Checks, which stop the script on failure.
stopifnot(!anyNA(monetary$value_mio_eur_current), !anyNA(monetary$value_mio_eur_constant),
          all(monetary$unit_value_eur_m3 > 0))
checks <- bind_rows(
  record_check(monetary$value_mio_eur_constant / monetary$deflator, monetary$value_mio_eur_current,
               "Constant prices return to current prices through the deflator"),
  record_check(deflator$deflator[deflator$year == base_year], 1, "The deflator equals one in the base year")
)

# Exports.
saveRDS(monetary, "data/outputs/results/wood_value_country_year.rds")

national_sources <- overuse |>
  filter(year %in% years_report) |>
  left_join(select(monetary, geo, year, ratio_source, unit_value_eur_m3), by = c("geo", "year")) |>
  transmute(geo, year, nai_source, removals_source, ratio_source, unit_value_eur_m3, removals_to_nai)
write_results_workbook(
  overuse, nuts_weights, years_report, base_year,
  path = "data/outputs/results/wood_provision_results.xlsx",
  monetary = monetary, sources = national_sources
)

# Small tables for the report.
save_report_table(checks, "checks_monetary")
save_report_table(filter(deflator, year %in% years_report), "deflators")

save_report_table(
  tibble(
    Year = years_report,
    `Timber value` = vapply(years_report, \(y) sum(!is.na(timber_reported$value[timber_reported$year == y])), integer(1)),
    `Export unit value` = vapply(years_report, \(y) sum(!is.na(unit_value_exports$value[unit_value_exports$year == y])), integer(1))
  ),
  "monetary_coverage"
)

save_report_table(
  screen |>
    mutate(treatment = case_when(geo %in% screened_out ~ "All timber values removed", .default = "Kept")) |>
    bind_rows(
      ratio_before |>
        filter(geo %in% tool_timber_outliers, !is.na(value)) |>
        summarise(n_observed = n(), median_ratio = median(value), min_ratio = min(value), max_ratio = max(value), .by = geo) |>
        mutate(treatment = "All timber values removed, as in the INCA tool")
    ) |>
    arrange(desc(median_ratio)),
  "ratio_screen"
)

save_report_table(
  ratio_filled |>
    filter(year %in% years_report) |>
    count(year, fill) |>
    pivot_wider(names_from = fill, values_from = n, values_fill = 0),
  "ratio_sources"
)

save_report_table(
  exports_all |>
    filter(geo != "MT", !is.na(unit_value), removed | paste(geo, year) %in% paste(tool_export_outliers$geo, tool_export_outliers$year)) |>
    transmute(geo, year, unit_value, country_median) |>
    arrange(geo, year),
  "export_points_removed"
)

save_report_table(
  tibble(
    eu_ratio = ratio_filled$value[ratio_filled$fill == "eu_mean"][1],
    median_screened = median(ratio_final$value, na.rm = TRUE),
    eu_ratio_uncleaned = fill_with_means(select(ratio_before, geo, year, value), country_years, eu_years) |>
      filter(fill == "eu_mean") |>
      pull(value) |>
      first(),
    uncleaned_hr_ratio = median(ratio_before$value[ratio_before$geo == "HR"], na.rm = TRUE),
    uncleaned_lt_ratio = median(ratio_before$value[ratio_before$geo == "LT"], na.rm = TRUE),
    uncleaned_be_ratio = median(ratio_before$value[ratio_before$geo == "BE"], na.rm = TRUE)
  ),
  "ratio_summary"
)

# Value of each quantity by country in the reporting years.
national_value <- overuse |>
  filter(year %in% years_report) |>
  left_join(select(monetary, geo, year, unit_value_eur_m3, deflator), by = c("geo", "year")) |>
  mutate(
    sustainable = pmin(removals, nai),
    flow_current = nai * unit_value_eur_m3 / 1000,
    flow_constant = flow_current * deflator,
    sustainable_constant = sustainable * unit_value_eur_m3 / 1000 * deflator,
    overuse_constant = overuse_volume * unit_value_eur_m3 / 1000 * deflator
  ) |>
  select(geo, year, unit_value_eur_m3, flow_current, flow_constant, sustainable_constant, overuse_constant)
save_report_table(national_value, "value_by_country")

save_report_table(
  national_value |>
    summarise(across(c(flow_current, flow_constant, sustainable_constant, overuse_constant), sum), .by = year),
  "value_eu_series"
)

save_report_table(
  national_value |>
    filter(geo != "MT") |>
    summarise(minimum = min(unit_value_eur_m3), median = median(unit_value_eur_m3),
              maximum = max(unit_value_eur_m3), highest = geo[which.max(unit_value_eur_m3)], .by = year),
  "unit_value_range"
)

published <- annex |>
  filter(geo != "UK", !is.na(million_eur)) |>
  transmute(geo, year, published = million_eur)
against_published <- national_value |>
  inner_join(published, by = c("geo", "year")) |>
  mutate(difference_pct = 100 * (flow_current / published - 1))
save_report_table(against_published |> select(geo, year, flow_current, published, difference_pct), "value_against_published")
save_report_table(
  against_published |>
    summarise(accounts = sum(flow_current), published = sum(published),
              median_difference_pct = median(abs(difference_pct)), .by = year),
  "value_against_published_eu"
)

# Figure of the report.
figure <- monetary |>
  filter(year %in% years_report, geo != "MT") |>
  mutate(
    geo = reorder(geo, unit_value_eur_m3, FUN = median),
    ratio_source = recode(ratio_source, observed = "Observed", country_mean = "Country mean", eu_mean = "EU mean")
  ) |>
  ggplot(aes(unit_value_eur_m3, geo, colour = ratio_source)) +
  geom_point(size = 1.4) +
  facet_wrap(~year, nrow = 1) +
  scale_colour_manual(values = c(Observed = "#2f6b4f", `Country mean` = "#d97a3a", `EU mean` = "#6b7f99"), name = "Ratio") +
  labs(x = "Unit value of the net annual increment (euro per m3, current prices)", y = NULL) +
  theme_minimal(base_size = 9) +
  theme(panel.grid.minor = element_blank(), legend.position = "top")
save_figure(figure, "wood_unit_value", width = 7.5, height = 5.5)
