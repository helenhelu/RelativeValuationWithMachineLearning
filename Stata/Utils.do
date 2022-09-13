* ----------------------------------------------------------------------------
* Utils
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
* load_predictions
*------------------------------------------------------------------------------

* load data from an ML run using files starting with `prediction_stub' 
capture program drop load_predictions
program load_predictions

	args prediction_stub startperiod endperiod
	
	* debug
	*local prediction_stub "BLVarsfilteredlnm2b"
	*local startperiod 300
	*local endperiod 360
	* debug
	foreach data in "test" "train" {
		di "LOADING :: `prediction_stub' from `startperiod' to `endperiod' "
		
		* append together predictions
		use `prediction_stub'_`startperiod'_1_`data', clear
		gen block = 1
		gen model_period = `startperiod'
		
		* drop all observations - leave empty scaffold
		drop if 1 == 1
		
		* combine different time periods (months) and blocks
		forvalues t = `startperiod'/`endperiod' {
			di "appending period `t'"
			forvalues b = 1/5 {
				append using `prediction_stub'_`t'_`b'_`data', gen(new)
				qui replace block = `b' if new == 1
				qui replace model_period = `t' if new == 1
				qui drop new
			}
		}
		
		* clean up variables
		ren mth date
		gen mth = mofd(dofc(date))
		gen data_period = mth
		format mth %tm
		drop index
		drop date
		
		qui sort gvkeynum mth data_period model_period
		
		if "`data'" == "test" {
			gcollapse (mean) y_pred y_true value_true value_pred block, by(gvkeynum mth data_period) fast
			qui sort gvkeynum mth
		}
		else {
			* save training data means ; needed for out of sample r^2
			gen logvalue_true = ln(value_true)
			gcollapse (mean) y_train_mean = y_true value_train_mean = value_true logvalue_train_mean = logvalue_true, by(mth data_period block) fast
			qui sort mth block
		}

		save `data'_clean, replace
	}
	
	* load main valuation data (unfiltered)
	use valuation_data_unfiltered, clear

	qui sort gvkeynum mth
	qui tsset gvkeynum mth
	
	* merge back in predictions
	merge 1:1 gvkeynum mth using test_clean, keep(match) nogen keepusing(y_pred y_true value_true value_pred block)
	
	* merge in training data target means (needed for out-of-sample r^2)
	merge m:1 mth block using train_clean, keep(match) nogen keepusing(*_train_mean)
	
	qui sort gvkeynum mth
	qui tsset gvkeynum mth	
	
	* create prediction errors in dataset (test only!)
	qui gen value_error = value_pred/value_true - 1
	qui gen value_abserror = abs(value_error)
	
	* keep these variables
	keep gvkeynum permno acc_mth mth value_* y_* *_train_mean compustat_equity_value  m2b lnm2b v2a lnv2a v2s lnv2s m2s lnm2s CAPMbeta industry book sale_ac assets debt_book_value *_wr *_an sicn missing_vars be_ac

end


*------------------------------------------------------------------------------
* Out-of-sample R-squared
*   compares prediction with naive prediction = training data sample mean of target
*------------------------------------------------------------------------------

capture program drop r2oos
program r2oos, rclass
	syntax varlist(min=3 max=3 numeric) [if] [in]
	di "`varlist' `if' `in'"
	
	corr `varlist'
	*tokenize y_pred_ML_m y_true_ML_m y_true_train_ML_m
	tokenize `varlist'
	
	local y_hat  `1'
	local y      `2'
	local y_mean `3'
	
	tempvar err_hat_sqrd
	gen double `err_hat_sqrd' = (`y' - `y_hat')^2
	su `err_hat_sqrd' `if' `in', meanonly
	
	local sse_hat = r(sum)
	
	tempvar err_mean_sqrd
	gen double `err_mean_sqrd' = (`y' - `y_mean')^2
	su `err_hat_mean' `if' `in', meanonly
	
	local sse_mean = r(sum)
	
	return scalar r2oos = 1 - ((`sse_hat')/(`sse_mean'))
	
end



*------------------------------------------------------------------------------
* calcmeasures
*------------------------------------------------------------------------------

* pass predicted, actual as arguments.
capture program drop calcmeasures
program calcmeasures, rclass
	syntax varlist(min=7 max=7 numeric) [if] [in]
	
	if wordcount("`varlist'") != 7 {
		di "calcmeasures <y_pred> <y_true> <y_train_mean> <value_pred> <value_true> <value_train_mean> <logvalue_train_mean>"
		
		*     y_pred_ML_lnm2b     y_true_ML_lnm2b     y_train_mean_ML_lnm2b 
		* value_pred_ML_lnm2b value_true_ML_lnm2b value_train_mean_ML_lnm2b 
		* logvalue_train_mean_ML_lnm2b
	}
	
	tokenize `varlist'

	* get arguments
	local y_pred `1'
	local y_true `2'
	local y_train_mean `3'
	local value_pred `4'
	local value_true `5'
	local value_train_mean `6'
	local logvalue_train_mean `7'

	* record variables actually passed in to code
	return local y_pred `y_pred'
	return local y_true `y_true'
	return local y_train_mean `y_train_mean'
	return local value_pred `value_pred'
	return local value_true `value_true'
	return local value_train_mean  `value_train_mean'
	return local logvalue_train_mean  `logvalue_train_mean'

	local insample & !missing(`value_true') & !missing(`value_pred')
	if "`if'"=="" {
		local if if 1==1
	}

	quietly {

		* valuation error
		tempvar abserror
		gen `abserror' = abs(`value_pred' - `value_true') `if' `insample' `in'
		
		* valuation percentage error
		tempvar pcterror
		gen `pcterror' = ((`value_pred' - `value_true')/(`value_true')) `if' `insample' `in'
		
		* valuation percentage error (log based)
		tempvar logpcterror
		gen `logpcterror' = ln(`value_pred'/`value_true') `if' `insample' `in'
		
		* valuation absolute percentage error
		tempvar abspcterror
		gen `abspcterror' = abs(`pcterror') `if' `insample' `in'
		
		* valuation absolute percentage error (log based)
		tempvar abslogpcterror
		gen `abslogpcterror' = abs(`logpcterror') `if' `insample' `in'	
	
		* for RMSE
		tempvar y_error_squared
		gen `y_error_squared' = (`y_pred' - `y_true')^2 `if' `insample' `in'			
		
		tempvar value_error_squared			
		gen `value_error_squared' = (`value_pred' - `value_true')^2 `if' `insample' `in'

		tempvar logvalue_error_squared
		gen `logvalue_error_squared' = (ln(`value_pred') - ln(`value_true'))^2 `if' `insample' `in'

		* y error squared
		su `y_error_squared' `if' `insample' `in', meanonly
		local y_error_sq = r(mean)
		di "y_error_sq : `y_error_sq'"

		* value error squared
		su `value_error_squared' `if' `insample' `in', meanonly
		local value_error_sq = r(mean)
		di "value_error_sq : `value_error_sq'"
		
		su `logvalue_error_squared' `if' `insample' `in', meanonly
		local logvalue_error_sq = r(mean)
		di "logvalue_error_sq : `logvalue_error_sq'"			
		
		su `value_true_squared' `if' `insample' `in', meanonly
		local value_true_sq = r(mean)
		di "value_true_sq : `value_true_sq'"
		
		su `y_true_square' `if' `insample' `in', meanonly
		local y_true_sq = r(mean)
		di "y_true_sq : `y_true_sq'"
		
		su `logvalue_true_squared' `if' `insample' `in', meanonly
		local logvalue_true_sq = r(mean)
		di "logvalue_true_sq : `logvalue_true_sq'"			
		
		* y rmse
		return scalar y_rmse = sqrt(`y_error_sq')
		
		* value rmse
		return scalar value_rmse = sqrt(`value_error_sq')
		
		* log value rmse
		return scalar logvalue_rmse = sqrt(`logvalue_error_sq')
		
		* mae
		su `abserror' `if' `insample' `in', detail
		return scalar mae = r(mean)
		return scalar mdae = r(p50)
		
		*** mean percentage error ***
		*----------------------------
		su `pcterror' `if' `insample' `in', detail
		* number of observations
		return scalar N = r(N)
		* mpe (mean percentage error)
		return scalar mpe = r(mean)
		* minpe min percentage error
		return scalar minpe = r(min)
		* maxpe max percentage error
		return scalar maxpe = r(max)
		* p25pe p25 percentage error
		return scalar p25pe = r(p25)
		* p50pe p50 percentage error
		return scalar p50pe = r(p50)
		* p75pe p75 percentage error
		return scalar p75pe = r(p75)
		* sdpe (standard deviation of percentage error)
		return scalar sdpe = r(sd)
		
		* mlpe (mean log percentage error)
		su `logpcterror' `if' `insample' `in'
		return scalar mlpe = r(mean)

		* mape (mean absolute percentage error)
		su `abspcterror' `if' `insample' `in', detail 
		return scalar mape = r(mean)
		
		* mdape (median absolute percentage error)
		return scalar mdape = r(p50)

		* malpe (mean absolute percentage error)
		su `abslogpcterror' `if' `insample' `in', detail 
		return scalar malpe = r(mean)
		
		* mdalpe (median absolute percentage error)
		return scalar mdalpe = r(p50)
		
		* R-squared / rho
		reg `value_true' `value_pred' `if' `insample' `in'
		return scalar value_r2 = e(r2)
		return scalar value_rho = sqrt(e(r2))
		
		*** out-of-sample R-squareds ***
		*-------------------------------
		
		* y out-of-sample R-squared
		r2oos `y_pred' `y_true' `y_train_mean' `if' `insample' `in'
		return scalar y_r2oos = r(r2oos)
		
		* value out-of-sample R-squared
		r2oos `value_pred' `value_true' `value_train_mean' `if' `insample' `in'
		return scalar value_r2oos = r(r2oos)
		
		* logvalue out-of-sample R-squared
		tempvar logvalue_pred
		tempvar logvalue_true
		
		gen `logvalue_pred' = ln(`value_pred')
		gen `logvalue_true' = ln(`value_true')
		r2oos `logvalue_pred' `logvalue_true' `logvalue_train_mean' `if' `insample' `in'
		return scalar logvalue_r2oos = r(r2oos)
		
	}
end

if 0 {
	local v ML_lnv2a
	calcmeasures y_pred_`v' y_true_`v' y_train_mean_`v' value_pred_`v' value_true_`v' value_train_mean_`v' logvalue_train_mean_`v'
	return list
}

*------------------------------------------------------------------------------
* savemeasures
*------------------------------------------------------------------------------

capture program drop measures_header
program measures_header
	
	syntax namelist(min=1) using/
	
	local measures = wordcount("`namelist'")
	local columns = "l"+"r"*`measures'
	
	local valid_measures  null    value_rho              r2                      mdalpe                         malpe                          mdape                    mape                     mlpe                         sdpe                  mpe                    y_rmse              value_rmse           logvalue_rmse            N   minpe                  p25pe                  p50pe                  p75pe                  maxpe                  value_r2oos                  y_r2oos                     logvalue_r2oos
	local latex_measures "null"  "$ \rho_{M,\hat{M}} $" "$ r^{2}_{M,\hat{M}} $" "med($ |\dot{\varepsilon}| $)" "avg($ |\dot{\varepsilon}| $)" "med($ |\varepsilon| $)" "avg($ |\varepsilon| $)" "avg($ \dot{\varepsilon} $)" "sd($ \varepsilon $)" "avg($ \varepsilon $)" "rmse($ \hat{y} $)" "rmse($ \hat{M} $)"  "rmse($ \ln(\hat{M}) $)" "N" "min($ \varepsilon $)" "p25($ \varepsilon $)" "med($ \varepsilon $)" "p75($ \varepsilon $)" "max($ \varepsilon $)" "$ r^{2}_{oos} (\hat{M}) $" "$ r^{2}_{oos} (\hat{y}) $" "$ r^{2}_{oos} (\ln\hat{M}) $"
	
	tempvar fh

	file open `fh' using `using', write text replace
	file write `fh' "\begin{tabular}{`columns'}" _n
	file write `fh' "\hline" _n
	foreach v in `namelist' {
		local idx : list posof "`v'" in valid_measures
		local header : word `idx' of `latex_measures'
		*di "`header'"
		file write `fh' " & `header'"
	}
	file write `fh' " \\ " _n	
	file write `fh' "\hline" _n
	file close `fh'
	
end


capture program drop measures_footer
program measures_footer
	
	syntax using/

	tempvar fh
	file open `fh' using `using', write text append
	
	file write `fh' "\hline" _n
	file write `fh' "\end{tabular}"
	file write `fh' _n
	file close `fh'
	
end


capture program drop measures_emit
program measures_emit
	
	syntax anything using/

	tempvar fh
	file open `fh' using `using', write text append
	file write `fh' `anything' _n
	file close `fh'
	
end

capture program drop measures_line
program measures_line
	
	syntax namelist(min=1) using/, RESULTname(string) [FORMATlist(string)]
	
	local measures = wordcount("`namelist'")
	local columns = "l"+"c"*`measures'
	
	* default format is %5.4f
	if "`formatlist'" == "" {
		foreach v in `namelist' {
			local formatlist `formatlist' %5.4f
		}
	}
	
	tempvar fh

	file open `fh' using `using', write text append
	file write `fh' "`resultname' "
	local counter = 0
	foreach v in `namelist' {
		local ++counter
		local idx : list posof "`v'" in valid_measures
		local result = `r(`v')'
		local format = word("`formatlist'",`counter')
		local result_formatted : display `format' `result'
		file write `fh' `" & `result_formatted' "'
	}
	file write `fh' " \\ " _n	
	file close `fh'
	
