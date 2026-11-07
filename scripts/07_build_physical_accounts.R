# Build the physical accounts by country: actual flow, sustainable flow and overuse.
#
# Why    : this is the calculation on tables at the base of the service, and it runs in seconds.
# Inputs : data/inputs/eurostat/for_vol_efa_thsm3.rds (script 02)
#          data/inputs/carbon_budget/cbm_nai.rds (script 03)
#          data/inputs/params/inca_part3_timber_annex.csv (script 04)
# Outputs: data/outputs/results/wood_nai_faws_country_year.rds
#          data/outputs/results/wood_overuse_country_year.rds
#          data/outputs/report/      small tables for the report
#          data/outputs/figures/wood_removals_to_nai.png
# Method : The flow is the net annual increment (NAI) of forest available for wood supply. Gaps take the estimate
#          of the carbon budget model and then the nearest values of the country. Overuse is the removals above
#          the NAI, and the sustainable flow is the removals up to the NAI. The script stops if a check fails.
# Run    : source("scripts/07_build_physical_accounts.R", encoding = "UTF-8"), from the project root.

source("scripts/helpers_common.R", encoding = "UTF-8")
source("scripts/helpers_wood.R", encoding = "UTF-8")
library(ggplot2)

eu27 <- read_eu27()
extract_all <- readRDS("data/inputs/eurostat/for_vol_efa_thsm3.rds")
cbm <- readRDS("data/inputs/carbon_budget/cbm_nai.rds")
annex <- read.csv("data/inputs/params/inca_part3_timber_annex.csv")

for_vol_efa <- filter(extract_all, geo %in% eu27)
eu_aggregate <- filter(extract_all, geo == "EU27_2020")
pick_series <- function(flow_name, class_name) filter(for_vol_efa, flow == flow_name, forest_class == class_name)

# Malta has no forest available for wood supply and no sheet in the carbon budget workbook.
no_supply <- tibble(geo = "MT", year = years_all, thousand_m3 = 0)
cbm_total <- cbm |>
  transmute(geo, year, thousand_m3 = cbm_total_forest) |>
  bind_rows(no_supply)
nai_filled <- fill_series(
  primary = pick_series("NAI", "FAWS"),
  fallback = cbm_total,
  geos = eu27, years = years_all,
  fallback_label = "carbon_budget"
) |>
  mutate(source = factor(if_else(geo == "MT", "no_supply", as.character(source))))

removals_filled <- fill_series(
  primary = pick_series("RMOV", "FAWS"),
  fallback = pick_series("RMOV", "FOR"),
  geos = eu27, years = years_all
)

overuse <- check_overuse(nai_filled, removals_filled)

# Checks, which stop the script on failure.
stopifnot(!anyNA(nai_filled$value), !anyNA(removals_filled$value), all(nai_filled$value >= 0))
accounts_check <- overuse |>
  mutate(sustainable = pmin(removals, nai))
checks <- bind_rows(
  record_check(accounts_check$sustainable + accounts_check$overuse_volume, accounts_check$removals,
               "Sustainable flow and overuse add up to removals"),
  record_check(nrow(overuse), length(eu27) * length(years_all), "One row per member state and year")
)

# Exports.
dir.create("data/outputs/results", showWarnings = FALSE, recursive = TRUE)
saveRDS(rename(nai_filled, nai_faws_1000m3 = value, nai_source = source),
        "data/outputs/results/wood_nai_faws_country_year.rds")
saveRDS(mutate(overuse, across(c(nai_source, removals_source), as.character)),
        "data/outputs/results/wood_overuse_country_year.rds")

# Small tables for the report.
save_report_table(checks, "checks_physical")

# Last year with an original value for each Member State, so what 2024 repeats is visible.
save_report_table(
  nai_filled |>
    filter(source %in% c("reported", "carbon_budget")) |>
    summarise(last_year = max(year), .by = geo) |>
    count(last_year),
  "nai_latest_year"
)

save_report_table(
  for_vol_efa |>
    filter(year %in% years_report, forest_class %in% c("FAWS", "FOR")) |>
    count(flow, forest_class, year) |>
    arrange(year) |>
    pivot_wider(names_from = year, values_from = n, values_fill = 0),
  "reporting_coverage"
)

save_report_table(
  nai_filled |>
    filter(year %in% years_report) |>
    count(year, source = as.character(source)) |>
    pivot_wider(names_from = source, values_from = n, values_fill = 0),
  "nai_sources"
)

