* ----------------------------------------------------------------------------
* ReconciliationModels
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

* Reconciles performance of BL model (see 060BL.do) with GBM model
* only for m2b (m2b performs best for both GBM ML and OLS BL models)

* create dataset without missing values for use in ML vars + Lasso

foreach depvar in lnm2b lnv2a lnv2s {
    
	use BL_`depvar'_${mrun}, clear

	local model BL_`depvar'_ols
	
	rename value_pred          value_pred_`model'
	rename value_true          value_true_`model'
	rename y_pred              y_pred_`model'
	rename y_true              y_true_`model'
	rename y_train_mean        y_train_mean_`model'
	rename value_train_mean    value_train_mean_`model'
	rename logvalue_train_mean logvalue_train_mean_`model'

	keep gvkeynum mth *`depvar'_ols

	* save BL estimates using log target
	save BL_`depvar'_ols_${mrun}, replace

}


* predict with lasso
foreach depvar in lnm2b lnv2a lnv2s {
	
	forvalues i = 1/5 {
		
		di "lasso for depvar = `depvar' i = `i'"
		
		* this file is generated in LoadMLPredictions
		use combined_full_${mrun}, clear
		sort mth
		
		gen train = 1
		replace train = 0 if hash100 > (`i'-1) * 20 & hash100 < `i' * 20		
		
		unab ML_vars : *_wr *_an assets book sale_ac debt_book_value CAPMbeta
		
		* only keep observations with non-missing data
		egen count_missing = rowmiss(`ML_vars' lnm2b lnv2a lnv2s)
		keep if count_missing == 0
		
		* the 80's have too much missing data... whole months will be missing
		keep if mth >= tm(1990m1)
		
		* winsorise for LASSO
		gstats winsor `ML_vars', cuts(1 99) replace by(mth)
		
		keep gvkeynum mth `depvar' `ML_vars' train crsp_market_equity
		
		* train means (for calculating out-o-sample R^2's)
		*-------------------------------------------------
		
		* calculate means of target - for use in OOS R^2 calculations
		qui by mth: gen y_train        = `depvar'           if train == 1
		qui by mth: gen value_train    = crsp_market_equity if train == 1
		qui by mth: gen logvalue_train = ln(value_train)    if train == 1
		
		* calculate training mean and extend to out-of-sample (test) data
		qui by mth: egen y_train_mean        = mean(y_train)
		qui by mth: egen value_train_mean    = mean(value_train)
		qui by mth: egen logvalue_train_mean = mean(logvalue_train)
		
		* drop train-only values
		drop y_train value_train logvalue_train
		
		
		* predict with ML vars and LASSO
		*-------------------------------------------------

		gen y_pred = .

		qui levelsof mth, local(months)
		
		*di "months = `months'"
		
		*di "going to lasso estimate `depvar' on `ML_vars' for each month"
		
		foreach m in `months' {

			di "doing lasso for month `m'"
			* set tolerance to accomodate edge cases with weak convergence
			
			qui lasso linear `depvar' `ML_vars' if mth == `m' & train, selection(plugin) rseed(42) tol(0.001)
			qui predict temp_hat if mth == `m' & !train
			qui replace y_pred = temp_hat if mth == `m' & !train
			qui drop temp_hat
		
		}
		
		gen y_true = `depvar'
		gen value_true = crsp_market_equity
	    if "`depvar'" == "lnv2s" {
			gen value_pred = exp(y_pred) * sale_ac - debt_book_value
		} 
		else if "`depvar'" == "lnm2b" {
			gen value_pred = exp(y_pred) * book
		}
		else if "`depvar'" == "lnv2a" {
			gen value_pred = exp(y_pred) * assets
		}

		* save ML estimates (only out-of-sample = not train)
		keep if !train
		save temp`i', replace

	}
	
	use temp1, clear
	append using temp2
	append using temp3
	append using temp4
	append using temp5
	
	local model ML_`depvar'_ls
	
	rename value_pred          value_pred_`model'
	rename value_true          value_true_`model'
	rename y_pred              y_pred_`model'
	rename y_true              y_true_`model'
	rename y_train_mean        y_train_mean_`model'
	rename value_train_mean    value_train_mean_`model'
	rename logvalue_train_mean logvalue_train_mean_`model'
	
	sort gvkeynum mth
	keep gvkeynum mth *_ls
	
	save ML_`depvar'_ls_${mrun}, replace
	
}