end

capture program drop savemeasures
program savemeasures
	
	syntax using/, RESULTname(string) [REPLACE]
	
	di `"syntax using=`using', replace=`replace'"'		
	
	tempvar fh
	
	if "`replace'" == "replace" {
		file open `fh' using `using', write text replace
	}
	else {
		file open `fh' using `using', write text append
	}
	file write `fh' "Resultname,     r(r2_oos),     r(rho),     r(r2),     r(mdalpe),     r(malpe),     r(mdape),     r(mape),     r(mlpe),     r(sdpe),     r(mpe),     r(rmse),     r(rmslpe),    r(N)"  _n
	file write `fh' "`resultname', `=r(r2_oos)',  `=r(rho)',  `=r(r2)',  `=r(mdalpe)',  `=r(malpe)',  `=r(mdape)',  `=r(mape)',  `=r(mlpe)',  `=r(sdpe)',  `=r(mpe)',  `=r(rmse)',   `=r(rmslpe)', `=r(N)'" _n
	file close `fh'
	
end



*------------------------------------------------------------------------------
* Latex table
*------------------------------------------------------------------------------
capture program drop describevariables
program describevariables
	
	syntax varlist(numeric) [if] [in] using/, Title(string) Reference(string)
	
	di `"syntax varlist=`varlist' if=`if' in=`in' using=`using', title=`title' reference=`reference'"'		
	tempvar fh
	
	file open `fh' using `using', write text replace
	file write `fh' "\begin{longtable}[l]{>{\raggedright}p{3.5cm}>{\raggedright}p{13.5cm}}" _n
	file write `fh' `"\caption{`title' \label{`reference'}} \\ "' _n
	file write `fh' "\hline" _n
	file write `fh' "Variable & Description \tabularnewline " _n
	file write `fh' "\hline" _n
	file write `fh' "\endhead" _n
	file write `fh' "\hline" _n
	file write `fh' "\endfoot" _n

	foreach v in `varlist' {
		
		* retrieve notes 
		notes _fetch lab_orig : `v' 1
		local lab = subinstr(`"`lab_orig'"',`"""',"",.)
		
		local lab2 = subinstr(`"`lab'"',"&", "\&", .)
		local lab3 = subinstr(`"`lab2'"',"_", "\_", .)
		local lab4 = subinstr(`"`lab3'"',"%", "\%", .)
		
		local v2 = subinstr("`v'","&", "\&", .)
		local v3 = subinstr("`v2'","_", "\_", .)
		local v4 = subinstr("`v3'","%", "\%", .)
		
		file write `fh' `"`v3' & `lab3' \tabularnewline"' _n
	}
	file write `fh' "\hline" _n
	file write `fh' "\end{longtable}" _n	
	file close `fh'

end


