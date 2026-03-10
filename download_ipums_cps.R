#!/usr/bin/env Rscript
# Purpose: Submit and download an IPUMS CPS extract containing key labor market variables.
# Requires: ipumsr >= 0.7.0 with IPUMS API support enabled.
#
# Before running:
#   1. Install ipumsr: install.packages("ipumsr")
#   2. Obtain an IPUMS API key from https://account.ipums.org/api_keys
#   3. Export the key as an environment variable, e.g.:
#        Sys.setenv(IPUMS_API_KEY = "XXXXXXXXXXXXXXXX")
#   4. (Optional) Adjust the year/month range or variable list below.

suppressPackageStartupMessages({
  library(ipumsr)
  library(glue)
})

# ---- configuration -------------------------------------------------------

# Reference year for data pull. Adjust as needed.
reference_year <- 2023L

# Months to include for the given year (1-12 for the full calendar year).
target_months <- 1:12

# IPUMS CPS variable list (documented in immigration_data_plan.md).
core_variables <- c(
  "YEAR", "MONTH", "CPSID", "CPSIDP",
  "ASECFLAG", "WTFINL", "ASECWT",
  "AGE", "SEX", "RACE", "HISPAN",
  "NATIVITY", "CITIZEN",
  "EDUC",
  "EMPSTAT", "LABFORCE",
  "UHRSWORKT", "UHRSWORKLY",
  "PTREASON",
  "OCC", "IND",
  "CLASSWKR", "PAIDHOUR", "EARNWEEK"
)

# Destination directory for downloaded extract files.
download_dir <- file.path("data", "raw")

# Friendly description recorded with the IPUMS extract.
extract_description <- glue("CPS basic monthly pooled {reference_year} (domestic vs foreign born)")

# ---- validation ----------------------------------------------------------

api_key <- Sys.getenv("IPUMS_API_KEY")
if (!nzchar(api_key)) {
  stop(
    "No IPUMS_API_KEY detected. Set it via Sys.setenv(IPUMS_API_KEY = \"<your-key>\") ",
    "or add it to your .Renviron before running this script."
  )
}

if (!dir.exists(download_dir)) {
  dir.create(download_dir, recursive = TRUE, showWarnings = FALSE)
}

# Register the key for the CPS collection (kept in R session cache).
ipumsr::set_ipums_api_key(api_key, "cps")

# ---- build extract definition -------------------------------------------

monthly_samples <- sprintf("cps_%d_%02d", reference_year, target_months)

cps_extract <- ipumsr::define_extract_cps(
  description = extract_description,
  samples = monthly_samples,
  variables = core_variables,
  data_format = "fixed_width"
)

message("Submitting IPUMS CPS extract request...")

submitted_extract <- ipumsr::submit_extract(cps_extract)

message(glue("Extract submitted (number: {submitted_extract$extract_number}). Awaiting processing..."))

# Poll until extract is ready. Adjust timeout as needed (default 12 hours).
completed_extract <- ipumsr::wait_for_extract(submitted_extract, timeout = 12 * 60 * 60)

message("Extract ready. Downloading files to: ", normalizePath(download_dir, winslash = "/"))

downloaded_files <- ipumsr::download_extract(completed_extract, download_dir = download_dir)

message("Downloaded files:")
for (f in downloaded_files) {
  message("  - ", f)
}

message("IPUMS CPS extract download complete. Remember to reference the extract number in immigration2.tex.")

