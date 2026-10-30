# Wood provision in INCA Part III (JRC126566) and the 2026 Ecosystem accounts handbook

Verification levels: **V** = verified in text, **I** = inferred by the compiler.

## Sources

| Short name | File (in `refs/`, not versioned) | Where the wood content is | Page numbers used |
|---|---|---|---|
| INCA III (old) | `inca_part_iii_online_version.pdf` | Section 6.2 "Timber provision" (within Chapter 6, "Updates of previous ecosystem services accounts") | Printed p. 100-102 = PDF p. 107-109 (offset +7). Also printed p. 112-121 (indicators, overuse) |
| Handbook 2026 | `KS-01-26-019-EN-N.pdf` | Chapter 7 "Wood Provision Services" (Eurostat *Ecosystem accounts handbook*, 2026 edition); Annexes 16-17 | Printed p. = PDF p. 122-134, 251-252 |

**Important finding.** The second file is not an INCA Part III update. It is the Eurostat *Ecosystem accounts handbook* (2026 edition, manuscript March 2026). Its wood chapter is Chapter 7, not 6. It covers definitions, physical accounting and supply/use tables only. It has no monetary valuation method for wood and no spatial disaggregation (V; searched whole text for resource rent, stumpage, monetary valuation, none for wood).

## 1. Definition, ecosystem contribution, flow proxy

- INCA III (old, p. 100, V): timber provision is the ecological contribution to the production of timber that can be harvested and used as a raw material. The ecological process is natural growth of a biotic resource, so the accounting flow is the **net annual increment (NAI) of standing timber in forest available for wood supply (FAWS)**.
- Old p. 100 (V): the whole NAI is reported; human input is not disentangled from it. Reasons: (a) SEEA CF forest asset accounts already record "addition to stock due to natural causes" as the ecosystem contribution; (b) Eichhorn's rule (p. 101), by which management does not much change stand volume growth within a range of thinning.
- Old p. 100 (V): three flows are distinguished: NAI (woodland to forestry), felling/logging (forestry to logging sector) and use. NAI is the flow for CF/EA consistency; logging is suggested as alternative for ecological and sustainability analysis (Maes et al., 2020).
- Handbook 2026 p. 122 (V): wood provision is "the ecosystem contributions to the growth of trees and other woody biomass" (Reg. (EU) No 691/2011), reported as net increment in thousand m3 overbark. Net annual increment = average annual volume growth of live trees less average annual mortality.
- Handbook p. 123-125 (V): FAWS is treated as cultivated, so the flow is net increment, not removals. Forests not available for wood supply (FNAWS) are treated as uncultivated and use removals (voluntary item). The first product the service feeds is standing "Forest trees" (CPA 02.10.3), not roundwood (p. 132). No adjustment for double counting with climate regulation (p. 125, 7.10).

## 2. Physical accounting

- Variable (both, V): NAI of forest available for wood supply, 1 000 m3 overbark (old p. 101-102 tables in 1 000 m3; handbook Table 7.1-7.3, p. 126, 130).
- Eurostat dataset (old p. 101, fn 42, V): `for_vol_efa` "Volume of timber over bark" (European Forest Accounts). The handbook (p. 127, fn 89, V) also names `for_vol_efa`. Other named sources: FAO Global Forest Resources Assessment (5-yearly), Forest Europe state-of-forests reports (5-yearly), national forest inventories, the FAO/UNECE/Forest Europe Pan-European Questionnaire (handbook p. 127).
- Gap filling (old p. 101, V): because of many missing data, estimates from the JRC carbon budget model (Pilli et al., 2021; JRC data catalogue link in fn 43) are used to fill gaps. The exact rule (fill only missing, or replace) is not stated (see section 6).
- Years (old Table 6.3, p. 102, V): 2000, 2006, 2012; EU total NAI shown as 955, 897 and 885 (1 000 m3 units as printed; magnitude to be checked). The handbook sets no years; it is annual.
- Handbook mapping (V, p. 128-129): Mandatory supply = Forest AWS net increment (item 1) plus Other wooded land (OWL) AWS net increment (item 3b) if that split exists. Voluntary supply = removals from FNAWS (2) + OWL total (3a) + other land with tree cover (4). Never include both 3a and 3b. OWL and FAWS are reported under EUET "Forest and woodland"; item 4 goes to cropland or grassland.
- Use table (handbook p. 132-134, V): all FAWS increment is "intermediate consumption by industries" (forestry, NACE A02.1). Removals from NAWS also go to industries (logging A02.2, agriculture A01, household own use counted as industry).
- Natural losses (Annex 17, p. 251-252, V): recurrent losses are already net in NAI; catastrophic/irretrievable losses are not deducted from the supply.
- Handbook p. 127-128 (V): Forest Accounts are national, annual. Only "Forest" is mandatory; OWL and other land with tree cover are voluntary and scarce.

