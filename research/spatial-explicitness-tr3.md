# Spatial explicitness: TR3 (JRC116334) and the FAWS 2020 map (JRC132358)

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

Implication: TR3 aggregated the forest at the CLC level and left FAWS refinement as future work. The FAWS 2020 map is the layer announced there.

## B. FAWS 2020 EU27 map (JRC132358, section 6.3.5)

| Item | Finding | Page | Level |
|---|---|---|---|
| Definition (FAO/COST FP1001) | FAWS = "forests where there are no environmental, social or economic restrictions that could have a significant impact on the current or potential supply of wood". | 94 | V |
| FNAWS definition | Restrictions with significant impact on current or potential supply, from legal acts, management decisions or other reasons: environmental (protected areas, habitats, species, protective forest), social (aesthetic, cultural, recreational), economic (accessibility, slope, soil). Age and diameter class are not restrictions. | 94-95 | V |
| Statistics | Harmonised NFI data (22 NFIs through ENFIN; FNAWS estimated for 20 countries), 16 EU countries with sub-national detail, 239 administrative areas; 11 other countries use SoEF 2020. FAWS = forest minus FNAWS per unit; updated to 2020 with the SoEF forest area ratio. | 90, 94-95 | V |
| Map inputs | Reference statistics + a forest map matching the statistics + six restriction maps. | 97 | V |
| Forest mask | Copernicus 2018 Forest Type map aggregated to forest/non-forest, adjusted to national NFI forest area using the 2018 Tree Cover Density map. | 6.2.4 (p.~85) | V |
| Restrictions | Slope and altitude (EU-DEM), protected areas IUCN I and II (WDPA), protected species (Quercus suber, Q. ilex, Pinus mugo; Copernicus Forest Type + JRC tree species atlas, probability > 5%), poor accessibility (distance to paved/unpaved roads, OpenStreetMap), low productivity (kNDVI from MODIS NDVI). | 97-98 | V |
| Thresholds | Set per country so the mapped area matches the reported FNAWS; for SoEF-only countries, borrowed from neighbours. Typical: altitude 2,000 m, productivity 1-2 m3/ha/yr, slope 20-25 deg (Mediterranean) to 40-45 deg (mountains), road distance 500-3,000 m. | 98 | V |
| Resolution | 1 ha (100 m). | 90, 97 | V |
| Resolution (catalogue) | 100 m, calibrated to sub-national NFI statistics, year 2020; restrictions listed: altitude, slope, distance to roads, protected areas, unproductive forests. | catalogue | W |
| CRS | Not stated in the PDF or README. World file origin (2636050, 5415850) with 100 m cell is consistent with ETRS89-LAEA EPSG:3035. | tfw | I (not read from a CRS tag) |
| Pixel coding | Not stated in the PDF. Band statistics (online `.tif.aux.xml`): 2 values only, 1 = 139,287,011 px and 2 = 17,806,353 px; mean 1.113. The file name is "FAWS_FNAWS_Map". Likely 1 = FAWS, 2 = FNAWS (FNAWS = 11.3%, close to the 13% in the text). | n/a | I (coding) / W (counts) |
| NoData | Not documented in the PDF or the online sidecar files; both counts add to 157.1 M px (157.1 Mha forest); background value unknown. Check the TIFF header locally with `terra::describe()` before use. | n/a | unverified |
| Coverage | EU-27, year 2020. | 99 | V |
| Accuracy: FAWS share | 87% of forest area per map vs 89% per statistics; biomass 88% vs 92%. | 98 | V |
| Accuracy: restrictions | The six mapped restrictions cover 82% of FNAWS area and 71% of FNAWS biomass reported by 20 countries. | 98 | V |
| Known limits | Not all restrictions can be mapped (recreation, culture, erosion/wind protection forests). Some overlap with mapped ones (e.g. steep slopes). Maps do not match national statistics exactly; the authors advise integrating both. Country-specific refinement possible with national maps. Most FNAWS biomass in PT (protected species), ES (protection forests), the Alps and northern Scandinavia. | 98-99 | V |
| Related product | BAWS (biomass available for wood supply), 100 m, mask of FAWS on the harmonised biomass map; DOI 10.2905/JRC.944V7T8. | 97 | V (text) / W |
| Licence | CC BY 4.0; access without limits. | catalogue, copyright.txt | W |
| Size online | `FAWS_2020_EU27.tif` 150 MB plus 55 MB overviews (too large to commit; aggregate before saving). | FTP index | W |

### Citation

European Commission, Joint Research Centre (2026): Map of the Forest Available for Wood Supply (FAWS) of EU27 for 2020. [Dataset] doi: 10.2905/JRC.SF31H30. PID: http://data.europa.eu/89h/768d2620-1619-4953-8c7d-42511a43ff8a (W and README.txt).

Report: Avitabile V. et al. (2023). Biomass production, supply, uses and flows in the European Union. EUR 31566 EN, JRC132358. doi:10.2760/811744 (W).

Data location: https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/FOREST/BIOMASS/SUSBIOM/LATEST/FAWS/