save_report_table(
  removals_filled |>
    filter(year %in% years_report) |>
    count(year, source = as.character(source)) |>
    pivot_wider(names_from = source, values_from = n, values_fill = 0),
  "removals_sources"
)

# Candidate rules for the gaps, against the member state values printed in INCA Part III.
candidate_rules <- list(
  `Total forest reported to Eurostat` = pick_series("NAI", "FOR"),
  `Carbon budget model, total forest` = cbm_total,
  `Carbon budget model, scaled to available forest` = cbm |>
    transmute(geo, year, thousand_m3 = cbm_total_forest * share_available) |>
    bind_rows(no_supply)
)
published <- annex |>
  filter(geo != "UK", !is.na(million_m3)) |>
  transmute(geo, year, published = million_m3 * 1000)
rule_comparison <- lapply(names(candidate_rules), function(rule) {
  fill_series(pick_series("NAI", "FAWS"), candidate_rules[[rule]], eu27, years_all) |>
    inner_join(published, by = c("geo", "year")) |>
    summarise(
      eu_total = sum(value) / 1000,
      published_total = sum(published) / 1000,
      absolute_differences = sum(abs(value - published)) / 1000,
      median_difference_pct = 100 * median(abs(value / published - 1)),
      .by = year
    ) |>
    mutate(rule = rule, .before = 1)
}) |>
  bind_rows()
save_report_table(rule_comparison, "gap_rule_comparison")
save_report_table(filter(published, geo == "FR"), "published_france")

eu_series <- accounts_check |>
  filter(year %in% years_report) |>
  summarise(
    n_overuse = sum(overuse),
    overuse = sum(overuse_volume) / 1000,
    sustainable = sum(sustainable) / 1000,
    removals = sum(removals) / 1000,
    nai = sum(nai) / 1000,
    .by = year
  )
save_report_table(eu_series, "eu_series")

aggregate_wide <- eu_aggregate |>
  filter(flow == "NAI", forest_class %in% c("FAWS", "FOR"), year %in% years_report) |>
  transmute(year, forest_class, million_m3 = thousand_m3 / 1000) |>
  pivot_wider(names_from = forest_class, values_from = million_m3, names_prefix = "eurostat_")
published_totals <- published |>
  summarise(published = sum(published) / 1000, .by = year)
save_report_table(
  eu_series |>
    select(year, accounts = nai) |>
    left_join(aggregate_wide, by = "year") |>
    left_join(published_totals, by = "year"),
  "nai_against_aggregates"
)

# A change of source between two reporting years moves the series for reasons that are not ecological.
source_breaks <- nai_filled |>
  filter(year %in% years_report) |>
  arrange(geo, year) |>
  group_by(geo) |>
  mutate(previous_year = lag(year), previous_value = lag(value), previous_source = lag(as.character(source))) |>
  ungroup() |>
  filter(previous_source == "carbon_budget", source == "reported") |>
  left_join(transmute(cbm, geo, year, cbm_same_year = cbm_total_forest), by = c("geo", "year")) |>
  transmute(
    geo, previous_year, year, previous_value, value, cbm_same_year,
    change_pct = 100 * (value / previous_value - 1),
    source_gap_pct = 100 * (value / cbm_same_year - 1)
  ) |>
  arrange(desc(abs(change_pct)))
save_report_table(source_breaks, "source_breaks")

save_report_table(
  overuse |>
    filter(year %in% years_report, overuse) |>
    transmute(year, geo, nai, removals, overuse_volume, removals_to_nai,
              nai_source = as.character(nai_source), removals_source = as.character(removals_source)) |>
    arrange(year, desc(removals_to_nai)),
  "overuse_cases"
)

save_report_table(
  overuse |>
    filter(overuse) |>
    count(year),
  "overuse_all_years"
)

save_report_table(
  overuse |>
    filter(year %in% years_report) |>
    transmute(geo, year, nai, removals, sustainable = pmin(removals, nai), overuse_volume),
  "physical_by_country"
)

# Figure of the report.
figure <- overuse |>
  filter(year %in% years_report, is.finite(removals_to_nai)) |>
  mutate(geo = reorder(geo, removals_to_nai, FUN = max)) |>
  ggplot(aes(removals_to_nai, geo)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey40") +
  geom_point(size = 1.4, colour = "#2f6b4f") +
  facet_wrap(~year, nrow = 1) +
  labs(x = "Removals divided by net annual increment", y = NULL) +
  theme_minimal(base_size = 9) +
  theme(panel.grid.minor = element_blank())
save_figure(figure, "wood_removals_to_nai", width = 7.5, height = 5.5)
