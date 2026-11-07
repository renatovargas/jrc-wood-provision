# Method decisions

The INCA reports settle questions they address. Part II is Vallecillo et al. (2019), Part III is La Notte et al. (2021). Where they are silent, the choice and its reason are recorded here and in the report. Levels: **V** = verified in text, **M** = measured in this repository, **I** = inferred.

| Decision | Source or evidence | Page or location | Level |
|---|---|---|---|
| The flow is the whole NAI of forest available for wood supply, with no ecosystem contribution coefficient | Part III, Section 6.2 | p. 100 | V |
| Gaps in NAI take carbon budget model estimates | Part III, Section 6.2, note 43, data at `data.jrc.ec.europa.eu/dataset/d4be2da6-54a1-4767-a262-dcebf66bf10b` | p. 101 | V |
| Total forest estimate of the model, unscaled | Closest to Annexes AA37, AA41, AA45 by Member State. Table `gap_rule_comparison` | `scripts/07` | M |
| The annexes of Part III do not state a price basis, and 2012 matches current prices, which also fits a constant series based on 2012 | Germany 2012 reproduces at 3,626 million euro. Table `value_against_published` | `scripts/08` | M, I |
| Unit value through the export ratio, with country and EU means | Part III, Section 6.2 | p. 101 to 102 | V |
| Timber values of HR, FI, EL, PT, SE and export points DK 2014, EL 2006 removed | INCA tool, `woodprovision/preprocessing/outlier_cleaning_*.py` | Tool source | V |
| Median ratio outside 1 to 100 removes a Member State, and single points outside that range are dropped | LT near 1,500, BE near 0.9. After the tool list, observed ratios leave a gap from 13 to 1,000. Part III values BE near 32 euro per m3 | Table `ratio_screen` | M |
| Export unit value more than threefold from the country median is dropped | HR 2012 at 10 against 67, RO 2024 at 286 against 93 | Table `export_points_removed` | M |
| Forest mask of CLC 311, 312, 313, without 324 | Part II, Chapter 4 | p. 32 | V |
| The INCA tool includes CLC 324 in forest | `integration_tests/clc/CLCACC_ecosystem-level1_translation.csv` | Tool source | V |
| No availability mask | Part II rejects delineating availability through thresholds | p. 32, 40 | V |
| GDMP in place of DMP, as the proxy shares national values within a country | Part II names DMP. Copernicus lists both as separate products that differ in autotrophic respiration. The quality page of the 1 km DMP describes a constant fraction of 0.5. Script 12 compared 10 of the 180 pairs of files behind the key, January and July of each reporting year over Europe, against a tolerance set beforehand of 1% of the productivity total and 0.1% of cells with data in one product only. DMP equals half of GDMP in every cell of all 10 pairs, so the shares do not change on this evidence and the key stays on GDMP | `land.copernicus.eu`, product pages, `data/outputs/report/dmp_gdmp_check.rds` | V |
| Overuse is removals above NAI, sustainable flow is removals up to NAI | Part III gives no formula for wood. The water purification method defines overuse from the threshold (p. 89). The Eurostat handbook describes overharvesting as removals above NAI (p. 124) | p. 89, handbook p. 124 | V, I |
| Constant prices with the EU27 HICP and base year 2010 | Part III moves other accounts to constant prices (p. 62, about Section 6.4) and gives no deflator for wood. The tool uses national indices with base 2000. The base keeps this series of accounts together | Part III, tool source | V, I |
| Series breaks between model and reported values are kept | Part III has them as well, for example FR 156 in 2000 and 93 in 2012 | Annexes AA37, AA45 | V |

## Open questions

- Whether scaling the model estimates to the reported level of each country would serve users better than keeping the series as Part III builds it.