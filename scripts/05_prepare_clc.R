# Combine Corine Land Cover forest with the FAWS map, one compact raster per CLC epoch.
#
# Inputs : refs/corine/<zip folders>/DATA/U20xx_CLCyyyy_V2020_20u1.tif
#          CLC 2000, 2006, 2012 and 2018, version V2020_20u1, 100 m, EPSG:3035
#          (Copernicus Land Monitoring Service, doi:10.2909/960998c1-1870-4e82-8051-6485205ebbac for 2018)
#          refs/Forest Available For Wood Supply 2020/FAWS_2020_EU27_Compressed.tif
#          Forest classes are the raster legend values 23, 24 and 25 (CLC 311, 312 and 313:
#          broad-leaved, coniferous and mixed forest). The legend is identical in the four epochs.
# Output : data/inputs/corine/FAWS_x_CLC<year>_1km.tif
#          Share (0-1) of each 1 km cell where a 100 m cell is both FAWS and CLC forest in <year>.
# Run    : source("scripts/05_prepare_clc.R", encoding = "UTF-8"), once, from the project root.
#          Resumable: epochs whose output already exists are skipped. Takes several minutes per epoch.

library(terra)

clc_dir <- "refs/corine"
faws_file <- "refs/Forest Available For Wood Supply 2020/FAWS_2020_EU27_Compressed.tif"
out_dir <- "data/inputs/corine"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Epoch -> file. The archive name carries the update year (u2006 holds CLC2000, and so on).
clc_files <- c(
  `2000` = "u2006_clc2000_v2020_20u1_raster100m/u2006_clc2000_v2020_20u1_raster100m/DATA/U2006_CLC2000_V2020_20u1.tif",
  `2006` = "u2012_clc2006_v2020_20u1_raster100m/u2012_clc2006_v2020_20u1_raster100m/DATA/U2012_CLC2006_V2020_20u1.tif",
  `2012` = "u2018_clc2012_v2020_20u1_raster100m/u2018_clc2012_v2020_20u1_raster100m/DATA/U2018_CLC2012_V2020_20u1.tif",
  `2018` = "u2018_clc2018_v2020_20u1_raster100m/u2018_clc2018_v2020_20u1_raster100m/DATA/U2018_CLC2018_V2020_20u1.tif"
)

forest_codes <- 23:25
agg_factor <- 10

faws <- rast(faws_file)

for (year in names(clc_files)) {
  out_file <- file.path(out_dir, sprintf("FAWS_x_CLC%s_1km.tif", year))
  if (file.exists(out_file)) next

  # Same grid as FAWS; drop the legend so the cells are plain numbers
  clc <- crop(rast(file.path(clc_dir, clc_files[[year]])), faws)
  levels(clc) <- NULL
  coltab(clc) <- NULL

  is_forest <- clc >= min(forest_codes) & clc <= max(forest_codes)
  both <- ifel(is.na(is_forest & (faws == 1)), 0, is_forest & (faws == 1))

  share <- aggregate(both, fact = agg_factor, fun = "mean", na.rm = TRUE)
  names(share) <- paste0("faws_x_clc", year)
  writeRaster(
    share,
    out_file,
    datatype = "FLT4S",
    gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3", "ZLEVEL=9", "TILED=YES")
  )
}