## 3. Overuse and sustainability

- Old p. 10, 25, 121 (V): timber is classed among services whose actual flow can exceed regeneration; overuse occurs if annual use goes beyond a sustainability threshold (for timber, the regeneration rate). The old report quotes the check "is wood felling below the regeneration rate?" (p. 25) and gives the worked example only for water purification (overuse = sustainable flow minus actual flow, table 7.4, p. 121). **No timber overuse figure or formula is given** (V).
- Handbook p. 124 (V, 7.4): overharvesting means removals exceed NAI of usable wood over an extended period; it is possible because of stock built earlier. No threshold or indicator formula, and no overuse table for wood in Ecosystem Accounts.
- Implementable proxy (I): overuse ratio = removals (fellings) / NAI by country-year, with overuse flagged when ratio > 1 and overuse volume = max(0, removals - NAI). Removals come from `for_vol_efa` (same table, "removals" item). This is the compiler's inference, not a stated method.

## 4. Monetary valuation (PHASE 2; old edition only)

Described in old p. 101-102 (V). No resource-rent or stumpage-price method is used.

1. NAI monetary value comes from Eurostat `for_sup_cp` "Supply and use of products within forestry" (old fn 44). Divide by NAI volume to get `unit_value_NAI` (EUR/m3), by country-year.
2. Unit value of exports of roundwood: `for_basic` "Roundwood, fuelwood and other basic products" (old fn 45), monetary and physical exports; `unit_value_export` = export value / export volume (EUR/m3).
3. `Ratio_export_NAI = unit_value_export / unit_value_NAI` where both exist.
4. Gaps in the ratio: use the country average over the series if partly missing; use the EU average if the country has no data.
5. Final proxy: `unit_value_NAI_filled = unit_value_export / Ratio_export_NAI` (filled); monetary flow = NAI x `unit_value_NAI_filled`.
- Table 6.3 (p. 102, V): monetary EU values in million EUR: 23 745 (2000), 21 623 (2006), 22 714 (2012). Annexes AA37-AA48 give Member State tables (not read).
- Deflator and base year: **not stated** in section 6.2 (checked text; V that absent). The ratio of the 3 totals looks like current prices (I). Confirm.

## 5. Spatial disaggregation and 2026 changes

- Old section 6.2 (V): no spatial method. Supply is allocated to the ecosystem type "Woodland and forest available for wood supply" in SUT, national level, no masks or weights described. Spatial disaggregation for wood is absent in both files (V). Any mapping step (for example CORINE/forest masks) would be a project design choice (I).
- Handbook 2026 changes versus old edition (V unless marked):
  - Name: "Wood provision" instead of "Timber provision"; NAI definition tied to Regulation 691/2011 (p. 122).
  - Explicit FAWS (cultivated, net increment, mandatory) versus FNAWS (removals, voluntary) distinction with rules for OWL and other tree land (p. 123-129).
  - Supply by EUET level 1 and use to intermediate consumption by industries (p. 127, 132).
  - SNA 2025 note: output of uncultivated forests will be recorded as trees grow, little effect for the EU (p. 125, 7.7).
  - Relation to MFA item 1.3 (removals) (p. 125). No monetary valuation or overuse method.
  - Gap filling and carbon-budget-model approach are not repeated (I; not found).

## 6. Ambiguities to confirm with the client

1. Which source defines "chapter 6 update": the second PDF is the Eurostat handbook (wood is Chapter 7). Is the intended method INCA III 6.2, the handbook, or both?
2. Is monetary valuation (phase 2) to follow the export-ratio method of INCA III 6.2? Deflator and base year, and EU-28 or EU-27 coverage.
3. Years to update (the old report has 2000, 2006, 2012) and whether EUET level 1 or country totals are required.
4. Gap filling: use the carbon budget model (Pilli et al., 2021) for missing NAI only, or other rules; version of the dataset.
5. Include OWL (item 3b) and removals from FNAWS (voluntary) or only FAWS?
6. Overuse: define as removals/NAI or use another threshold; is a wood overuse indicator expected?
7. Spatial disaggregation: the reports give none. Confirm whether maps are needed and with which forest mask.
8. Units: Table 6.3 prints 955 (1 000 m3) as the EU total, which looks too low against 23 745 million EUR; verify unit labelling against Annexes AA37-AA48.
