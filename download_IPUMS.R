# R Script for Building Custom Annual Time Series from IPUMS CPS Microdata

# 1. Installation and Setup
# -------------------------
# Install the necessary packages if you haven't already
# install.packages("ipumsr")
# install.packages("dplyr")
# install.packages("lubridate")

library(ipumsr)
library(dplyr)
library(lubridate)

# Set your IPUMS API key. Replace "YOUR_API_KEY" with the key from your IPUMS account.
# It is best practice to store this as an environment variable.
# NOTE: The `overwrite = TRUE` argument is added to prevent an error if the key
# has already been saved from a previous run of the script.
set_ipums_api_key("59cba10d8a5da536fc06b59d04e2641adbaa490aafb610fb9b8077d4", overwrite = TRUE, save = TRUE)



# 2. Define and Submit the IPUMS Extract
# --------------------------------------
# This defines an extract request for the IPUMS CPS ASEC data.
# It selects all years from 1994 to the most recently available year.
# It includes the variables listed in Table 2.

# Find the most recent available ASEC/March sample year
latest_year <- get_sample_info("cps") %>%
  filter(grepl("03s", name)) %>% # ASEC is the March supplement (_03s)
  mutate(year = as.numeric(substr(name, 4, 7))) %>%
  summarise(max_year = max(year, na.rm = TRUE)) %>%
  pull(max_year)

# The sample names for the ASEC/March supplement use the "_03s" suffix.
cps_extract_request <- define_extract_cps(
  description = "Annual Labor Market Data by Nativity, 1994-Present",
  samples = paste0("cps", seq(1994, latest_year), "_03s"),
  variables = c("YEAR", "ASECWTH", "NATIVITY", "LABFORCE", "EMPSTAT", "AGE", "SEX")
)

# Submit the extract request to the IPUMS API
submitted_extract <- submit_extract(cps_extract_request)

# Wait for the extract to be processed by the IPUMS servers.
# This can take several minutes. The function will print status updates.
downloadable_extract <- wait_for_extract(submitted_extract)


# 3. Download the Data
# --------------------
# Download the data and DDI metadata files to a local directory.
# Replace "path/to/your/directory" with your desired location.
dirpath = "C:/Users/E1SMP01/Dropbox/My Papers/LFP and FB"
data_files <- download_extract(downloadable_extract, download_dir = dirpath)


# 4. Read and Process the Microdata
# ---------------------------------
# Use read_ipums_micro to load the data. The.xml DDI file is used to apply labels.
cps_data <- read_ipums_micro(data_files)

# Process the microdata to calculate annual labor market statistics
annual_data_ipums <- cps_data %>%
  # Filter to the civilian noninstitutional population (age 16+)
  filter(AGE >= 16) %>%
  # Filter to valid nativity categories (1=Native-born, 5=Foreign-born)
  filter(NATIVITY %in% c(1, 5)) %>%
  # CORRECTED: Replaced the problematic lbl_collapse with a standard case_when
  mutate(nativity_status = case_when(
    NATIVITY == 1 ~ "Native-Born",
    NATIVITY == 5 ~ "Foreign-Born"
  )) %>%
  # Group by year and nativity status for aggregation
  group_by(YEAR, nativity_status) %>%
  # Calculate weighted sums using the ASECWTH variable. This is the most critical step.
  # CORRECTED: The logic now correctly subsets the weights for each category before summing.
  summarise(
    # Population is the sum of weights for everyone in the group
    population = sum(ASECWTH),
    # Labor force is the sum of weights for those in the labor force (LABFORCE == 2)
    labor_force = sum(ASECWTH[LABFORCE == 2]),
    # Employed is the sum of weights for those employed (EMPSTAT is 10 or 12)
    employed = sum(ASECWTH[EMPSTAT %in% c(10, 12)]),
    # Unemployed is the sum of weights for those unemployed (EMPSTAT is 20, 21, or 22)
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
    nativity = nativity_status,
    labor_force_participation_rate = lfpr,
    employment_population_ratio = epop,
    unemployment_rate,
    labor_force_level = labor_force,
    employment_level = employed,
    population_level = population
  )

# Display the first few rows of the final annual time series
head(annual_data_ipums)

# This 'annual_data_ipums' data frame contains the longest possible consistent
# annual time series for these indicators, from 1994 to the present.


#-----------------------------------------

# 5. Plot the Time Series Data
# ----------------------------
# Install ggplot2 for plotting and tidyr for data manipulation, if needed.
# install.packages("ggplot2")
# install.packages("tidyr")

library(ggplot2)
library(tidyr)

# Reshape the data from a "wide" to a "long" format, which is ideal for ggplot2.
# This stacks the three indicator columns into a single column.
plotting_data <- annual_data_ipums %>%
  select(year, nativity, labor_force_participation_rate, employment_population_ratio, unemployment_rate) %>%
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

# Create the time series plot with separate panels for each indicator
ggplot(plotting_data, aes(x = year, y = rate, color = nativity, group = nativity)) +
  geom_line(linewidth = 1.1) +
  # Create a separate plot for each indicator and allow y-axes to adjust freely
  facet_wrap(~ indicator, scales = "free_y", ncol = 1) +
  labs(
    title = "U.S. Labor Market Indicators by Nativity Status",
    subtitle = "Annual Data from 1994 to Present",
    x = "Year",
    y = "Percent (%)",
    color = "Nativity Status"
  ) +
  # Apply a clean theme and adjust text elements for readability
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5),
    strip.text = element_text(face = "bold")
  )