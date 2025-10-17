# R Script for Building and Plotting Annual Time Series 
# for Native-Born, Recent Immigrants, and Prior Immigrants
# from IPUMS CPS Microdata

# 1. Installation and Setup
# -------------------------
# Install the necessary packages if you haven't already
# install.packages("ipumsr")
# install.packages("dplyr")
# install.packages("lubridate")
# install.packages("ggplot2")
# install.packages("tidyr")

library(ipumsr)
library(dplyr)
library(lubridate)
library(ggplot2)
library(tidyr)

# Set your IPUMS API key. It is best practice to store this as an environment variable.
# NOTE: The `overwrite = TRUE` argument prevents an error if the key was saved previously.
set_ipums_api_key("59cba10d8a5da536fc06b59d04e2641adbaa490aafb610fb9b8077d4", overwrite = TRUE, save = TRUE)


# 2. Define and Submit the IPUMS Extract
# --------------------------------------
# This defines an extract request for IPUMS CPS ASEC data from 1994 to present.
# It includes the standard labor force variables plus YRIMMIG to identify arrival cohorts.

# Find the most recent available ASEC/March sample year
latest_year <- get_sample_info("cps") %>%
  filter(grepl("03s", name)) %>% # ASEC is the March supplement (_03s)
  mutate(year = as.numeric(substr(name, 4, 7))) %>%
  summarise(max_year = max(year, na.rm = TRUE)) %>%
  pull(max_year)

# Define the extract, making sure to include YRIMMIG
cps_extract_request <- define_extract_cps(
  description = "Annual Labor Market Data by Arrival Cohort, 1994-Present",
  samples = paste0("cps", seq(1994, latest_year), "_03s"),
  variables = c("YEAR", "ASECWTH", "NATIVITY", "LABFORCE", "EMPSTAT", "AGE", "SEX", "YRIMMIG")
)

# Submit the extract request to the IPUMS API
submitted_extract <- submit_extract(cps_extract_request)

# Wait for the extract to be processed. This can take several minutes.
downloadable_extract <- wait_for_extract(submitted_extract)


# 3. Download the Data
# --------------------
# Download the data and DDI metadata files to a local directory.
# Replace with your desired location.
dirpath = "C:/Users/E1SMP01/Dropbox/My Papers/LFP and FB"
data_files <- download_extract(downloadable_extract, download_dir = dirpath)


# 4. Read and Process the Microdata
# ---------------------------------
# Use read_ipums_micro to load the data with labels.
cps_data <- read_ipums_micro(data_files)

# Process the microdata to calculate annual labor market statistics
annual_data_by_arrival <- cps_data %>%
  # Filter to the civilian noninstitutional population (age 16+)
  filter(AGE >= 16) %>%
  # Filter to valid nativity categories
  filter(NATIVITY %in% c(1, 5)) %>%
  
  # Create a new grouping variable based on arrival cohort
  mutate(immigrant_group = case_when(
    NATIVITY == 1 ~ "Native-Born",
    # "Recent Migrants" are foreign-born who arrived in the *previous* calendar year
    NATIVITY == 5 & YRIMMIG == (YEAR - 1) ~ "Recent Immigrant (Arrived Last Year)",
    # "Prior Migrants" are all other foreign-born with a valid immigration year
    NATIVITY == 5 & YRIMMIG < (YEAR - 1) & YRIMMIG > 0 ~ "Prior Immigrant",
    # All others are grouped as "Other"
    TRUE ~ "Other"
  )) %>%
  # Filter out any groups we don't want
  filter(immigrant_group %in% c("Native-Born", "Recent Immigrant (Arrived Last Year)", "Prior Immigrant")) %>%
  
  # Group by year and this new immigrant status
  group_by(YEAR, immigrant_group) %>%
  
  # Calculate weighted sums using the ASECWTH variable
  summarise(
    population = sum(ASECWTH),
    labor_force = sum(ASECWTH[LABFORCE == 2]),
    employed = sum(ASECWTH[EMPSTAT %in% c(10, 12)]),
    unemployed = sum(ASECWTH[EMPSTAT %in% c(20, 21, 22)]),
    .groups = 'drop'
  ) %>%
  
  # Calculate the final rates from the weighted sums
  mutate(
    lfpr = (labor_force / population) * 100,
    epop = (employed / population) * 100,
    unemployment_rate = (unemployed / labor_force) * 100
  ) %>%
  
  # Select and rename final columns for clarity
  select(
    year = YEAR,
    group = immigrant_group,
    labor_force_participation_rate = lfpr,
    employment_population_ratio = epop,
    unemployment_rate
  )

# Display the first few rows of the final annual time series
print("Final Processed Data:")
head(annual_data_by_arrival)


# 5. Plot the Time Series Data
# ----------------------------
# Reshape the data from a "wide" to a "long" format for ggplot2
plotting_data <- annual_data_by_arrival %>%
  pivot_longer(
    cols = c(labor_force_participation_rate, employment_population_ratio, unemployment_rate),
    names_to = "indicator",
    values_to = "rate"
  ) %>%
  # Improve the labels for the plot facets
  mutate(indicator = factor(indicator, levels = c(
    "labor_force_participation_rate",
    "employment_population_ratio",
    "unemployment_rate"
  ), labels = c(
    "Labor Force Participation Rate (%)",
    "Employment-Population Ratio (%)",
    "Unemployment Rate (%)"
  )))

# Create the time series plot
ggplot(plotting_data, aes(x = year, y = rate, color = group, group = group)) +
  geom_line(linewidth = 1.1) +
  # Create a separate plot for each indicator
  facet_wrap(~ indicator, scales = "free_y", ncol = 1) +
  labs(
    title = "U.S. Labor Market Indicators by Nativity and Arrival Cohort",
    subtitle = "Annual Data from 1994 to Present",
    x = "Year",
    y = "Percent (%)",
    color = "Immigrant Group"
  ) +
  # Apply a clean theme and adjust text elements for readability
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5),
    strip.text = element_text(face = "bold")
  )