#!/usr/bin/env Rscript
# Purpose: Refresh labor market statistics for domestic vs. foreign-born workers in the U.S.
# Data source: CPS Basic Monthly microdata retrieved via IPUMS CPS extract.

suppressPackageStartupMessages({
  library(tidyverse)
  library(ipumsr)
  library(janitor)
  library(glue)
  library(scales)
})

# ---- configuration -------------------------------------------------------

# Update these paths to match the downloaded IPUMS CPS extract artefacts.
ddi_path <- "data/raw/cps_immigration_extract.xml"
data_path <- "data/raw/cps_immigration_extract.dat.gz"

# Output folders used in the project (created automatically if absent).
processed_dir <- "data/processed"
table_dir <- file.path(processed_dir, "tables")
figure_dir <- file.path(processed_dir, "figures")

dir.create(processed_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(table_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)

# Reference year for reporting (edit if you pool multiple years).
reference_year <- 2023

# ---- helper functions ----------------------------------------------------

read_cps_extract <- function(ddi_path, data_path) {
  if (!file.exists(ddi_path) || !file.exists(data_path)) {
    stop(
      glue(
        "Could not locate CPS extract. Expected:\n  {ddi_path}\n  {data_path}\n",
        "Download these files from IPUMS CPS and update the paths above."
      )
    )
  }

  ddi <- read_ipums_ddi(ddi_path)
  read_ipums_micro(ddi, data_path = data_path, verbose = TRUE)
}

# Recode CPS nativity into domestic / foreign-born labels.
mutate_nativity <- function(df) {
  df %>%
    mutate(
      nativity_group = case_when(
        NATIVITY %in% c(1, 2) ~ "Domestic born",  # born in U.S. / territories
        NATIVITY %in% c(3, 4, 5) ~ "Foreign born",
        TRUE ~ NA_character_
      ),
      nativity_group = factor(nativity_group, levels = c("Domestic born", "Foreign born"))
    ) %>%
    filter(!is.na(nativity_group))
}

# Identify labor force status using EMPSTAT.
mutate_labor_status <- function(df) {
  df %>%
    mutate(
      is_employed = EMPSTAT %in% c(10, 12),
      is_unemployed = EMPSTAT %in% c(20, 21),
      is_labor_force = is_employed | is_unemployed,
      is_part_time = UHRSWORKT > 0 & UHRSWORKT < 35,
      is_full_time = UHRSWORKT >= 35,
      part_time_econ = PTREASON %in% c(1, 2, 3, 4), # economic reasons
      wt = if_else(!is.na(WTFINL), WTFINL, 0)
    )
}

# Clean education groups similar to BLS foreign-born release categories.
mutate_education <- function(df) {
  df %>%
    mutate(
      educ_group = case_when(
        EDUC %in% 2:71 ~ "Less than high school",
        EDUC %in% 72:100 ~ "High school graduate",
        EDUC %in% 110:121 ~ "Some college or associate",
        EDUC %in% 122:125 ~ "Bachelor's degree",
        EDUC >= 126 ~ "Advanced degree",
        TRUE ~ NA_character_
      ),
      educ_group = factor(
        educ_group,
        levels = c(
          "Less than high school",
          "High school graduate",
          "Some college or associate",
          "Bachelor's degree",
          "Advanced degree"
        )
      )
    )
}

# Aggregate helper for a given grouping variable.
summarise_labor_metrics <- function(df, group_vars = c("nativity_group")) {
  df %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      population = sum(wt, na.rm = TRUE),
      labor_force = sum(wt * is_labor_force, na.rm = TRUE),
      employed = sum(wt * is_employed, na.rm = TRUE),
      unemployed = sum(wt * is_unemployed, na.rm = TRUE),
      part_time = sum(wt * is_part_time, na.rm = TRUE),
      part_time_econ = sum(wt * (is_part_time & part_time_econ), na.rm = TRUE),
      full_time = sum(wt * is_full_time, na.rm = TRUE),
      median_weekly_earn = weighted.median(EARNWEEK, wt = wt, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      lfpr = labor_force / population,
      emp_pop_ratio = employed / population,
      unemployment_rate = unemployed / labor_force,
      part_time_share = part_time / employed,
      part_time_econ_share = part_time_econ / employed,
      full_time_share = full_time / employed
    ) %>%
    adorn_totals(name = "All", fill = NA) %>%
    mutate(reference_year = reference_year) %>%
    select(reference_year, everything())
}

# Weighted median helper; defaults to stats::weighted.median if available.
weighted.median <- function(x, wt, na.rm = TRUE) {
  stats::weighted.median(x, w = wt, na.rm = na.rm)
}

# Convenience table writer.
write_summary_table <- function(tbl, name) {
  path <- file.path(table_dir, paste0(name, ".csv"))
  readr::write_csv(tbl, path)
  message(glue("Saved summary table: {path}"))
}

# ---- main workflow -------------------------------------------------------

cps_raw <- read_cps_extract(ddi_path, data_path)

cps_prepped <- cps_raw %>%
  mutate_nativity() %>%
  mutate_labor_status() %>%
  mutate_education() %>%
  clean_names()

# Overall headline indicators.
headline_tbl <- summarise_labor_metrics(cps_prepped)
write_summary_table(headline_tbl, "headline_labor_indicators")

# Breakdowns by sex.
sex_tbl <- summarise_labor_metrics(cps_prepped, group_vars = c("nativity_group", "sex"))
write_summary_table(sex_tbl, "labor_indicators_by_sex")

# Breakdowns by education.
education_tbl <- cps_prepped %>%
  filter(!is.na(educ_group)) %>%
  summarise_labor_metrics(group_vars = c("nativity_group", "educ_group"))
write_summary_table(education_tbl, "labor_indicators_by_education")

# Breakdowns by broad occupation.
occupation_tbl <- cps_prepped %>%
  mutate(occ_major = substr(as.character(occ), 1, 2)) %>%
  summarise_labor_metrics(group_vars = c("nativity_group", "occ_major"))
write_summary_table(occupation_tbl, "labor_indicators_by_occupation2digit")

# Optional: example visualization of unemployment rate by nativity.
headline_plot <- headline_tbl %>%
  filter(nativity_group != "All") %>%
  mutate(unemployment_pct = unemployment_rate * 100) %>%
  ggplot(aes(x = nativity_group, y = unemployment_pct, fill = nativity_group)) +
  geom_col(width = 0.6) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = glue("Unemployment rate by nativity, {reference_year}"),
    x = NULL,
    y = "Percent of labor force",
    caption = "Source: Author's calculations using CPS Basic Monthly microdata (IPUMS CPS)."
  ) +
  guides(fill = "none")

ggplot2::ggsave(
  filename = file.path(figure_dir, glue("unemployment_rate_{reference_year}.png")),
  plot = headline_plot,
  width = 6,
  height = 4,
  dpi = 300
)

message("Analysis complete.")

