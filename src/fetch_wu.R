
# set up ------------------------------------------------------------------

library(tidyverse)
library(dataRetrieval)
library(purrr)
library(data.table)
library(reshape2)

# fetch water use data  ---------------------------------------------------
## using dataRetrival to pull from NWIS https://waterdata.usgs.gov/nwis/wu

## national scale timeseries data
wu_nation <- readNWISuse(stateCd = NULL, countyCd = NULL, transform = TRUE)
wu_nation # 5 yr incremental data for population, withdrawls, etc
colnames(wu_nation)

# pull most important features at state and county level over time
## state--level data
wu_states <- purrr::map(state.abb, ~readNWISuse(stateCd = .x, countyCd = NULL, convertType = TRUE)) %>%
  rbindlist()

# groupings
wu_vars <- wu_states[,c(2:4)]
colnames(wu_vars) <- c('state_name', 'year', 'population_1000')

# filter to withdrawal total variables - includes overall total and by saline / fresh & broken down by gw/sw
wu_keep <- wu_states %>% select(contains('Mgal') & contains('withdrawals') & contains('total'),
                                -contains("Hydroelectric"), -contains("Fossil"), -contains("Geothermal"),-contains("Nuclear"), 
                                -contains("Closed"), -contains("Once"), -contains('Deliveries'))  # drop subcategories in thermoelectric and irrigation

# combine with state and year variables, relassify water use categories
wu_clean <- wu_vars %>%
  cbind(wu_keep) %>%
  mutate(across(where(is.double) | where(is.character) & !c(state_cd, state_name, year), ~as.numeric(.x))) %>%
  pivot_longer(!c(state_cd, state_name, year), "use", "use_value") %>%
  mutate(used = use, use = str_split(tolower(use), '\\.')) %>%
  rowwise() %>%
  mutate(water_source = case_when(
           'groundwater' %in% unlist(use) ~ 'gw',
           'surface' %in% unlist(use) ~ 'sw',
           TRUE ~ 'total'
         ),
         water_type = case_when(
           'saline' %in% unlist(use) ~ 'saline',
           'fresh' %in% unlist(use) ~ 'fresh',
           TRUE ~ 'both'
         ),
         water_use = case_when(
           'public' %in% unlist(use) ~ 'public supply',
           'irrigation' %in% unlist(use) ~ 'irrigation',
           'industrial' %in% unlist(use) ~ 'industrial',
           'thermoelectric' %in% unlist(use) ~ 'thermoelectric',
           'domestic' %in% unlist(use) ~ 'domestic',
           'livestock' %in% unlist(use) ~ 'livestock',
           'mining' %in% unlist(use) ~ 'mining',
           'aquaculture' %in% unlist(use) ~ 'aquaculture'
         )
  ) %>%
  ungroup()

# create new variables based on type of water for surface water, groundwater, saline, and freshwater
wu_clean_time <- wu_clean %>% 
  filter(!is.na(water_use)) %>%
  mutate(water_kind = case_when(
    water_source == "total" & water_type == "both" ~ 'total',
    water_source == "total" & water_type == "fresh" ~ 'fresh',
    water_source == "total" & water_type == "saline" ~ 'saline',
    water_source == "gw" & water_type == "both" ~ 'gw',
    water_source == "sw" & water_type == "both" ~ 'sw'
  )) %>% 
  select(state_name, year, water_use, water_kind, value) %>%
  filter(!is.na(water_kind)) %>%
    group_by(state_name, year, water_use, water_kind) %>%
    summarize(value = sum(value, na.rm = TRUE)) %>%
  dcast(state_name + year + water_use ~ water_kind, value.var = "value") %>%
  left_join(wu_vars)
str(wu_clean_time)

# export state-level timeseries of water use categories by type/source
# # using multiple total columns to account for differences in reporting
wu_clean_time %>% 
  select(state_name, year, water_use, sw, gw, saline, fresh, total) %>%
  mutate(total_type = saline+fresh, total_source = gw+sw) %>%
  write_csv("out/use_state_time.csv")

# population trend and public supply --------------------------------------

## generate timeseries data on population trend and public supply
ps_keep <- wu_states %>% select(contains("Public.Supply"), -contains("deliveries"))

ps_clean <- wu_states[,c(1:3)] %>%
  cbind(ps_keep) %>%
  mutate(across(where(is.double) | where(is.character) & !c(state_cd, state_name, year), ~as.numeric(.x))) %>%
  pivot_longer(!c(state_cd, state_name, year), "use", "use_value") %>%
  mutate(used = use, use = str_split(tolower(use), '\\.')) %>%
  rowwise() %>%
  mutate(water_source = case_when(
    'groundwater' %in% unlist(use) ~ 'gw',
    'surface' %in% unlist(use) ~ 'sw',
    TRUE ~ 'total'
  ),
  water_type = case_when(
    'saline' %in% unlist(use) ~ 'saline',
    'fresh' %in% unlist(use) ~ 'fresh',
    TRUE ~ 'both'
  ),
  water_use =  'public supply') %>%
  ungroup()%>%
  dcast(state_name+year+water_use~used, value.var = "value")
ps_clean %>% str

colnames(ps_clean) <- c("state_name", "year", "water_use", "ps_facilities", "ps_gallons_person_day", "ps_pop_gw_1000", "ps_pop_sw_1000",
                        "ps_use_loss", "ps_reclaimed", "ps_gw_fresh", "ps_gw_saline", "ps_sw_fresh", "ps_sw_saline", "ps_pop_served_1000", "ps_fresh", "ps_gw","ps_saline","ps_sw","ps_total")

str(ps_clean)

# reduce variables
ps_clean %>% select(state_name:water_use, ps_gallons_person_day:ps_pop_sw_1000, ps_reclaimed, ps_pop_served_1000:ps_total) %>%
  write_csv("/Users/cnell/Documents/Projects/water-use-tiout/use_publicsupply.csv")


# fetch county-level data -------------------------------------------------



## county-level data
wu_county <- purrr::map(state.abb, ~readNWISuse(stateCd = .x, countyCd = 'ALL', convertType = TRUE))
str(wu_states)

