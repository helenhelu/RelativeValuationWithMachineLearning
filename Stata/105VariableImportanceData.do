* ----------------------------------------------------------------------------
* VariableImportanceData
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



* (1) feature importance (SHAP): all, new and old economy
* (2) generate feature importance by decade: all, new and old economy
* (3) generate feature importance by year: all, new and old economy 
* (4) describe variables (main) (APPENDIX)

local model1 Base${mrun}lnm2b
local model2 Base${mrun}lnv2s
local model3 Base${mrun}lnv2a

* (1) feature importance (SHAP), all, new and old economy
foreach eco in "" "_Neweconomy" "_Oldeconomy" {
	foreach model in `model1' `model2'  `model3' {
		use ABS_SHAP_`model'_combined.dta, clear
		
		if "`eco'" != "" {
			merge 1:1 gvkeynum mth using neweconomy, keep(master match) nogen
			local v = substr("`eco'",2,.)
			keep if `v' == 1
			drop `v'
		}

		gen dummy = 1

		unab all_vars : *
		local remove_vars mth block gvkeynum dummy
		local predictors : list all_vars - remove_vars
		
		* di "`=wordcount("`predictors'")'"
		
		gcollapse (mean) `predictors', by(dummy)
		xpose, clear
		drop in 1
		ren v1 scaledimportance
		gen variable = ""
		local k = 0
		foreach v in `predictors' {
			local ++k
			replace variable = "`v'" in `k'
		}
		gsort -scaledimportance
		gen cumulativescaledimportance = sum(scaledimportance)
		
		drop if variable == "`eco'"
		save `model'_ABS_SHAP`eco'_combined.dta, replace
	}
}



* ----------------------------------------------------------------------------
* (2) generate feature importance by decade: all, new and old economy
* ----------------------------------------------------------------------------

foreach eco in "" "_Neweconomy" "_Oldeconomy" {
	foreach model in  `model1' `model2'  `model3' {
		
		use ABS_SHAP_`model'_combined.dta, clear
		if "`eco'" != "" {
			merge 1:1 gvkeynum mth using neweconomy, keep(master match) nogen
			local v = substr("`eco'",2,.)
			keep if `v' == 1
			drop `v'
		}
		
		gen dummy = 1

		unab all_vars : *
		local remove_vars mth block gvkeynum dummy
		local predictors : list all_vars - remove_vars
		
		di "`=wordcount("`predictors'")'"

		gen decade = floor(year(dofm(mth))/10)*10
		sort decade
		gcollapse (mean) `predictors', by(decade) fast
		
		xpose, clear

		* rename columns after decades
		unab columns : *
		di "`columns'"
		foreach v in `columns' {
			ren `v' D`=`v'[1]'
		}
		
		drop in 1
		
		* write back variable names
		gen variable = ""
		local k = 0
		foreach v in `predictors' {
			local ++k
			replace variable = "`v'" in `k'
		}

		save ABS_SHAP_by_decade_`model'`eco', replace
		
		unab decades : D*
		
		* save different dataset for each decade
		foreach v in `decades' {
			use ABS_SHAP_by_decade_`model'`eco', clear
			keep variable `v'
			ren `v' scaledimportance
			gsort -scaledimportance
			gen cumulativescaledimportance = sum(scaledimportance)
			local d=substr("`v'",2,.)
			save `model'_ABS_SHAP_combined_`d'`eco', replace
		}
	}	
}


* ----------------------------------------------------------------------------
* (3) generate feature importance by year: all, new and old economy
* ----------------------------------------------------------------------------

foreach eco in "" "_Neweconomy" "_Oldeconomy" {
	foreach model in  `model1' `model2'  `model3' {
		use ABS_SHAP_`model'_combined.dta, clear
		
		if "`eco'" != "" {
			merge 1:1 gvkeynum mth using neweconomy, keep(master match) nogen
			local v = substr("`eco'",2,.)
			keep if `v' == 1
			drop `v'
		}
		
		gen dummy = 1

		unab all_vars : *
		local remove_vars mth block gvkeynum dummy
		local predictors : list all_vars - remove_vars
		
		di "`=wordcount("`predictors'")'"

		gen year = year(dofm(mth))
		sort year
		gcollapse (mean) `predictors', by(year) fast
		
		xpose, clear

		* rename columns after decades
		unab columns : *
		di "`columns'"
		foreach v in `columns' {
			ren `v' Y`=`v'[1]'
		}
		
		drop in 1
		
		* write back variable names
		gen variable = ""
		local k = 0
		foreach v in `predictors' {
			local ++k
			replace variable = "`v'" in `k'
		}

		save ABS_SHAP_by_year_`model'`eco', replace
		
		unab years : Y*
		
		* save different dataset for each decade
		foreach v in `years' {
			use ABS_SHAP_by_year_`model'`eco', clear
			keep variable `v'
			ren `v' scaledimportance
			gsort -scaledimportance
			gen cumulativescaledimportance = sum(scaledimportance)
			local y=substr("`v'",2,.)
			save `model'_ABS_SHAP_combined_Y`y'`eco', replace
		}
	}
}
	
	
* ----------------------------------------------------------------------------		
* (4) describe variables (main) (APPENDIX)
* ----------------------------------------------------------------------------

local model Base${mrun}lnm2b
use `model'_ABS_SHAP_combined, clear
sort variable
* make a list of variables used
local variables_used
forvalues k = 1/`=_N' {
    di "`k'"
	if "`=variable[`k']'" != "unit" {
		local variables_used `variables_used' `=variable[`k']'
	}
}

* Table in Appendix has Variable Category and Description (Note)
** generate a dta with variable and label
use valuation_data_filtered_blocks, clear
local thefile ${results}\\variable_label.csv
tempvar myfile
file open  `myfile' using  `thefile', write replace
foreach v in `variables_used' {
	* retrieve label
	local lab : var label `v'
	file write `myfile' "`v'" "," "`lab'" _n
}	
file close `myfile'


import delimited ${results}\\variable_label.csv, clear
ren v1 Variable
ren v2 Description
save ${results}\\variable_label, replace

use valuation_data_filtered_blocks, clear
describevariables lnm2b lnv2a lnv2s `variables_used' using ${results}\\variables_used_main.tex, title(Variables description) reference(vardesc)


