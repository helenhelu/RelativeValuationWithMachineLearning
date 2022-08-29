* ----------------------------------------------------------------------------
* RRV
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

* RRV cross-sectional errors using the Rhodes-Kropf, Robinson, Viswanathan (RRV) fundamental valuation approach

forvalues i = 1/5 {
	
    use RRVdata_${mrun}, clear

	keep if !missing(lnm) &  !missing(lnb) &  !missing(lnni) &  !missing(negni) &  !missing(LEV_book)

	* training and testing blocks
	gen train = 1
    replace train = 0 if hash100 > (`i'-1) * 20 & hash100 < `i' * 20

	qui gen value_true = crsp_market_equity
	qui gen y_true     = lnm
	
	sort mth
	
	* calculate means of target - for use in OOS R^2 calculations
	qui by mth: gen y_train        = lnm                if train == 1
	qui by mth: gen value_train    = crsp_market_equity if train == 1
	qui by mth: gen logvalue_train = lnm                if train == 1
	
	* calculate training mean and extend to out-of-sample (test) data
	qui by mth: egen y_train_mean        = mean(y_train)
	qui by mth: egen value_train_mean    = mean(value_train)
	qui by mth: egen logvalue_train_mean = mean(logvalue_train)
	
	* drop train-only values
	drop y_train value_train logvalue_train	

	* regress by industry by month >> keep betas and constant >>> predict lnmit_hat (firm i fundamental value at time t)
	sort industry mth
	
	bysort industry mth: asreg lnm lnb lnni negni LEV_book if train == 1, fit minimum(15)
	by industry mth: egen y_true_train = mean(y_true) if train == 1

	* write missing estimates for test firms 
	foreach v in _b_lnb _b_lnni _b_negni _b_LEV_book _b_cons y_true_train {
		by industry mth: egen `v'_mean = mean(`v')
	}

	replace _fitted = _b_cons_mean + _b_lnb_mean * lnb + _b_lnni_mean * lnni + _b_negni_mean * negni + _b_LEV_book_mean * LEV if  train == 0
	gen y_pred = _fitted if  train == 0

	* generate predicted equity value
	gen RRVcs_hat = exp(_fitted) if (!missing(_fitted)) &  train == 0
	gen value_pred = RRVcs_hat if  train == 0

	keep if train == 0
	keep gvkeynum mth RRVcs_hat  crsp_market_equity value_true value_pred y_true y_pred *_train_mean
	label var RRVcs_hat "Equity value estimated from RRV industry-month regressions"

	count
	drop if missing(RRVcs_hat)

	sort gvkeynum mth
	save temp`i', replace

}

use temp1, clear
append using temp2
append using temp3
append using temp4
append using temp5
sort gvkeynum mth
save RRV_${mrun}, replace

