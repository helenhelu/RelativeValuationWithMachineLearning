* ----------------------------------------------------------------------------
* BartramRegressions
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

*------------------------------------------------------------------------------
* Bartram and Grinblat Valuation
*------------------------------------------------------------------------------
* start from 1980 to be consistent with ML

* loop through cross-sectional blocks

forvalues i = 1/5 {
	use BGdata_${mrun}, clear
	keep if ${bg_datecutoff}

	* variables used in Bartram and Grinblat (2018)
	* list defined as global var in RunAll
	* See appendix B, 145
	local bglist
	foreach v in $bg_bsitems  $bg_cfitems  $bg_y2ditems {
		* display "`v'"
		local bglist `bglist' `v'_ac
	}
	di "`bglist'"

	* teqq is missing many values (200k vs 970k for other)
	* as per WRDS balancing model, teqq = seqq + mibnq
	replace teq_ac = seq_ac + cond(missing(mibn_ac),0,mibn_ac) if missing(teq_ac)

	keep mth permco gvkeynum crsp_market_equity `bglist' hash100 

	* training and testing blocks
	gen train = 1
    	replace train = 0 if (hash100 > ((`i'-1) * 20)) & (hash100 < (`i' * 20))

	*------------------------------------------------------------------------------
	* Do Bartram and Grimblat predictions
	*------------------------------------------------------------------------------

	* (1) regress  by month >> keep betas and constant >>> predict lnmit_hat (firm i peer-implied value at time t, bg_equity_value_hat)

	* only estimate model using observations with non-missing data 
	egen count_missing = rowmiss(`bglist')
	keep if count_missing == 0

	* run monthly cross-sectional OLS regressions to predict market value
	bysort mth: asreg crsp_market_equity `bglist' if train == 1, fit

	* calculate means of target - for use in OOS R^2 calculations
	qui by mth: gen y_train        = crsp_market_equity if train == 1
	qui by mth: gen value_train    = crsp_market_equity if train == 1
	qui by mth: gen logvalue_train = ln(value_train)    if train == 1
	
	* calculate training mean and extend to out-of-sample (test) data
	qui by mth: egen y_train_mean        = mean(y_train)
	qui by mth: egen value_train_mean    = mean(value_train)
	qui by mth: egen logvalue_train_mean = mean(logvalue_train)
	
	* drop train-only values
	drop y_train value_train logvalue_train
	
	* write fitted value to out-of-sample (test) data
	sort mth
	foreach v in `bglist'  {
		qui by mth: egen _b_`v'_mean = mean(_b_`v')
	}
	qui by mth: egen _b_cons_mean = mean(_b_cons)
	
	* manually construct estimates for test 
	gen _fitted_new = 0 
	foreach v in `bglist' {
		replace _fitted_new =  _fitted_new  + `v' * _b_`v'_mean if train == 0
	}
	* add constants
	replace _fitted_new =  _fitted_new  +  _b_cons_mean  if train == 0 
	replace _fitted = _fitted_new if train == 0 
	replace _fitted = . if train == 1
	rename _fitted bg_equity_value_hat

	gen value_pred = bg_equity_value_hat
	gen y_pred = bg_equity_value_hat

	gen value_true = crsp_market_equity
	gen y_true = crsp_market_equity

	la var bg_equity_value_hat "Equity values predicted from cross-sectional regressions (BG)"
	count if !missing(bg_equity_value_hat) & train == 0

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
save BG_${mrun}, replace

