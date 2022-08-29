* ----------------------------------------------------------------------------
* AppendixVariables
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


*---------------------------------------------------------------------------
* Appendix Table  Variables used in ML
*---------------------------------------------------------------------------
*---------------------------------------------------------------------------
* ML variable description
*---------------------------------------------------------------------------

* describe variables (main) (APPENDIX)
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

di "`variables_used'"


*-------------------------------------------------------------------------------------------------------------------
* ML variable summary statistics Category Variable N mean p25 p50 p75 
* ML variable importance Category Variable SHAP_lnm2b SHAP_lnv2a SHAP_lnv2s rho_lnm2b  rho_lnv2a  rho_lnv2s----
*-------------------------------------------------------------------------------------------------------------------
foreach v in m2b v2a v2s {
    import delimited  ${results}\\Base${mrun}ML_ln`v'_rho.csv, clear
	ren v1 Variable
	ren v2 rho_ln`v'
	save ${results}\\Base${mrun}ML_ln`v'_rho, replace 
}

use  ${results}\\Base${mrun}ML_lnm2b_rho, clear
merge 1:1 Variable using ${results}\\Base${mrun}ML_lnv2a_rho, keep(match) nogen
merge 1:1 Variable using ${results}\\Base${mrun}ML_lnv2s_rho, keep(match) nogen
save ${results}\\Base${mrun}feature_rho, replace

use valuation_data_filtered_blocks, clear
gen Description = ""

local thefile ${results}\\MLsummarystats_${mrun}.csv
tempvar myfile
file open `myfile' using `thefile', write replace
foreach v in lnm2b lnv2a lnv2s  `variables_used' {
    local lab : var label `v'
	qui sum `v', detail
	file write `myfile' "`v'" "," "`lab'" "," "`r(N)'" "," "`r(mean)'" ","  "`r(sd)'" "," "`r(p1)'" "," "`r(p10)'" "," "`r(p50)'" "," "`r(p99)'"  "," "`r(p99)'"  _n
	
}
file close `myfile'

import delimited  ${results}\\MLsummarystats_${mrun}.csv, clear
ren v1 Variable
ren v2 Description
ren v3 N
ren v4 Mean
ren v5 SD
ren v6 p1
ren v7 p10
ren v8 p50
ren v9 p90
ren v10 p99


merge 1:1 Variable using ${results}\\Base${mrun}feature_rho, keep(master match) nogen
ren Variable variable

* merge in category (hard-coded data file)
merge 1:1 variable using ${source}\MLvars_category, keep(master match) nogen
replace category = "Target variable" if category == ""

merge 1:1 variable using Basefilteredlnm2b_ABS_SHAP_combined, keep(master match) nogen
drop cumulativescaledimportance
ren scaledimportance SHAP_lnm2b
replace SHAP_lnm2b = SHAP_lnm2b * 100

merge 1:1 variable  using Basefilteredlnv2a_ABS_SHAP_combined, keep(master match) nogen
drop cumulativescaledimportance
ren scaledimportance SHAP_lnv2a
replace SHAP_lnv2a = SHAP_lnv2a * 100

merge 1:1 variable  using Basefilteredlnv2s_ABS_SHAP_combined, keep(master match) nogen
drop cumulativescaledimportance
ren scaledimportance SHAP_lnv2s
replace SHAP_lnv2s = SHAP_lnv2s * 100

ren variable Variable
ren category Category


sort Category Variable

foreach v in Variable Description Category {
	replace `v' = subinstr(`v',"&", "\&", .)
	replace `v' = subinstr(`v',"_", "\_", .)
	replace `v' = subinstr(`v',"%", "\%", .)
}

sort Category Variable
local varlist Category Variable N Mean p1 p10 p50 p90 p99
local formatlist  %5s %5s  %9.0fc %5.2fc  %5.2fc   %5.2fc  %5.2fc   %5.2fc  %5.2fc 
local alignlist  llrrrrrrr

data2tex_longtable `varlist' using ${results}\\${mrun}summarystats1.tex, f(`formatlist') a(`alignlist') title(Summary statistics of variables used in machine learning models) reference(MLsum) replace

file close _all
sleep 1000
filefilter ${results}\\${mrun}summarystats1.tex ${results}\\${mrun}summarystats.tex, from("Financial\BS_soundness") to("Financial soundness") replace
	
	
drop if Category == "Target variable"
local varlist Category Variable SHAP_lnm2b SHAP_lnv2s SHAP_lnv2a rho_lnm2b rho_lnv2a rho_lnv2s
local formatlist  %5s %5s  %5.1f  %5.1f  %5.1f %5.2f  %5.2f   %5.2f
local alignlist  llrrrrrr

data2tex_longtable `varlist' using ${results}\\${mrun}feature_importance_detail1.tex, f(`formatlist') a(`alignlist') title(Variable importance in machine learning models) reference(MLsum) replace

file close _all
sleep 1000
filefilter ${results}\\${mrun}feature_importance_detail1.tex ${results}\\${mrun}feature_importance_detail2.tex, from("Financial\BS_soundness") to("Financial soundness") replace

file close _all
sleep 1000
filefilter ${results}\\${mrun}feature_importance_detail2.tex ${results}\\${mrun}feature_importance_detail3.tex, from("\BS_lnm2b") to("(lnm2b)") replace

file close _all
sleep 1000
filefilter ${results}\\${mrun}feature_importance_detail3.tex ${results}\\${mrun}feature_importance_detail4.tex, from("\BS_lnv2a") to("(lnv2a)") replace

file close _all
sleep 1000
filefilter ${results}\\${mrun}feature_importance_detail4.tex ${results}\\${mrun}feature_importance_detail.tex, from("\BS_lnv2s") to("(lnv2s)") replace


save ${results}\MLsummarystats_${mrun}, replace


