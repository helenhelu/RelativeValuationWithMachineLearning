* ----------------------------------------------------------------------------
* Graphs
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

*---------------------------------------------------------------------------
*  Median error by month - model comparison (m2b, v2a, v2s)
*---------------------------------------------------------------------------

use combined_full_${mrun}, clear

* drop dummy observations (used in ML code)
drop if hash100 == 100

gcollapse (median) abserr* err* , by(mth) fast
tsset mth

local targets m2b v2a v2s

foreach target in `targets' {
	
	local vars ML_ln`target' BL_`target' IND_`target' HP_`target'
	local plotvars
	foreach v in `vars' {
		local plotvars `plotvars' abserr_`v'
		la var abserr_`v' "`v'"
	}
	di "`plotvars'"
	
	line `plotvars'  mth, xtitle("") ytitle("Median absolute percentage valuation error") ylabel(#5) lpattern(solid shortdash longdash_dot longdash dash_dot dot) lcolor(black navy dkgreen maroon gs7 cranberry)  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(2) region(lcolor(white))) 
graph export ${results}\\Graph_abserr_ts_comparison_`target'_${mrun}.pdf, replace
	
}


*---------------------------------------------------------------------------
*  Median error by month - model comparison (all ML_ln* vs RRV GB)
*---------------------------------------------------------------------------

use combined_full_${mrun}, clear

* drop dummy observations (used in ML code)
drop if hash100 == 100

gcollapse (median) abserr* err* , by(mth) fast
tsset mth

local targets m2b v2a v2s

local vars ML_lnm2b ML_lnv2a ML_lnv2s RRV BG
local plotvars
foreach v in `vars' {
	local plotvars `plotvars' abserr_`v'
	la var abserr_`v' "`v'"
}

di "`plotvars'"

line `plotvars'  mth, xtitle("") ytitle("Median absolute percentage valuation error") ylabel(#5) lpattern(solid shortdash longdash_dot longdash dash_dot dot) lcolor(black navy dkgreen maroon gs7 cranberry)  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(2) region(lcolor(white))) 
graph export ${results}\\Graph_abserr_ts_comparison_RRV_BG_${mrun}.pdf, replace


*---------------------------------------------------------------------------
* Median error by month: alt targets
*---------------------------------------------------------------------------

use combined_full_${mrun}, clear

* drop dummy observations (used in ML code)
drop if hash100 == 100

gcollapse (median) abserr* err* , by(mth) fast

foreach v in ML_lnm2b ML_m2b ML_m ML_lnm  {
	label var abserr_`v' "`v'"
}

tsset mth

line abserr_ML_lnm2b abserr_ML_m2b abserr_ML_m abserr_ML_lnm mth, xtitle("") ytitle("Median absolute percentage valuation error") ylabel(#5) yscale(titlegap(5))  lpattern(solid shortdash longdash_dot longdash dash_dot dot) lcolor(black navy dkgreen maroon gs7 cranberry) graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white))) 
graph export ${results}\\Graph_abserr_ts_alttarget_${mrun}.pdf, replace

local vars ML_lnm2b ML_lnv2a ML_lnv2s BG RRV
local plotvars abserr_ML_lnm2b abserr_ML_lnv2a abserr_ML_lnv2s abserr_BG abserr_RRV

di "`plotvars'"

* create labels for variables used as plot variables
foreach v in `vars' {
	label var abserr_`v' "`v'"
}

* create graph
line `plotvars'  mth, xtitle("") ytitle("Median absolute percentage valuation error") ylabel(#5)  yscale(range(0 400))  lpattern(solid longdash longdash_dot  dash_dot dash) lcolor(black black black dkgreen maroon gs7 cranberry)  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(2) region(lcolor(white))) 
graph export ${results}\\Graph_abserr_ts_comparison_RRV_BG_${mrun}.pdf, replace


*---------------------------------------------------------------------------
* Median error by month: all
*---------------------------------------------------------------------------

use combined_full_${mrun}, clear

* drop dummy observations (used in ML code)
drop if hash100 == 100

gcollapse (median) abserr* err* , by(mth) fast

foreach v in ML_lnm2b ML_lnv2a ML_lnv2s {
	label var abserr_`v' "`v'"
}

tsset mth

