## Guidance for Updating `immigration2.tex`

1. **Document the new data extract**
   - Insert a short paragraph in the data section citing the IPUMS CPS extract number, download date, and access path (e.g., `data/raw/cps_immigration_extract.xml`).
   - Update the description of the reference year (currently assumed to be 2023 in `immigration_analysis.R`).

2. **Refresh tables**
   - Replace existing domestic vs. foreign-born labor market tables with the CSV outputs from `data/processed/tables/`.
   - Use `\input{}` or `\includegraphics{}` referencing the new files (e.g., `headline_labor_indicators.csv` after converting to LaTeX table format via `\input{tables/headline_labor_indicators.tex}`).
   - Ensure the table captions specify "Author's calculations using CPS Basic Monthly microdata (IPUMS CPS)."

3. **Update figures**
   - Add or replace figures using the PNG exports generated in `data/processed/figures/`.
   - Verify figure labels in the text correspond to the refreshed captions and file names.

4. **Narrative adjustments**
   - Revise all numeric references in the abstract, executive summary, and findings sections to reflect the new metrics (LFPR, unemployment rate, median weekly earnings).
   - Highlight any notable changes between the previous study year and the updated year (e.g., shifts in employment-population ratios for foreign-born workers).

5. **Methodology notes**
   - Include a sentence on handling part-time for economic reasons and the education grouping logic implemented in `immigration_analysis.R`.
   - If pooling multiple years or months, clarify the weighting strategy (e.g., average of 12 monthly WTFINL weights).

6. **Reproducibility**
   - Append a short subsection listing the R version, key packages, and the script path (`immigration_analysis.R`).
   - Consider adding a `make` target or command-line snippet to re-run the analysis (`Rscript immigration_analysis.R`).
