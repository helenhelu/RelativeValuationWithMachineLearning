* ----------------------------------------------------------------------------
* VariableImportanceSub
* ----------------------------------------------------------------------------

* ----------------------------------------------------------------------------
* Valution project, Copyright (C) Paul Geertsema and Helen Lu 2019 - 2022
* See "Relative Valuation with Machine Learning", Geertsema & Lu (2022)
* https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3740270
* ----------------------------------------------------------------------------

* ----------------------------------------------------------------------------
* This program is free software: you can redistribute it and/or modify it 
* under the terms of the GNU General Public License as published by the 
* Free Software Foundation, either version 3 of the License, or (at your option)
* any later version.

* This program is distributed in the hope that it will be useful, but 
* WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for 
* more details.

* You should have received a copy of the GNU General Public License along 
* with this program. If not, see <https://www.gnu.org/licenses/>.
* ----------------------------------------------------------------------------

* calculate quintiles

use combined_full_${mrun}, clear

rename crsp_market_equity Size
rename roe_wr ROE
rename m2b M2B
rename investment_an Investment

local sortvars Size M2B ROE Investment SalesGrowth

keep gvkeynum mth `sortvars'
sort gvkeynum mth

* only keep observations with valid ML predictions
merge 1:1 gvkeynum mth using combined_${mrun}, keep(master match) keepusing(value_error)
* only keep matches
keep if _merge == 3
drop _merge
drop value_error

su `sortvars'

* now create quintiles
foreach sv in `sortvars' {
	sort mth Investment
	gquantiles `sv'_quintile = `sv' if !missing(`sv'), xtile by(mth) nquantiles(5)
}

sort gvkeynum mth
save valuation_quintiles, replace


* get category definitions (saved in locals, see local categories for list)
* use -include- rather than -do- to keep local variables available
include ${code}\\categories.do



* merge in SHAP values 
* in absolute terms, scaled to 100% accross all variables for each observation
* only keep if shap values exist

local model1 Base${mrun}lnm2b
local model2 Base${mrun}lnv2s
local model3 Base${mrun}lnv2a

* SHAP importance by variable categories and sorting variable quintiles, for each model
foreach model in `model1' `model2'  `model3' {
    
	* get SHAP values (absolute shap values, scaled to add to 100% for each observation)
    use ABS_SHAP_`model'_combined.dta, clear
	
	* combine into categories
	foreach c in `categories' {
	    di "egen `c' = rowtotal(``c'')"
	    egen `c'_cat = rowtotal(``c'')
	}
	
	* collapse blocks, only keep categories
	gcollapse (mean) *_cat, by(gvkeynum mth) fast	
	sort gvkeynum mth
	
	* merge in quintiles
	merge 1:1 gvkeynum mth using valuation_quintiles, keep(master match) nogen keepusing(*_quintile)
	
	save SHAP_`model'_quintiles_${mrun}, replace
	
}



* SHAP importance by variable categories and sorting variable quintiles, for each model

local formatlist %2.0f %3.1f %3.1f %3.1f %3.1f %3.1f %3.1f %3.1f %3.1f %3.1f %3.1f %3.1f
local alignlist  lrrrrrrrrrrr
		
foreach model in `model1' `model2'  `model3' {
    	
	foreach sv in `sortvars' {
	    
		use SHAP_`model'_quintiles_${mrun}, clear    
		gcollapse (mean) *_cat, by(`sv'_quintile)
		ren *_cat *
		keep if !missing(`sv'_quintile)
		
		* present in percentage points
		unab varlist : *
		foreach c in `categories' {
		    replace `c' = `c'*100
		}
		ren `sv'_quintile Quintile
		
		unab varlist : *
		data2tex `varlist' using ${results}\SHAP_${mrun}`model'_`sv'_quintiles.tex, f(`formatlist') a(`alignlist') replace

	
	}
	
}

























