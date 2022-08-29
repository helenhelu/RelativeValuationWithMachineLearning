* ----------------------------------------------------------------------------
* BL
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

* ----------------------------------------------------------------------------
* S. BHOJRAJ AND C. M. C. LEE 2002 JAR
* ----------------------------------------------------------------------------

* also do logged ratios, for use in ReconciliationResults.do
foreach depvar in v2s m2b v2a lnv2s lnm2b lnv2a {
	
    forvalues i = 1/5 {
		
	    use BLdata_${mrun}, clear
		
		di "depvar = `depvar' i = `i'"
		
		* training and testing blocks
		gen train = 1
		replace train = 0 if hash100 > (`i'-1) * 20 & hash100 < `i' * 20
		
		* (1) regress  by month >> keep betas and constant >>> predict lnmit_hat (firm i fundamental value at time t)
		local vars indv2s indv2a indm2b adjopmad negadjopmad adjsalesgrowth d2e pretret_noa_wr roe_wr rd_sale_wr 

		* gen value_true
		gen value_true = crsp_market_equity 

		* only keep observations with non-missing data (including targets
		egen count_missing = rowmiss(`vars' v2s m2b v2a)
		keep if count_missing == 0

		sort mth
		
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
		
		* in-sample prediction (training firms only )
		bysort mth: asreg `depvar' `vars' if train == 1, fit minimum(15)
		by mth: egen y_true_train = mean(`depvar') if train == 1
		
		* copy fitted coefficients to test firms
		sort mth
		foreach v in `vars' {
			by mth: egen _b_`v'_mean = mean(_b_`v')
		}
		by mth: egen _b_cons_mean = mean(_b_cons)
		
		* manually calculate predicted (fitted) target for test firms (_fitted_new)
		gen _fitted_new = 0 	
		
		* add coefficient*predictor for each predictor
		foreach v in `vars' {
			replace _fitted_new =  _fitted_new  + `v' * _b_`v'_mean if train == 0
			drop _b_`v'_mean  
		}	
		* add intercept
		replace _fitted_new =  _fitted_new  +  _b_cons_mean if train == 0

		* copy test predictions
		replace _fitted = _fitted_new if train == 0
		
		gen y_true = `depvar' if train == 0
		gen y_pred = _fitted if train == 0
		
		if "`depvar'" == "v2s" {
			gen bl`depvar'_equity_value_hat = _fitted * sale_ac - debt_book_value
		} 
		else if "`depvar'" == "m2b" {
			gen bl`depvar'_equity_value_hat = _fitted * book
		}
		else if "`depvar'" == "v2a" {
			gen bl`depvar'_equity_value_hat = _fitted * assets
		}
		else if "`depvar'" == "lnv2s" {
			gen bl`depvar'_equity_value_hat = exp(_fitted) * sale_ac - debt_book_value
		} 
		else if "`depvar'" == "lnm2b" {
			gen bl`depvar'_equity_value_hat = exp(_fitted) * book
		}
		else if "`depvar'" == "lnv2a" {
			gen bl`depvar'_equity_value_hat = exp(_fitted) * assets
		}
		else {
			* should not happen
			di "Error in BL.do: unknown depvar `depvar'"
			assert(1==0)
		}

		gen value_pred = bl`depvar'_equity_value_hat if train == 0
		
		la var bl`depvar'_equity_value_hat "Equity values predicted from `depvar' multiples (BL)"
		
		count if !missing(bl`depvar'_equity_value_hat) & train == 0
		
		drop _b_* _residuals _fitted _Nobs _R2 _adjR2
		drop _fitted_new

		* save BL estimates
		sort gvkeynum mth
		keep if !missing(y_pred)
		
		save temp`i', replace
	}
	
	use temp1, clear
	append using temp2
	append using temp3
	append using temp4
	append using temp5
		
	sort gvkeynum mth
	save BL_`depvar'_${mrun}, replace
}

