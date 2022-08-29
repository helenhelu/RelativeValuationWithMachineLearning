* ----------------------------------------------------------------------------
* HP
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
* Hobart and Phillips industry score - harmonic average
* -----------------------------------------------------------------------------*

* monthly time scaffold
drop _all
drop if 1 == 1
set obs 760
gen mth = _n
format mth %tm
ren mth month

* year YYYY+1 after latest possible fiscal year end (31 Dec YYYY)
gen year = year(dofm(month))
save monthly_scaffold, replace

* get data

import delimited using "${source}//tnic3_data.txt", clear
drop if missing(score)

* so ascending sort contains the closest matches, low rank = close match
replace score = -score

* no self-referent comparables
drop if gvkey1 == gvkey2

* only keep gvkeys and months where we have filtered data (GVKEY1)
count
gen gvkeynum = gvkey1 
gen mth = mofd(mdy(12,1,year))
merge m:1 gvkeynum mth using valuation_filtered, keep(match) nogen keepusing(assets)
drop gvkeynum
count

* only keep gvkeys and months where we have filtered data (GVKEY2)
count
gen gvkeynum = gvkey2 
merge m:1 gvkeynum mth using valuation_filtered, keep(match) nogen keepusing(assets)
drop gvkeynum
drop assets
drop mth
count

sort gvkey1 year score
by gvkey1 year: gen rank = _n

save tnic3_temp, replace

use tnic3_temp, replace

* monthly frequency
* create 12 months for each year
joinby year using monthly_scaffold
sort gvkey1 gvkey2 year month

* year YYYY data could contain FYE data up to 31 DEC YYYY - hence add 12 months
* so availability is always AFTER last possible FYE date
* then lag month by 4 months to reflect availability of accounting data to market
gen mth = month + 12 + 4
la var mth "date of score availability to market"
format mth %tm
drop month

save tnic3_temp2, replace

use tnic3_temp2, replace

* merge in the details of the "base" gvkey firm
gen gvkeynum = gvkey1

***> merge in valuation data
local keepvars gvkeynum permno mth v2s v2a  m2b book sale_ac debt_book_value crsp_market_equity industry hash100 shrout assets 

* note 2: only keep match, as non-match cannot be used 
merge m:1 gvkeynum mth using valuation_data_filtered_blocks, keep(match) nogen keepusing(`keepvars')

ren m2b base_m2b
ren v2a base_v2a
ren v2s base_v2s
ren hash100 base_hash100

***> merge in tnic3 "peer" data
drop gvkeynum
gen gvkeynum = gvkey2 

* note: uses master match, as missing peer firms can be handled.
merge m:1 gvkeynum mth using valuation_data_all_blocks, keep(master match) nogen keepusing(m2b v2a v2s hash100)

ren m2b peer_m2b
ren v2a peer_v2a
ren v2s peer_v2s
ren hash100 peer_hash100

drop gvkeynum
* back to "base" interpretation of gvkeynum
gen gvkeynum = gvkey1

sort gvkeynum mth 
egen count_missing = rowmiss(mth base_v2a base_v2s base_m2b book sale_ac debt_book_value assets)
save tnic3_ready, replace

* do peer means by gvkey and mth

* loop through multiples
foreach depvar in m2b v2a v2s {
	
	* loop through test blocks
	forvalues i = 1/5 {
		
		* get data
		use tnic3_ready, clear
		
		* keep only "peer" firms in training blocks
		gen peer_train = (peer_hash100 <= (`i'-1) * 20) | (peer_hash100 >= `i' * 20)
		keep if peer_train
		
		gen base_train = (base_hash100 <= (`i'-1) * 20) | (base_hash100 >= `i' * 20)
		
		* only keep top-4 peers from training data (min 2 obs)
		sort gvkeynum mth score
		by gvkeynum mth : gen peer_train_rank = _n if peer_train
		* take avg of 60, min 5
		* based on average firms in FF49 industry in a given month of 60
		keep if peer_train_rank <= 60 & peer_train_rank >= 5
		
		* harmonic mean
		*-----------------
		
		* uses _gwmean ("ssc install _gwmean")
		egen _fitted = wmean(peer_`depvar'), by(gvkeynum mth) harmonic		

		* collapse to unique gvkeynum mth level
		gcollapse (mean) _fitted base_* book sale_ac debt_book_value crsp_market_equity assets count_missing, by(gvkeynum mth) fast
		
		gen value_true = crsp_market_equity
		sort mth		

		* calculate means of target - for use in OOS R^2 calculations
		qui by mth: gen y_train        = base_`depvar'       if base_train
		qui by mth: gen value_train    = crsp_market_equity  if base_train
		qui by mth: gen logvalue_train = ln(value_train)     if base_train
		
		* calculate training mean and extend to out-of-sample (test) data
		qui by mth: egen y_train_mean        = mean(y_train)
		qui by mth: egen value_train_mean    = mean(value_train)
		qui by mth: egen logvalue_train_mean = mean(logvalue_train)
		
		* drop train-only values
		drop y_train value_train logvalue_train

		* calculate dollar values for relevant prediction
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
			di "Uknown depvar = `depvar' in HP.do"
			assert(1==0)
		}
		
		la var `depvar'_value_hat "Equity values predicted from harmonic means of `depvar' HP top-4 training comparables"
		
		sort gvkeynum mth
			
		gen y_`depvar'_pred = _fitted
		drop _fitted
		gen y_`depvar'_true = base_`depvar'
		
		* keep only base firms in test (eg not train)
		keep if !base_train
		
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

	keep gvkeynum mth value_* y_* *_train_mean `depvar'_value_hat count_missing
	sort gvkeynum mth
	
	* only keep observations with non-missing data 
	keep if count_missing == 0 & !missing(value_true)

	save HP_`depvar'_${mrun}, replace
	
}