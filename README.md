# water-use-timeseries
pulling and processing water use data from NWIS

Uses the dataRetrieval package for R to programmatically access the water use data from the National Water Information System using the readNWISuse function. This allows for national, state, or county-level queries of water use over time. The wu_fetch.R script fetches and simplifies state-level water use data. Variable endings with "1000" are expressed in thousands, and all water use quatities are in Mgal/d (millions of gallons a day). 

use_state_time.csv -
The key variables are state_name, year, water_use, and total. "total" quantifies total water withdrawals for the given location, year, and water use category. The other columns capture different types or sources of the total water use, where gw = groundwater, sw = surface water, and fresh or saline water. Total should be equal to gw + sw AND fresh + saline. This is not always the case due to differences in reporting and missing data. If you wanted to use either of these subcategories of the data in addition to total, I would suggest creating a new total variable that is either gw+sw or fresh+saline to make sure the numbers add up.

use_publicsupply.csv - 
This is similar but captures just public supply variables and population. Public supply is broken into similar categories, including the number of supply facilities (ps_facilities), gallons per person a day (ps_gallons_person_day), the population served by gw and sw (ps_pop_gw/sw_1000), reclaimed use (ps_reclaimed), and the public supply stemming from freshwater, saline, gw, sw, and total.