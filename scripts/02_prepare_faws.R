# Reduce the Forest Available for Wood Supply (FAWS) 2020 map to the exact area by country.
#
# Input  : refs/Forest Available For Wood Supply 2020/FAWS_2020_EU27_Compressed.tif
#          100 m, EPSG:3035, values 1 and 2 (1 = available for wood supply, 2 = not available;
#          coding inferred from pixel counts and the JRC report, see research/spatial-explicitness-tr3.md)
#          Citation: JRC (2026), doi:10.2905/JRC.SF31H30
# Output : data/inputs/faws/faws_area_by_country.rds  exact hectares by country at 100 m
# Run    : source("scripts/02_prepare_faws.R", encoding = "UTF-8"), once, from the project root.

library(terra)
library(sf)
library(dplyr)

faws_file <- "refs/Forest Available For Wood Supply 2020/FAWS_2020_EU27_Compressed.tif"
countries_file <- "data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg"
out_dir <- "data/inputs/faws"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

faws <- rast(faws_file)
countries <- project(vect(countries_file), crs(faws))

# Binary layers at 100 m: 1 where the cell has that class, 0 elsewhere.
is_faws <- ifel(is.na(faws), 0, faws == 1)
is_fnaws <- ifel(is.na(faws), 0, faws == 2)

# Exact hectares per country from the 100 m map (each 100 m cell is 1 ha)
ha_faws <- extract(is_faws, countries, fun = "sum", na.rm = TRUE)[, 2]
ha_fnaws <- extract(is_fnaws, countries, fun = "sum", na.rm = TRUE)[, 2]

faws_area <- tibble(
  geo = countries$geo,
  faws_ha = ha_faws,
  fnaws_ha = ha_fnaws
) |>
  filter(faws_ha > 0 | fnaws_ha > 0)

saveRDS(faws_area, file.path(out_dir, "faws_area_by_country.rds"))
