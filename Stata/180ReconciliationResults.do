* ----------------------------------------------------------------------------
* ReconciliationResults
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

foreach multiple in m2b v2a v2s {

	* 1) Import ML predictions from 10 BL variables
	
	di "load_predictions BLVarsfilteredln`multiple' ${startperiod} ${endperiod}"
	load_predictions BLVarsfilteredln`multiple' ${startperiod} ${endperiod}

	local model BL_ln`multiple'_gbm
	
	rename value_pred          value_pred_`model'
	rename value_true          value_true_`model'
	rename y_pred              y_pred_`model'
	rename y_true              y_true_`model'
	rename y_train_mean        y_train_mean_`model'
	rename value_train_mean    value_train_mean_`model'
	rename logvalue_train_mean logvalue_train_mean_`model'
	
	keep gvkeynum mth value_* y_* *_train_mean*
	
	drop value_error value_abserror
	save BL_ln`multiple'_gbm_${mrun}, replace
}

foreach multiple in m2b v2a v2s {	
	
	* 2) Import BL with OLS (done in 060BL.do)

	use combined_${mrun}, clear
	
	foreach v of varlist y_*_BL_`multiple' value_*_BL_`multiple' logvalue_*_BL_`multiple' {
		di "`v'"
		ren `v' `v'_ols
	}

	keep gvkeynum mth *_ols
	
	save BL_`multiple'_ols_${mrun}, replace
}

foreach multiple in m2b v2a v2s {
	
	* 3) Save ML vars with GBM results (also for nm; see code in next loop for sample harmonisation)

	use combined_${mrun}, clear

	local model ML_ln`multiple'
	
	foreach v of varlist y_*_`model' value_*_`model' logvalue_*_`model' {
		di "`v'"
		ren `v' `v'_gbm
	}	
	
	keep gvkeynum mth *_gbm

	save ML_ln`multiple'_gbm_${mrun}, replace
	
	* copy for use comparing with lasso (using same sub-sample)
	ren  *_gbm *_nm
	save ML_ln`multiple'_nm_${mrun}, replace
}

* combine all models and calculate results

foreach multiple in m2b v2a v2s {
	
	local predictors       BL_`multiple'_ols BL_ln`multiple'_ols BL_ln`multiple'_gbm ML_ln`multiple'_gbm ML_ln`multiple'_ls ML_ln`multiple'_nm
	local other_predictors BL_`multiple'_ols BL_ln`multiple'_ols BL_ln`multiple'_gbm                     ML_ln`multiple'_ls ML_ln`multiple'_nm

	* use ML predictions as base
	use  ML_ln`multiple'_gbm_${mrun}, clear

	* merge in other predictors
	foreach v in `other_predictors' {
		di "merging `v'_${mrun}"
		merge 1:1 gvkeynum mth using `v'_${mrun}, nogen keep(master match) keepusing(value_* y_* *_train_mean*)
	}
	
	su value_pred_BL_`multiple'_ols value_pred_BL_ln`multiple'_ols value_pred_BL_ln`multiple'_gbm value_pred_ML_ln`multiple'_gbm value_pred_ML_ln`multiple'_ls value_pred_ML_ln`multiple'_nm
	
	la var value_pred_BL_`multiple'_ols         "OLS : BL vars $\rightarrow$ `multiple'"
	la var value_pred_BL_ln`multiple'_ols       "OLS : BL vars $\rightarrow$ ln(`multiple')"
	la var value_pred_BL_ln`multiple'_gbm       "GBM : BL vars $\rightarrow$ ln(`multiple')"
	la var value_pred_ML_ln`multiple'_gbm       "GBM : ML vars $\rightarrow$ ln(`multiple')"
	la var value_pred_ML_ln`multiple'_ls        "LASSO : ML vars (nm) $\rightarrow$ ln(`multiple')"
	la var value_pred_ML_ln`multiple'_nm        "GBM : ML vars (nm) $\rightarrow$ ln(`multiple')"

	* all models on an equal footing - same sample - except ML vars with Lasso
	egen main_count = rowmiss(value_pred_BL_`multiple'_ols value_pred_BL_ln`multiple'_ols value_pred_BL_ln`multiple'_gbm value_pred_ML_ln`multiple'_gbm)
	foreach v in value_pred_BL_`multiple'_ols value_pred_BL_ln`multiple'_ols value_pred_BL_ln`multiple'_gbm value_pred_ML_ln`multiple'_gbm {
	    replace `v' = . if main_count != 0
	}
	
	* non missing (ML GBM and ML lasso)
	egen alt_count = rowmiss(value_pred_ML_ln`multiple'_ls value_pred_ML_ln`multiple'_nm)
	foreach v in value_pred_ML_ln`multiple'_ls value_pred_ML_ln`multiple'_nm {
	    replace `v' = . if alt_count != 0
	}
	
	su value_pred_BL_`multiple'_ols value_pred_BL_ln`multiple'_ols value_pred_BL_ln`multiple'_gbm value_pred_ML_ln`multiple'_gbm value_pred_ML_ln`multiple'_ls value_pred_ML_ln`multiple'_nm

	* performance table variables and numerical formats
	
	local thevariables  N      mdape mape    y_rmse  value_rmse   y_r2oos value_r2oos value_rho
	local theformats    %9.0fc %4.2f %4.2f    %4.2fc  %9.0fc        %4.2f   %4.2f         %4.2fc
	local thefile ${results}\\reconciliation_performance_`multiple'_${mrun}.tex

	measures_header `thevariables' using `thefile'

	foreach v in `predictors' {
	    
	    local lab: variable label value_pred_`v'
		calcmeasures y_pred_`v'  y_true_`v'  y_train_mean_`v'  value_pred_`v'  value_true_`v'  value_train_mean_`v'  logvalue_train_mean_`v' if !missing(value_pred_`v')
		return list
		
		* add a line before ML vars with lasso
		if "`v'" == "ML_ln`multiple'_ls" {
		    measures_emit "\hline" using `thefile' 
		}
			
		measures_line `thevariables' using `thefile' , result("`lab'") formatlist(`theformats')
	}

	* Complete table	
	measures_footer using `thefile'


}