# Reduce the Forest Available for Wood Supply (FAWS) 2020 map to compact products.
#
# Input  : refs/Forest Available For Wood Supply 2020/FAWS_2020_EU27_Compressed.tif
#          100 m, EPSG:3035, values 1 and 2 (1 = available for wood supply, 2 = not available;
#          coding inferred from pixel counts and the JRC report, see research/spatial-explicitness-tr3.md)
#          Citation: JRC (2026), doi:10.2905/JRC.SF31H30
# Output : data/inputs/faws/FAWS_2020_EU27_1km.tif    share of each 1 km cell (0-1) that is FAWS
#          data/inputs/faws/FNAWS_2020_EU27_1km.tif   share of each 1 km cell that is forest not available
#          data/inputs/faws/faws_area_by_country.rds  exact hectares by country at 100 m
# Run    : source("scripts/02_prepare_faws.R", encoding = "UTF-8"), once, from the project root.

library(terra)
library(sf)
library(dplyr)

faws_file <- "refs/Forest Available For Wood Supply 2020/FAWS_2020_EU27_Compressed.tif"
countries_file <- "data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg"
out_dir <- "data/inputs/faws"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Aggregation factor: 10 cells of 100 m give one cell of 1 km
agg_factor <- 10

faws <- rast(faws_file)
countries <- project(vect(countries_file), crs(faws))

# Binary layers at 100 m: 1 where the cell has that class, 0 elsewhere.
# Cells without data are not forest, so they count as 0 in the 1 km shares.
is_faws <- ifel(is.na(faws), 0, faws == 1)
is_fnaws <- ifel(is.na(faws), 0, faws == 2)

# Share of FAWS and FNAWS inside each 1 km cell
share_faws <- aggregate(is_faws, fact = agg_factor, fun = "mean", na.rm = TRUE)
share_fnaws <- aggregate(is_fnaws, fact = agg_factor, fun = "mean", na.rm = TRUE)

write_share <- function(x, file) {
  writeRaster(
    x,
    file,
    overwrite = TRUE,
    datatype = "FLT4S",
    gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3", "ZLEVEL=9", "TILED=YES")
  )
}
write_share(share_faws, file.path(out_dir, "FAWS_2020_EU27_1km.tif"))
write_share(share_fnaws, file.path(out_dir, "FNAWS_2020_EU27_1km.tif"))

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
