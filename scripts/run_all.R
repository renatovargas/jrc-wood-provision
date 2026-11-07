# Run the pipeline, or some of its stages, in order.
#
# Stages : inputs    scripts 01 to 06. Needs internet access and the files in refs/, and takes about an hour.
#                    Rerunning script 02 downloads the latest Eurostat data, which can change the results.
#          tables    scripts 07 and 08. Takes seconds.
#          maps_1km  script 09. Takes under a minute.
#          maps_100m scripts 10 and 11. Needs the files in refs/, and takes a few hours.
# Run    : from the project root, with the stages to run. With no stage named, it runs tables and maps_1km,
#          which need only the repository.
#            Rscript scripts/run_all.R
#            Rscript scripts/run_all.R tables
#            Rscript scripts/run_all.R inputs tables maps_1km maps_100m
#          The report is rendered afterwards with `quarto render`.
#
# Script 00 is commented out below on purpose. It rebuilds the annual productivity layers in refs/gdmp_annual/, which
# script 05 reads, from 180 global files in the Copernicus store. That takes Copernicus S3 keys, hours of reading over
# the network and roughly 10 GB of temporary disk space per year at 300 m, and the layers come from an archive that
# rarely changes, so a normal run reuses the 1 GB of finished files. To rebuild them, set the keys as its header
# explains, remove the file to replace and uncomment the line. Files that already exist are skipped.

pipeline <- list(
  inputs = c(
    # "00_prepare_gdmp_annual",
    "01_prepare_nuts", "02_download_eurostat", "03_prepare_carbon_budget", "04_extract_manual_annex",
    "05_prepare_weights", "06_prepare_nuts_weights"
  ),
  tables = c("07_build_physical_accounts", "08_build_monetary_accounts"),
  maps_1km = "09_write_maps_1km",
  maps_100m = c("10_write_maps_100m", "11_check_maps_100m")
)

requested <- commandArgs(trailingOnly = TRUE)
if (length(requested) == 0) requested <- c("tables", "maps_1km")
unknown <- setdiff(requested, names(pipeline))
if (length(unknown) > 0) stop("Unknown stage: ", paste(unknown, collapse = ", "))

# Stages always run in the order of the pipeline, each script in its own environment.
for (stage in intersect(names(pipeline), requested)) {
  for (script in pipeline[[stage]]) {
    message("== ", script, ", ", format(Sys.time()))
    source(sprintf("scripts/%s.R", script), encoding = "UTF-8", local = new.env())
  }
}
