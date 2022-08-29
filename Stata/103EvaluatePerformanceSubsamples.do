* ----------------------------------------------------------------------------
* EvaluatePerformanceSubsamples
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

*---------------------------------------------------------------------    
* Sub-sample performance
*---------------------------------------------------------------------

* performance table variables and numerical formats
* NOTE: omits OOS R^2 measures, as the reference training sample mean is not available
* for sub-samples.

local thevariables  N      mdape mape  p50pe  mpe   sdpe  y_rmse  value_rmse    value_rho
local theformats    %9.0fc %4.2f %4.2f %4.2f  %4.2f %4.2f %4.2fc  %9.0fc       %4.2f

* Re-produce the main table for different sample splits 
* (small/big, value/growth, high/low ROE).


use combined_full_${mrun}, clear

* drop dummy observations (used in ML code)
drop if hash100 == 100

* selected sorting variables
gen size = m
gen b2m = 1/m2b
gen roe = profitability_an

local sort_vars size b2m roe

* create terciles for sorting variables
foreach sv in `sort_vars' {
	gquantiles tercile_`sv' = `sv', xtile by(mth) nq(3)
}	


* only keep what we need
keep gvkeynum mth y_pred_* y_true_*  y_train_mean_*  value_pred_*  value_true_*  value_train_mean_*  logvalue_train_mean_* tercile_* `sort_vars' 

*-----------------------------------------------------------------------
* only IND models
*-----------------------------------------------------------------------

local thefile ${results}\\comparison_subsamples_available_IND_${mrun}.tex 
measures_header `thevariables' using `thefile' 

foreach v in IND_m2b IND_v2a IND_v2s {
	
	* loop through sortvars
	foreach sv in `sort_vars' {
	
		* loop through terciles
		forvalues tercile = 1(1)3 {
			
			

			local row_header = "`v' (`sv' tercile `tercile')"
			local row_header = subinstr("`row_header'", "_", "\_", .)
			di "`row_header'"
			
			* see Utils.do for calcmeasures code
			* calcmeasures <y_pred>    <y_true>    <y_train_mean>    <value_pred>    <value_true>    <value_train_mean>    <logvalue_train_mean>
			calcmeasures    y_pred_`v'  y_true_`v'  y_train_mean_`v'  value_pred_`v'  value_true_`v'  value_train_mean_`v'  logvalue_train_mean_`v' if tercile_`sv' == `tercile'
			return list
			
			* see Utils.do for measures_line code
			measures_line `thevariables' using `thefile' , result("`row_header'") formatlist(`theformats')
		
		}
		* see Utils.do for measures_emit code
		measures_emit "\hline" using `thefile'
	}
}
* see Utils.do for measures_emit code
measures_footer using `thefile'


*-----------------------------------------------------------------------
* only ML models
*-----------------------------------------------------------------------

local thefile ${results}\\comparison_subsamples_available_ML_${mrun}.tex 
measures_header `thevariables' using `thefile' 


foreach v in ML_lnm2b ML_lnv2a ML_lnv2s {
	
	* loop through sortvars
	foreach sv in `sort_vars' {
	
		* loop through terciles
		forvalues tercile = 1(1)3 {

			local row_header = "`v' (`sv' tercile `tercile')"
			local row_header = subinstr("`row_header'", "_", "\_", .)
			di "`row_header'"
			* calcmeasures <y_pred>    <y_true>    <y_train_mean>    <value_pred>    <value_true>    <value_train_mean>    <logvalue_train_mean>
			calcmeasures    y_pred_`v'  y_true_`v'  y_train_mean_`v'  value_pred_`v'  value_true_`v'  value_train_mean_`v'  logvalue_train_mean_`v' if tercile_`sv' == `tercile'
			return list
			
			measures_line `thevariables' using `thefile' , result("`row_header'") formatlist(`theformats')
		
		}
		measures_emit "\hline" using `thefile'
	}
}
measures_footer using `thefile'

*-----------------------------------------------------------------------
* only alt ML models (ML_m ML_lnm)
*-----------------------------------------------------------------------

local thefile ${results}\\comparison_subsamples_available_MLalt_${mrun}.tex 
measures_header `thevariables' using `thefile' 


foreach v in ML_m ML_lnm {
	
	* loop through sortvars
	foreach sv in `sort_vars' {
	
		* loop through terciles
		forvalues tercile = 1(1)3 {

			local row_header = "`v' (`sv' tercile `tercile')"
			local row_header = subinstr("`row_header'", "_", "\_", .)
			di "`row_header'"
			* calcmeasures <y_pred>    <y_true>    <y_train_mean>    <value_pred>    <value_true>    <value_train_mean>    <logvalue_train_mean>
			calcmeasures    y_pred_`v'  y_true_`v'  y_train_mean_`v'  value_pred_`v'  value_true_`v'  value_train_mean_`v'  logvalue_train_mean_`v' if tercile_`sv' == `tercile'
			return list
			
			measures_line `thevariables' using `thefile' , result("`row_header'") formatlist(`theformats')
		
		}
		measures_emit "\hline" using `thefile'
	}
}
measures_footer using `thefile'

