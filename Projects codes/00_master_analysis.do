clear all
set more off

global datathon "[FILE PATH HERE]/Reopening-of-super-spreader-businesses-and-risk-of-COVID-19-transmission-"

/************************************************************
AIM 1: GENERATE SUPER-SPREADER BUSINESSES INDEX 
AND DEFINE SUPER SPREADER BUSINESSES BY NAICS CODE
************************************************************/


use "$datathon/Project dataset/raw_patterns_CT_RI_2019.dta", clear 

* NAICS sector is the first 2 digits of the NAICS code
gen naics_2 = int(naics/10000) 

* Get visits and duration of visits in 2019 by NAICS codes
collapse (sum) raw_visit_counts est_total_dwell (mean) median_dwell (first) naics_2, by(naics_code)

rename raw_visit_counts total_visits
rename median_dwell avg_median_dwell


* Label the sectors
gen business_type = "Food" if naics_2 == 72
replace business_type = "Entertainment" if naics_2 == 71
replace business_type = "Retail" if naics_2 == 44 | naics_2 == 45
replace business_type = "Agriculture, Forestry, Fishing and Hunting" if naics_2 == 11
replace business_type = "Utilities" if naics_2 == 22
replace business_type = "Construction" if naics_2 == 23
replace business_type = "Manufacturing" if naics_2 ==31
replace business_type = "Manufacturing" if naics_2 ==32
replace business_type = "Manufacturing" if naics_2 ==33
replace business_type = "Wholesale Trade" if naics_2 ==42
replace business_type = "Transportation and Warehousing" if naics_2 ==48
replace business_type = "Transportation and Warehousing" if naics_2 ==49
replace business_type = "Information" if naics_2 ==51
replace business_type = "Finance and Insurance" if naics_2 ==52
replace business_type = "Real Estate Rental and Leasing" if naics_2 ==53
replace business_type = "Professional, Scientific, and Technical Services" if naics_2 ==54
replace business_type = "Management of Companies and Enterprises" if naics_2 ==55
replace business_type = "Administrative and Support and Waste Management and Remediation Services" if naics_2 == 56
replace business_type = "Educational Services" if naics_2 ==61
replace business_type = "Health Care and Social Assistance" if naics_2 ==62
replace business_type = "Arts, Entertainment, and Recreation" if naics_2 ==71
replace business_type = "Accommodation and Food Services" if naics_2 ==72
replace business_type = "Other Services (except Public Administration)" if naics_2 ==81
replace business_type = "Public Administration" if naics_2 == 92

* Can't classify missing NAICS
drop if naics_2 == .

* Convert dwell time in minutes to dwell time in days, since now looking over all of 2019
gen total_dwell_in_days = est_total_dwell/60/24

* Label quartiles of dwell time
xtile quartile_dwell = total_dwell_in_days, nquantiles(4)

* Define super-spreader as businesses in the top quartile of dwell index
gen super_spreader = 0
replace super_spreader = 1 if quartile_dwell == 4

* Keep NAICS code and super-spreader status 
keep naics_code super_spreader

save "$datathon/Project dataset/superspreader_index.dta", replace
export excel using "$datathon/Project dataset/superspreader_index.xlsx", firstrow(variables) replace
export delimited using "$datathon/Project dataset/superspreader_index.csv", replace

					
					
					
					
					
/************************************************************
AIM 2: EXPLORE ASSOCIATION BETWEEN 
COVID CASES AND SUPER SPREADER BUSINESSES
************************************************************/

						
clear all
set more off

global datathon "[FILE PATH HERE]/Reopening-of-super-spreader-businesses-and-risk-of-COVID-19-transmission-"

use "$datathon/Project dataset/raw_patterns_CT_RI_2020.dta", clear 

* Merge with superspreader indicator
merge m:1 naics_code using "$datathon/Project dataset/superspreader_index.dta"

* Drop businesses with no NAICS code
keep if _merge == 3
drop _merge

* Generate weekly start date
split date_range_start, p(T)
drop date_range_start date_range_start2
gen date = date(date_range_start1, "YMD")
format date %td
drop date_range_start1

* Tag each business so they can be summed during collapse
gen total_businesses = 1

* Collapse to county-week level of observation
collapse (sum) super_spreader total_businesses, by(countyfips date)

* Drop missing counties
drop if countyfips == .

* Rename countyfips so it can merge with census and covid-19 data
rename countyfips geoid
merge 1:1 geoid date using "$datathon/Project dataset/cases_ses_CT_RI.dta"

* Keep weekly measures
keep if _merge == 3
drop _merge
rename geoid countyfips

* Balance panel 
sort date
egen t = group(date)
keep if t >= 4 
replace t = t - 3

* Generate density of super spreaders out of total businesses
gen super_spreader_density = super_spreader/total_businesses*100

* Generate weekly new cases from cumulative measure
bys county (date): gen weekly_cases = cases - cases[_n-1]
* Replace first observation for a county with number of cases
replace weekly_cases = cases if weekly_cases==.

* Set control variables
global controls poverty over65 white black hispanic 

* Negative binomial regressions
nbreg cases super_spreader_density $controls t , ///
	exposure(population) vce(cluster countyfips)
eststo cases_cumulative

nbreg weekly_cases super_spreader_density $controls t , ///
	exposure(population) vce(cluster countyfips)
eststo cases_weekly

* Export results
estout *  using "$datathon/Output files/table2_results.xls", ///
	eform cells((b(star fmt(4) label(IRR)) p(label(p-value)) ) ///
	( se(par(`"="("' `")""' label(SE)) fmt(4)) ci(label(95% CI)))) stats(N, labels("Observations")) ///
	starlevels(* 0.1 ** 0.05 *** 0.01) ///
	title(Negative Binomial Results) label varlabels(_cons Constant) legend replace 
eststo clear

* Save final dataset
save "$datathon/Project dataset/final_dataset.dta", replace