line abserr_ML_lnm2b abserr_ML_lnv2a  abserr_ML_lnv2s  mth, xtitle("") ytitle("Median absolute percentage valuation error") ylabel(#5) yscale(range(20 60))  lpattern("l" ".." "__#"  "--..")  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white))) 
graph export ${results}\\Graph_abserr_ts_${mrun}.pdf, replace

*---------------------------------------------------------------------------
* Median error by month: new  economy
*---------------------------------------------------------------------------
use combined_full_${mrun}, clear

* drop dummy observations (used in ML code)
drop if hash100 == 100

merge 1:1 gvkeynum mth using neweconomy, keep(master match) nogen
keep if Neweconomy == 1

gcollapse (median) abserr* err* , by(mth) fast

foreach v in ML_lnm2b ML_lnv2a ML_lnv2s ML_m ML_lnm  {
	label var abserr_`v' "`v'"
}

tsset mth

line abserr_ML_lnm2b abserr_ML_lnv2a  abserr_ML_lnv2s  mth, xtitle("") ytitle("Median absolute percentage valuation error") ylabel(#5)  yscale(range(20 60))  lpattern("l" ".." "__#"  "--..")  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white))) 
graph export ${results}\\Graph_abserr_neweco_ts_${mrun}.pdf, replace

*---------------------------------------------------------------------------
* Median error by month: old  economy
*---------------------------------------------------------------------------

use combined_full_${mrun}, clear

* drop dummy observations (used in ML code)
drop if hash100 == 100

merge 1:1 gvkeynum mth using neweconomy, keep(master match) nogen
keep if Neweconomy == 0

gcollapse (median) abserr* err* , by(mth) fast

foreach v in ML_lnm2b ML_lnv2a ML_lnv2s ML_m ML_lnm  {
	label var abserr_`v' "`v'"
}

tsset mth

line abserr_ML_lnm2b abserr_ML_lnv2a  abserr_ML_lnv2s  mth, xtitle("") ytitle("Median absolute percentage valuation error") ylabel(#5)  yscale(range(20 60))  lpattern("l" ".." "__#"  "--..")  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white))) 
graph export ${results}\\Graph_abserr_oldeco_ts_${mrun}.pdf, replace

*---------------------------------------------------------------------------
* % of Neweconomy firms
*---------------------------------------------------------------------------
use combined_full_${mrun}, clear

* drop dummy observations (used in ML code)
drop if hash100 == 100

merge 1:1 gvkeynum mth using neweconomy, keep(master match) nogen
collapse (mean) Neweconomy, by(mth)
tsset mth

replace Neweconomy = Neweconomy * 100
line Neweconomy  mth, xtitle("") ytitle("") ylabel(#5)  yscale(range(0 50) titlegap(10))  lpattern("l" ".." "__#"  "--..")  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white))) 
graph export ${results}\\Graph_neweconomy_pct_ts_${mrun}.pdf, replace



*---------------------------------------------------------------------------
* Monthy OOSR2 - three multiples 
*---------------------------------------------------------------------------

use combined_full_${mrun}, clear

* drop dummy observations (used in ML code)
drop if hash100 == 100

foreach v in ML_lnm2b ML_lnv2a ML_lnv2s ML_m2b ML_m ML_lnm   {
	gen err_hat_sqr_`v' = (value_true_`v' - value_pred_`v') ^ 2
	gen err_mean_sqr_`v' = (value_true_`v' - value_train_mean_`v') ^ 2
}

gcollapse (sum) err_hat_sqr* err_mean_sqr* , by(mth) fast

foreach v in ML_lnm2b ML_lnv2a ML_lnv2s ML_m2b ML_lnm ML_m {
	gen oosr2_`v' = 1 - err_hat_sqr_`v' / err_mean_sqr_`v'
	label var oosr2_`v' "`v'"
}

tsset mth

line oosr2_ML_lnm2b  oosr2_ML_lnv2a  oosr2_ML_lnv2s   mth, xtitle("") ylabel(#5)  yscale(range(0 1) titlegap(10))  lpattern("l" ".." "__#"  "--..")  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white))) 
graph export ${results}\\Graph_oosr2_ts_${mrun}.pdf, replace


*------------------------------------------------------------------------------
* (5) Figure 2: Model performance in the cross-section
*------------------------------------------------------------------------------

* By industry: med  aberr and err
foreach err in aberr err {
	foreach v in ML_lnv2s ML_lnv2a  ML_lnm2b  {
		use combined_full_${mrun}, clear
		
		* drop dummy observations (used in ML code)
		drop if hash100 == 100

		
		capture drop aberr_`v'
		if "`err'" == "aberr" {
			gen aberr_`v' = abs(err_`v')
		}

		merge m:1 sicn using ${source}\\FF12_sic, nogen keep(master match) 
		levelsof ff12_des, local(ff12industries)
		local thefile ${results}\\`v'`err'_Industry_Med_${mrun}.csv
		tempvar myfile
		file open `myfile' using `thefile', write replace
		
		foreach industry in `ff12industries' {
			sum `err'_`v' if ff12_des == "`industry'", detail
			file write `myfile' "`industry'" "," "`r(p50)'" _n								    
		}
	
		file close `myfile'
		import delimited ${results}\\`v'`err'_Industry_Med_${mrun}.csv, clear
		save ${results}\\`v'`err'_Industry_Med_${mrun}, replace
	}	
	
	* merge results from different ML models
	use ${results}\\ML_lnv2s`err'_Industry_Med_${mrun}, clear
	rename v2 ML_lnv2s
	
	foreach v in ML_lnv2a ML_lnm2b  {
		merge 1:1 v1 using ${results}\\`v'`err'_Industry_Med_${mrun}, keep(master match using) nogen
		rename v2 `v'
	}	 
	
	rename v1 Q
	destring Q, replace
	save ${results}\temp1, replace
	use ${results}\temp1, clear
	*xlabels
	local l ""
	count if !missing(Q)
	forvalues k=1/`r(N)' {
		local Q = Q[`k']
		local l `l' `k' "`Q'"
		replace Q = "`k'" in `k'
	}

	destring Q, replace
	
	* simple
	line  ML_lnm2b ML_lnv2a  ML_lnv2s    Q, xlabel(`l') xtitle("") ytitle("Median absolute percentage valuation error", height(5)) ylabel(#5) yscale(range(10 40) titlegap(5)) lpattern("l" ".." "__#"  "--..") legend(size(medium) rows(1) region(lcolor(white))) plotregion(color(white)) graphregion(color(white)) plotregion(color(white))
	graph export ${results}\\Graph_`err'_Industry_Med_simple_${mrun}.pdf, replace
}


* By characteristics : med  aberr and err
foreach err in aberr err {
	foreach char in  Size M2B ROE {
		  foreach v in ML_lnv2s ML_lnv2a ML_lnm2b {
			    use combined_full_${mrun}, clear
				
				* drop dummy observations (used in ML code)
				drop if hash100 == 100
				
    			rename crsp_market_equity Size
				rename roe_wr ROE
				rename m2b M2B
				set more off
				local thefile ${results}\\`v'`err'_`char'_Med_${mrun}.csv
				tempvar myfile
				file open `myfile' using `thefile', write replace
				capture drop aberr_`v'
				if "`err'" == "aberr" {
					gen aberr_`v' = abs(err_`v')
				}
			
				sort mth `char'
				capture drop Q
					
				gquantiles Q = `char' if !missing(`char'), xtile by(mth) nquantiles(5)
					
				* write the median/mean of each quintile to a text file
				foreach q in 1 2 3 4 5 {
					sum `err'_`v' if Q == `q', detail
					file write `myfile' "`q'" "," "`r(p50)'" _n	
				}
				file close `myfile'
				import delimited ${results}\\`v'`err'_`char'_Med_${mrun}.csv, clear
				save ${results}\\`v'`err'_`char'_Med_${mrun}, replace
			}	
			
			* merge errors from all ML modles
			use ${results}\\ML_lnv2s`err'_`char'_Med_${mrun}, clear
			rename v2 ML_lnv2s
			foreach v in ML_lnv2a ML_lnm2b  {
				merge 1:1 v1 using ${results}\\`v'`err'_`char'_Med_${mrun}, keep(master match using) nogen
				rename v2 `v'
			}	 
			rename v1 Q
			destring Q, replace
			save ${results}\temp1, replace

			use ${results}\temp1, clear
			* simple
			if "`err'" == "aberr" {
				line  ML_lnm2b ML_lnv2a  ML_lnv2s     Q, xtitle("Quintiles of `char'") ytitle("Median absolute percentage valuation error", height(5)) ylabel(#5)  yscale(range(20 60)) lpattern("l" ".." "__#"  "--..")  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white)))
				graph export ${results}\\Graph_`err'_`char'_Med_simple_${mrun}.pdf, replace
			}
			else if "`err'" == "err" {
			   line  ML_lnm2b ML_lnv2a  ML_lnv2s     Q, xtitle("Quintiles of `char'") ytitle("Median percentage valuation error", height(5)) ylabel(#5)  yscale(range(-40 60)) lpattern("l" ".." "__#"  "--..")  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white)))
				graph export ${results}\\Graph_`err'_`char'_Med_simple_${mrun}.pdf, replace 
			}   
	}	
}	

*------------------------------------------------------------------------------		
* (6) Figure 3: Characteristics of misvalued firms
*------------------------------------------------------------------------------

* average decile numbers of  Size, m2b, ROE and % Neweconomy for error deciles
local ml_models ML_lnm2b ML_lnv2a ML_lnv2s
foreach err in "abserr" "err" {
	foreach model in `ml_models' {
		use combined_full_${mrun}, clear
		
		* drop dummy observations (used in ML code)
		drop if hash100 == 100

		* selected sorting variables
		gen size = m
		gen roe = profitability_an		

		merge 1:1 gvkeynum mth using neweconomy, keep(master match) nogen
		* get target multiple for this particular model
		local multiple = substr("`model'",-5,.)
		unab vars: `err'_`model' size m2b roe

		tsset gvkeynum mth
		sort gvkeynum mth
		foreach v in `vars' {
			gquantiles rank_`v' = `v', xtile nquantiles(10) by(mth)
		}

		keep gvkeynum mth rank_* Neweconomy
		gcollapse (mean) rank_size rank_m2b rank_roe Neweconomy, by(rank_`err'_`model')
		save `err'_`model'_characteristics_${mrun}, replace
	}
}

