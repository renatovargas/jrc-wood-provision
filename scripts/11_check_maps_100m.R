# Check every 100 m map against the national tables.
#
# Why    : the maps live outside the repository, so reading them back is the only proof that they hold the accounts.
# Inputs : refs/maps_100m/wood_<quantity>_100m_<year>.tif (script 10)
#          data/outputs/results/wood_overuse_country_year.rds (script 07)
#          data/outputs/results/wood_value_country_year.rds (script 08)
# Outputs: data/outputs/report/maps_100m_totals.rds, EU27 totals of each map against the tables
#          data/outputs/report/checks_maps_100m.rds, with the largest gap by country
# Method : Sums the cells of each country in each map and compares the sum with the national value. Whole numbers
#          round the smallest cells, so the tolerance is one part in a thousand by country. The script stops
#          if a check fails.
# Run    : source("scripts/11_check_maps_100m.R", encoding = "UTF-8"), from the project root.

source("scripts/helpers_common.R", encoding = "UTF-8")
source("scripts/helpers_weights.R", encoding = "UTF-8")
library(parallel)

tmp_dir <- "refs/maps_100m_tmp_check"
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
terraOptions(tempdir = tmp_dir, memfrac = 0.1, progress = 0)

overuse <- readRDS("data/outputs/results/wood_overuse_country_year.rds")
value <- readRDS("data/outputs/results/wood_value_country_year.rds")
national <- national_map_values(overuse, value, years_report) |>
  rename(table = total)

countries <- vect("data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg")
countries <- countries[countries$eu27, ]
countries$id <- seq_len(nrow(countries))
id_file <- file.path(tmp_dir, "ids.tif")
rasterize(countries, template_100m(), field = "id", filename = id_file, overwrite = TRUE)
id_table <- tibble(id = countries$id, geo = countries$geo)

jobs <- distinct(national, quantity, year)
read_back <- mclapply(seq_len(nrow(jobs)), function(i) {
  terraOptions(tempdir = tmp_dir, memfrac = 0.05, progress = 0)
  file <- sprintf("refs/maps_100m/wood_%s_100m_%s.tif", jobs$quantity[i], jobs$year[i])
  zonal(rast(file), rast(id_file), fun = "sum", na.rm = TRUE) |>
    setNames(c("id", "map")) |>
    inner_join(id_table, by = "id") |>
    mutate(quantity = jobs$quantity[i], year = jobs$year[i])
}, mc.cores = 5, mc.preschedule = FALSE)
failed <- vapply(read_back, \(x) !is.data.frame(x), logical(1))
if (any(failed)) stop("Could not read ", sum(failed), " maps")

compared <- bind_rows(read_back) |>
  right_join(national, by = c("geo", "year", "quantity")) |>
  mutate(map = coalesce(map, 0))

# A small absolute margin keeps a country with almost nothing from failing on rounding of whole numbers.
gap <- compared |>
  filter(table > 1e4) |>
  mutate(gap = abs(map - table) / table)

save_report_table(
  compared |> summarise(map = sum(map), table = sum(table), .by = c(quantity, year)) |> arrange(quantity, year),
  "maps_100m_totals"
)
save_report_table(
  bind_rows(
    record_check(gap$map[grepl("dm3", gap$quantity)], gap$table[grepl("dm3", gap$quantity)],
                 "100 m physical maps against the national tables, by country", tolerance = 1e-3),
    record_check(gap$map[grepl("eurocent", gap$quantity)], gap$table[grepl("eurocent", gap$quantity)],
                 "100 m monetary maps against the national tables, by country", tolerance = 1e-3)
  ),
  "checks_maps_100m"
)
unlink(tmp_dir, recursive = TRUE)
