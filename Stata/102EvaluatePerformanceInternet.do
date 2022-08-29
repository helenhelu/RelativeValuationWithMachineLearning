* ----------------------------------------------------------------------------
* EvaluatePerformanceInternet
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
* performance (all models in internet appendix)
*---------------------------------------------------------------------

use combined_${mrun}, clear

local additional_models ML_m ML_lnm ML_m2b Tree_lnm2b Tree_lnv2a Tree_lnv2s AS_lnm2b AS_lnv2a AS_lnv2s

egen count_missing = rowmiss(value_pred_ML* value_pred_RRV* value_pred_BL* value_pred_IND* value_pred_BG* value_pred_Tree*)

* performance table variables and numerical formats
local thevariables  N      mdape mape  p50pe  mpe   sdpe  y_rmse  value_rmse   y_r2oos value_r2oos value_rho
local theformats    %9.0fc %4.2f %4.2f %4.2f  %4.2f %4.2f %4.2fc  %9.0fc        %4.2f   %4.2f         %4.2f

foreach sampletype in available similar {
    
	local thefile ${results}\\comparison_all_`sampletype'_${mrun}.tex 
	
	* see Utils.do for measures_footer code
	measures_header `thevariables' using `thefile' 
	
	foreach v in `additional_models' {
		
		local row_header = subinstr("`v'", "_", "\_", .)
		if "`sampletype'" == "available" {
		    local data_availability
		}
		else {
		    local data_availability & count_missing == 0
		}
		
		* see Utils.do for calcmeasures and measures_line code
		* calcmeasures <y_pred>    <y_true>    <y_train_mean>    <value_pred>    <value_true>    <value_train_mean>    <logvalue_train_mean>
		calcmeasures    y_pred_`v'  y_true_`v'  y_train_mean_`v'  value_pred_`v'  value_true_`v'  value_train_mean_`v'  logvalue_train_mean_`v' if !missing(value_pred_`v') `data_availability'
		return list
		measures_line `thevariables' using `thefile' , result("`row_header'") formatlist(`theformats')
		
	}
	
	* see Utils.do for measures_footer code
	measures_footer using `thefile'
}