* save avg deciles of characteristics by error and model
foreach err in "abserr" "err" {
	foreach char in rank_size rank_m2b rank_roe Neweconomy {
		foreach model in `ml_models' {
			use `err'_`model'_characteristics_${mrun}, replace
			keep  rank_`err'_`model' `char'
			ren `char' `model'
			ren rank_`err'_`model' decile
			save `err'_`model'_`char'_${mrun}, replace
		}
	}
}	


* merge by characteristic and make graph
foreach err in "abserr" "err" {
	foreach char in rank_size rank_m2b rank_roe Neweconomy {
		
		use `err'_ML_lnm2b_`char'_${mrun}, replace
		
		
		merge 1:1 decile using `err'_ML_lnv2a_`char'_${mrun}, keep(match) nogen
		merge 1:1 decile using `err'_ML_lnv2s_`char'_${mrun}, keep(match) nogen
		label variable ML_lnm2b "ML_lnm2b"
		label variable ML_lnv2a "ML_lnv2a"
		label variable ML_lnv2s "ML_lnv2s"
		
		local err_label
		if "`err'" == "err" {
			local err_label "{&epsilon} decile"
		}
		else if "`err'" == "abserr" {
			local err_label "|{&epsilon}| decile"
		}
		
		if "`char'" == "Neweconomy" {
			
			line  ML_lnm2b ML_lnv2a  ML_lnv2s decile, xlabel(#10) ytitle("% New") xtitle("Neweconomy deciles") ylabel(#10) yscale(range(0 1) titlegap(5)) lpattern("l" ".." "__#"  "--..") legend(size(medium) rows(1) region(lcolor(white))) plotregion(color(white)) graphregion(color(white)) plotregion(color(white))
		}
		
		else {
			
			local no_rank_char = subinstr("`char'","rank_","",.)
			di " --- `no_rank_char'"
			line  ML_lnm2b ML_lnv2a  ML_lnv2s    decile, xlabel(#10) ytitle("`err_label'") xtitle("`no_rank_char' deciles") ylabel(#10) yscale(range(0 10) titlegap(5)) lpattern("l" ".." "__#"  "--..") legend(size(medium) rows(1) region(lcolor(white))) plotregion(color(white)) graphregion(color(white)) plotregion(color(white))
		}
		
		graph export ${results}\\Graph_`err'_d_`char'_${mrun}.pdf, replace
	}
}	


