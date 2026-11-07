# Write the 1 km maps of the flow, check them against the tables and draw the map figures.
#
# Why    : the 1 km maps run in under a minute from the repository alone, so they test the key and give the figures
#          of the report. The maps at 100 m come from script 10.
# Inputs : data/inputs/weights/clc_gdmp_weight_1km_<year>.tif (script 05)
#          data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg (script 01)
#          data/outputs/results/wood_nai_faws_country_year.rds (script 07)
#          data/outputs/results/wood_value_country_year.rds (script 08)
# Outputs: refs/maps_1km/wood_nai_clc_gdmp_1km_<year>.tif            (thousand m3 per cell)
#          refs/maps_1km/wood_value_constant_clc_gdmp_1km_<year>.tif (million euro, 2010 prices, per cell)
#          data/outputs/report/checks_maps_1km.rds and maps_1km_totals.rds
#          data/outputs/figures/wood_map_nai.png and wood_map_value.png
# Method : Each cell receives the national value times its weight divided by the weight total of its country, so
#          the cells of a country add up to the national value. The script stops if a check fails.
# Run    : source("scripts/09_write_maps_1km.R", encoding = "UTF-8"), from the project root.

source("scripts/helpers_common.R", encoding = "UTF-8")
source("scripts/helpers_wood.R", encoding = "UTF-8")
library(ggplot2)
library(sf)

out_dir <- "refs/maps_1km"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
gdal_opts <- c("COMPRESS=DEFLATE", "PREDICTOR=3", "TILED=YES")

countries <- st_read("data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg", quiet = TRUE)
eu_countries <- vect("data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg")
eu_countries <- eu_countries[eu_countries$eu27, ]
nai <- readRDS("data/outputs/results/wood_nai_faws_country_year.rds")
value <- readRDS("data/outputs/results/wood_value_country_year.rds")

weights <- lapply(years_report, \(y) rast(sprintf("data/inputs/weights/clc_gdmp_weight_1km_%s.tif", y)))
names(weights) <- years_report
country_ids <- make_country_ids(eu_countries, weights[[1]])
weight_sums <- lapply(weights, country_weight_sums, country_ids = country_ids)

for (yr in years_report) {
  key <- as.character(yr)
  flow_map <- spread_totals(
    totals = nai |> filter(year == yr) |> transmute(geo, value = nai_faws_1000m3),
    weight = weights[[key]], country_ids = country_ids, weight_sums = weight_sums[[key]]
  )
  names(flow_map) <- paste0("nai_clc_gdmp_", yr)
  writeRaster(flow_map, file.path(out_dir, sprintf("wood_nai_clc_gdmp_1km_%s.tif", yr)),
              overwrite = TRUE, datatype = "FLT4S", gdal = gdal_opts)

  value_map <- spread_totals(
    totals = value |> filter(year == yr) |> transmute(geo, value = value_mio_eur_constant),
    weight = weights[[key]], country_ids = country_ids, weight_sums = weight_sums[[key]]
  )
  names(value_map) <- paste0("value_constant_", yr)
  writeRaster(value_map, file.path(out_dir, sprintf("wood_value_constant_clc_gdmp_1km_%s.tif", yr)),
              overwrite = TRUE, datatype = "FLT4S", gdal = gdal_opts)
}

# The checks read the maps back from disk, so they test the files themselves.
nai_maps <- rast(file.path(out_dir, sprintf("wood_nai_clc_gdmp_1km_%s.tif", years_report)))
value_maps <- rast(file.path(out_dir, sprintf("wood_value_constant_clc_gdmp_1km_%s.tif", years_report)))
totals <- tibble(
  year = years_report,
  nai_map = global(nai_maps, "sum", na.rm = TRUE)[[1]] / 1000,
  nai_table = vapply(years_report, \(y) sum(nai$nai_faws_1000m3[nai$year == y]) / 1000, numeric(1)),
  value_map = global(value_maps, "sum", na.rm = TRUE)[[1]],
  value_table = vapply(years_report, \(y) sum(value$value_mio_eur_constant[value$year == y]), numeric(1))
)

lost <- lapply(names(weight_sums), \(y) mutate(weight_sums[[y]], year = as.integer(y))) |>
  bind_rows() |>
  right_join(nai |> filter(year %in% years_report), by = c("geo", "year")) |>
  filter((is.na(weight_sum) | weight_sum <= 0) & nai_faws_1000m3 > 0)
if (nrow(lost) > 0) stop("Countries with a national value and no forest weight: ", paste(unique(lost$geo), collapse = ", "))

save_report_table(totals, "maps_1km_totals")
save_report_table(
  bind_rows(
    record_check(totals$nai_map, totals$nai_table, "1 km maps of the flow against the national tables", tolerance = 1e-4),
    record_check(totals$value_map, totals$value_table, "1 km maps of the value against the national tables", tolerance = 1e-4)
  ),
  "checks_maps_1km"
)

# Figures of the report, drawn at 10 km, where each cell is the sum of 100 cells of 1 km.
map_figure <- function(maps, prefix, legend) {
  cells <- aggregate(maps, fact = 10, fun = "sum", na.rm = TRUE) |>
    as.data.frame(xy = TRUE) |>
    pivot_longer(starts_with(prefix), names_to = "year", values_to = "amount") |>
    mutate(year = sub(prefix, "", year)) |>
    filter(amount > 0)
  ggplot(cells) +
    geom_tile(aes(x, y, fill = amount)) +
    geom_sf(data = countries, fill = NA, linewidth = 0.1) +
    scale_fill_viridis_c(transform = "sqrt", name = legend) +
    facet_wrap(~year, ncol = 3) +
    coord_sf(xlim = c(2.6e6, 6.6e6), ylim = c(1.4e6, 5.4e6), datum = NA) +
    theme_void(base_size = 9)
}
save_figure(map_figure(nai_maps, "nai_clc_gdmp_", "Thousand m3\nper 10 km cell"), "wood_map_nai", width = 7.5, height = 5.5)
save_figure(map_figure(value_maps, "value_constant_", "Million euro\n(2010 prices)\nper 10 km cell"), "wood_map_value", width = 7.5, height = 5.5)
