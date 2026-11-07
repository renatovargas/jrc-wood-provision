# Repository structure and conventions

This file describes how the repository is organised and which conventions the documents follow. The
rules in `AGENTS.md` still apply. This file only adds what those rules do not cover.

## Layout

```
.
├── AGENTS.md                 rules for authors
├── structure.md              this file
├── _quarto.yml               project, menu and format configuration
├── index.qmd                 home page, a short description of what the site is about
├── styles.css                site styles (almost empty)
├── assets/
│   └── apa-6th-edition.csl   citation style shared by all documents
├── documentation/
│   ├── index.qmd             list of the reports, one definition per report
│   └── methods/
│       └── wood-provision/
│           ├── index.qmd     the report
│           └── wood-provision.bib
├── downloads/
│   └── index.qmd             buttons to the results workbook and the 100 m maps, HTML only
├── scripts/
│   ├── run_all.R             runs the pipeline, or some of its stages, in order
│   ├── NN_<verb>_<object>.R  numbered scripts of the pipeline
│   ├── helpers_common.R      constants, small tables and check functions
│   ├── helpers_wood.R        filling of the series, overuse and spreading over a map
│   ├── helpers_monetary.R    gap filling with means and the deflator
│   ├── helpers_weights.R     the 100 m spatial key
│   ├── helpers_results.R     workbook layout
│   └── helpers_report.R      reads the small tables and formats them, for the report only
├── data/
│   ├── inputs/
│   │   ├── manifest_heavy_inputs.csv  heavy sources kept in refs/, with source, size and md5
│   │   ├── params/           published tables of INCA Part III by Member State
│   │   ├── gis/              country boundaries
│   │   ├── eurostat/         forest volumes, value of forest trees, exports and price index
│   │   ├── carbon_budget/    NAI estimated by the carbon budget model
│   │   └── weights/          spatial key at 1 km and shares of the NUTS regions
│   └── outputs/
│       ├── results/          national tables (rds) and the results workbook (xlsx)
│       ├── report/           small tables that the scripts write for the report (rds)
│       └── figures/          figures that the scripts write for the report (png)
├── research/                 notes, not published
├── refs/                     downloads, reference files and maps, not versioned
│   ├── weights_100m/         100 m spatial key, written by 05, read by 10
│   ├── maps_1km/             1 km maps (GeoTIFF), written by 09
│   └── maps_100m/            100 m maps (GeoTIFF), written by 10, published outside the repository
└── docs/                     rendered site, generated, do not edit
```

## Reproducibility levels

The repository supports two levels. The first level needs only the repository. The stages `tables` and `maps_1km` of
`scripts/run_all.R` read the compact products in `data/inputs/`, rebuild every table and write the 1 km maps to
`refs/maps_1km/`. The report renders from the small tables with no further step. The second level rebuilds the spatial key and the
100 m maps from the sources listed in `data/inputs/manifest_heavy_inputs.csv`, which have to be in `refs/`.

## Scripts

Scripts run in the order of their numbers, from the project root. `scripts/run_all.R` runs them by stage, namely `inputs`, `tables`, `maps_1km` and `maps_100m`, and with no stage named it runs `tables` and `maps_1km`. Script 02 downloads the latest Eurostat data, which can change the results, so it runs only when an update is wanted. Script 00 is commented out in `scripts/run_all.R`, because it needs Copernicus keys, hours of network reading and many GB of temporary disk space to rebuild layers that `refs/` already holds.

All calculation is in the scripts, and the report reads their small tables and figures. After a change, rerun only what it affects, and then render:

| Change | Rerun |
|----|----|
| Text or formatting of the report | Only `quarto render` |
| The rule for gaps or overuse | `07`, `08`, `09` |
| The valuation | `08`, `09` |
| Forest mask or productivity | `05`, `06`, `08`, `09` |
| Any of the above that changes national values or the key | Also `10` and `11`, for the 100 m maps |

| Script | Purpose |
|----|----|
| `00_prepare_gdmp_annual.R` | Annual productivity from the ten-day Copernicus files, run by hand |
| `01_prepare_nuts.R` | Country boundaries |
| `02_download_eurostat.R` | Forest volumes, value of forest trees, roundwood exports and price index |
| `03_prepare_carbon_budget.R` | NAI estimated by the carbon budget model |
| `04_extract_manual_annex.R` | Published tables by Member State from INCA Part III |
| `05_prepare_weights.R` | Forest times productivity at 100 m and 1 km |
| `06_prepare_nuts_weights.R` | Share of each NUTS region in the weight of its country |
| `07_build_physical_accounts.R` | Actual flow, sustainable flow and overuse by country, with their checks |
| `08_build_monetary_accounts.R` | Unit values, value by country and the results workbook, with their checks |
| `09_write_maps_1km.R` | 1 km maps, map figures and comparison of maps with tables |
| `10_write_maps_100m.R` | 100 m maps |
| `11_check_maps_100m.R` | Comparison of the 100 m maps with the tables |
| `12_compare_dmp_gdmp.R` | Test of DMP against GDMP on a sample of files, run by hand |

## Menu

The site has three entries in the top bar, "Home", "Documents" and "Downloads". A new report needs its folder under
`documentation/methods/`, a line in the sidebar of `_quarto.yml` and a definition in `documentation/index.qmd`.

## Report

The report is a narrative with no visible code, and it has these sections, in this order: Summary, Introduction, Methods,
Results, Limitations, Appendix, References and Annex I. Methods follows the logical order of the scripts, with substeps inside each, and it
explains why each decision was taken. Results follows the products. Only the report has a PDF version, which it declares
in its own `format`, so `_quarto.yml` sets HTML alone.

- Every step of the method links to the entry of its script in Annex I, written as `(see [05_prepare_weights.R in Annex I](#script-05))`.
- Annex I has one entry per file in `scripts/`, in the order in which they run. Each entry has the file name as its heading, a link to the file on GitHub and a short paragraph in plain English with no code. A change to a script updates its entry.
- The table of scripts in the Introduction is a markdown table, because its names link to Annex I in both HTML and PDF.
- Numbers in the text come from `data/outputs/report/` through inline code.
- Chunks only read a small table and show it, and their labels are lowercase words separated by hyphens.
- The bibliography is one `.bib` file in the report folder, and the citation style is referenced as `../../../assets/apa-6th-edition.csl`.

## Data and file names

- The 100 m maps are named `wood_<quantity>_100m_<year>.tif`, where the quantity carries its unit, as in `flow_dm3` and `overuse_eurocent2010`. They are whole numbers per cell, written with `COMPRESS=DEFLATE`, `PREDICTOR=2` and `TILED=YES`.
- The 1 km maps are 32-bit floats with `COMPRESS=DEFLATE`, `PREDICTOR=3` and `TILED=YES`.
- All maps use EPSG:3035, on a grid aligned with the Corine grid.
- Country codes follow Eurostat (`EL` for Greece).
- CSV is kept only for short files edited or read by hand, namely the published tables of Part III and the manifest.

## Research notes

Notes in `research/` are plain markdown files with statements, each with its source, page and a verification
level. They are not published.
