# Spatial explicitness: TR3 (JRC116334)

Page numbers are the printed page numbers of each PDF (not the PDF index). Levels: **V** = verified in text; **I** = inferred (by the author of this note); **W** = verified in an online metadata file.

## A. TR3, chapter 4 (timber provision): how national statistics are spatialised

| # | Statement | Page | Level |
|---|---|---|---|
| 1 | The national actual flow (m3/year) = NAI x EcoContimber (Eq. 4.2). NAI comes from Eurostat/FAO forest resources tables (`for_sfm`, FAO-FE `for_vol`). | 31-32 | V |
| 2 | Mapping is needed for synergy and trade-off analysis with other INCA services. | 32 | V |
| 3 | Method: the national flow is "spatially disaggregated" using Dry Matter Productivity (DMP) as proxy. | 32 | V |
| 4 | Proxy: Copernicus Global Land Service DMP, 1 km x 1 km grid; kg dry matter/ha over a period. | 32 | V |
| 5 | Spatial support: forest classes of CLC only (broad-leaved, coniferous, mixed). Transitional woodland-shrub is excluded for timber (differs from the MAES Woodland and forest type); see Annex 1. | 32 | V |
| 6 | CLC forest includes forest available and not available for wood supply; the map is therefore not restricted to FAWS. | 32 | V |
| 7 | Authors tested constraints (slope, protected areas) to approximate FAWS and rejected them: thresholds are not common across Europe and the delineation "could be misleading" (Alberdi et al. 2016). | 32, 40 | V |
| 8 | Examples of heterogeneous thresholds: protected areas excluded from FAWS in only 50% of countries; slope threshold 35% in Slovenia, 45-50% in Spain (up to 75-80% in the Atlantic area). | 40 | V |
| 9 | Stated limit: spatially explicit FAWS data not available at EU level; downscaling used CLC forest extent. Suggested future step: use the upcoming JRC FAWS map. | 40 | V |
| 10 | Chapter 4 itself gives no explicit conservation rule for timber. The only explicit formula is in the sister service (CO2 uptake, Annex 7): pixel DMP / country total DMP, multiplied by the national value. | Annex 7 (after p.~110) | V (Annex 7); applied to timber by **I** |
| 11 | Sum conservation therefore follows by construction: weights per country add to 1, so the pixel values add back to the national total. Not stated in chapter 4. | n/a | I |
| 12 | DMP: SPOT-VGT + ECMWF meteorology, 1 km, 10-day layers, annual sum per reference year (2000, 2006, 2012), projected to ETRS89-LAEA. | Annex 7 | V |
| 13 | EcoContimber is a static average of 2010-2014 (no data for 2000 and 2006). | 39 | V |

Implication: TR3 aggregated the forest at the CLC level and left the delineation of available forest as future work.

