## Updated Data Requirements for Immigration Labor Market Study

### Target Populations
- **Domestic (native)**: Individuals born in the United States, encompassing the 50 states and the District of Columbia.
- **Foreign-born**: Individuals not born in the United States, including naturalized citizens, lawful permanent residents, temporary migrants, humanitarian migrants, and unauthorized immigrants as defined in CPS microdata.

### Reference Period
- Use the most recent full calendar year or rolling 12-month period with complete CPS microdata (e.g., 2023 if available, otherwise 2022).
- Apply annualized weights by combining CPS Basic Monthly files or use the Annual Social and Economic Supplement (ASEC) if the original study relied on that source.

### Core Labor Market Indicators
1. **Labor force participation rate (LFPR)**: Share of population 16+ in the labor force.
2. **Employment-population ratio**: Share of population 16+ that is employed.
3. **Unemployment rate**: Share of the labor force that is unemployed.
4. **Full-time/part-time status**: Employment shares by usual hours worked (>=35 hours vs. <35 hours).
5. **Industries and occupations**: Employment distribution across major NAICS sectors and SOC occupation groups.
6. **Educational attainment**: Employment and labor force rates by highest degree (less than HS, HS, some college/AA, bachelor's, advanced).
7. **Median usual weekly earnings** (for wage and salary workers with valid earnings).
8. **Part-time for economic reasons**: Share of employed working part-time involuntarily.

### Suggested CPS Variables
- `NATIVITY` (nativity status), `CITIZEN` (citizenship), `AGE`, `SEX`, `RACE`, `HISPAN`, `EDUC`, `EMPSTAT`, `LABFORCE`, `UHRSWORKT` (usual hours), `UHRSWORKLY`, `PTREASON` (part-time for economic reasons), `OCC`, `IND`, `PAIDHOUR`, `EARNWEEK`, `ASECWT` or `WTFINL` (weights), `YEAR`, `MONTH`.
- Include supplemental variables if the study segments by marital status (`MARST`), region (`STATEFIP`, `CPSIDP`), or tenure (`TENURE`).

### Preferred Data Sources
1. **CPS Basic Monthly microdata (IPUMS CPS)**: Enables reproduction of custom aggregates, matching prior study methodology, and disaggregation by multiple covariates. Requires IPUMS account and extraction of 12 monthly samples per year with harmonized weights.
2. **BLS Foreign-born Workers News Release tables**: Quick cross-check for headline LFPR, employment-population ratio, and unemployment rate. Series IDs (examples):
   - `LNU02332179`: Employment-population ratio, foreign-born, 16 years & over.
   - `LNU01332179`: Labor force participation rate, foreign-born, 16 years & over.
   - `LNU04032179`: Unemployment rate, foreign-born, 16 years & over.
   - Replace the middle digits (`32179`) with `00000` for native-born counterparts.
   - Similar `LNU` series exist for gender, age, and educational breakdowns.

### Data Acquisition Steps (IPUMS CPS workflow)
1. Log in to https://cps.ipums.org/ using project credentials.
2. Create a new extract selecting the latest 12 Basic Monthly samples (or the latest ASEC) and include the variables listed above.
3. Submit the extract, download the `.dat.gz` and accompanying `.xml` metadata.
4. Store the downloaded files under `data/raw/` (create the directory if needed).
5. Record the extract number and description; reference it in `immigration2.tex` for reproducibility.

> Automation option: Run `Rscript download_ipums_cps.R` after setting the `IPUMS_API_KEY` environment variable. The script submits the annual extract (monthly samples for the reference year), waits for completion, and saves the IPUMS zip contents into `data/raw/`.

### Processing Workflow Overview
1. Use `ipumsr::read_ipums_micro()` in R to load the extract efficiently (leveraging the `.xml` metadata).
2. Recode nativity into `domestic` and `foreign_born` categories.
3. Define labor force, employment, and unemployment counts using CPS status variables and appropriate person-level weights.
4. Aggregate totals and rates by nativity and the relevant demographic/industry/education breakdowns.
5. Generate summary tables and graphs that mirror those in the original study, ensuring weighting and annualization match previously documented methods.
6. Export cleaned tables to `data/processed/` (e.g., CSV files) for direct inclusion in LaTeX via `\input{}` or `\includegraphics`.

### Documentation Updates
- Update `immigration2.tex` to cite the IPUMS CPS extract number and download date.
- Refresh figure and table captions with the new reference year.
- Note any methodological deviations (e.g., new occupational coding, revised industry classifications, or pandemic-related adjustments).
