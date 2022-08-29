* ----------------------------------------------------------------------------
* LNT
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


* -----------------------------------------------------------------------------*
* Liu, Nissim and Thomas 2001 JARs
* -----------------------------------------------------------------------------*

foreach depvar in v2a v2s m2b {
	
	forvalues i = 1/5 {
		
		use valuation_data_${mrun}_blocks, clear
		* training and testing blocks
		gen train = 1
		replace train = 0 if hash100 > (`i'-1) * 20 & hash100 < `i' * 20
		
		keep gvkeynum permno mth v2s v2a  m2b book sale_ac debt_book_value crsp_market_equity industry hash100 shrout assets train

		* treat missing industry as 50
		replace industry = 50 if missing(industry)

		gen value_true = crsp_market_equity

		* only keep observations with non-missing data 
		egen count_missing = rowmiss(mth  v2a v2s m2b book sale_ac debt_book_value value_true industry assets)
		keep if count_missing == 0

		* harmonic mean

		*-----------------
		
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
		
		gen _fitted = .
		
		* in-sample prediction
		gen `depvar'_inv =  1 / `depvar'
		sort mth industry
		by mth industry: egen `depvar'_mean = sum(`depvar'_inv) if train == 1
		by mth industry: egen N = count(`depvar') if  train == 1
		gen `depvar'_mean1 =  N / `depvar'_mean
		by mth industry: egen `depvar'_tmp = mean(`depvar'_mean1)
		* training sample average
		by mth industry: egen `depvar'_train = mean(`depvar') if train == 1
		by mth industry: egen `depvar'_train_mean = mean(`depvar'_train) 
		drop `depvar'_train
		rename `depvar'_train_mean `depvar'_train
		
		* fill in missing multiple for test
		replace _fitted =  `depvar'_tmp if train == 0
		gen y_`depvar'_pred = _fitted if train == 0
		gen y_`depvar'_true = `depvar' if train == 0
		
		drop `depvar'_inv `depvar'_mean `depvar'_mean1 `depvar'_tmp N
		
		if      "`depvar'" == "v2s" {
			gen `depvar'_value_hat = _fitted * sale_ac - debt_book_value
		} 
		else if "`depvar'" == "v2a" {
			gen `depvar'_value_hat = _fitted * assets - debt_book_value
		}
		else if "`depvar'" == "m2b" {
			gen `depvar'_value_hat = _fitted * book
		}
		else {
			di "Uknown depvar = `depvar' in LNT.do"
			assert(1==0)
		}
		
		la var `depvar'_value_hat "Equity values predicted from harmonic means of `depvar' multiples"
		count if !missing(`depvar'_value_hat) & train == 0  
		drop _fitted
		sort gvkeynum mth
			
		drop if train == 1
		save temp`i', replace
	}
	
	use temp1, clear
	append using temp2
	append using temp3
	append using temp4
	append using temp5
	
	gen y_true = y_`depvar'_true 
	gen y_pred = y_`depvar'_pred
	gen value_pred = `depvar'_value_hat

	keep gvkeynum mth value_* y_* *_train_mean `depvar'_value_hat
	sort gvkeynum mth
	
	save IND_`depvar'_${mrun}, replace
	
}

