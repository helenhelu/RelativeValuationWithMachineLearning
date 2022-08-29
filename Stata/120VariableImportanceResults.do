* ----------------------------------------------------------------------------
* VariableImportanceResults
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
* Table 2 Feature importance (top10 & by group) MLlnm2b MLlnv2s
* (1) assemble yearly variable importance by input
* (2) assemble yearly variable importance by category
* (3) Figure4 and IA. time-series of category var importance (three models in the same graph; separate graphs for all, new and old economy)
* (4) Figure4 and IA. time-series of category var importance (all, new and old economy in the same graph; separate graph for each model)
* (5) Toable 5. top variables all, New and Old economy
* (6) Toable 6. category summary (full sampel and by decade)
* (7) Table 7. top 10 variables in 2010 decade and in 1980 decade(show all four decades): all, New and Old economy
* (8) Table 8. SHAP values of important vairables for most mis-valued firms
*---------------------------------------------------------------------------

*---------------------------------------------------------------------------
* (1) assemble yearly variable importance by input
*---------------------------------------------------------------------------

foreach eco in "" "_Neweconomy" "_Oldeconomy" {
	foreach model in lnm2b lnv2a lnv2s {
		use Base${mrun}`model'_ABS_SHAP_combined_Y1980`eco', replace
		keep variable scaledimportance
		rename scaledimportance Y1980
		save temp, replace

		forvalues i = 1981/2019 {
			use temp, clear
			merge 1:1 variable using Base${mrun}`model'_ABS_SHAP_combined_Y`i'`eco', keep(master match) nogen keepusing(scaledimportance)
			rename scaledimportance Y`i'
			save temp, replace
		}
		save ABSSHAP_input_yearly`eco', replace

		use ABSSHAP_input_yearly`eco', clear
		sort variable
		reshape long Y, i(variable) j(year)
		rename Y value
		reshape wide value, i(year) j(variable) string
		unab inputs: value*
		foreach v in  `inputs' {
			local name = substr("`v'",6,.)
			rename `v' `name'
			label variable `name' "`name'"
		}
		tsset year
		save ABSSHAP_inputs_yearly_`model'_${mrun}`eco', replace
	}
}	

*---------------------------------------------------------------------------
* (2) assemble yearly variable importance by category
*---------------------------------------------------------------------------

foreach eco in "" "_Neweconomy" "_Oldeconomy" {
	foreach model in lnm2b lnv2a lnv2s {
		use Base${mrun}`model'_ABS_SHAP_combined_Y1980`eco', replace
		keep variable scaledimportance
		rename scaledimportance Y1980
		save temp, replace

		forvalues i = 1981/2019 {
			use temp, clear
			merge 1:1 variable using Base${mrun}`model'_ABS_SHAP_combined_Y`i'`eco', keep(master match) nogen keepusing(scaledimportance)
			rename scaledimportance Y`i'
			save temp, replace
		}
		merge 1:1 variable using ${source}\MLvars_category, keep(master match using) nogen
		save ABSSHAP_yearly, replace

		use ABSSHAP_yearly, clear
		sort category
		collapse (sum) Y*, by(category)
		drop if missing(category)
		reshape long Y, i(category) j(year)
		rename Y value
		reshape wide value, i(year) j(category) string
		unab inputs: value*
		foreach v in  `inputs' {
			local name = substr("`v'",6,.)
			rename `v' `name'
			label variable `name' "`name'"
		}

		tsset year
		save ABSSHAP_category_yearly_`model'_${mrun}`eco', replace
	}
}

*---------------------------------------------------------------------------
* (3) time-series of category var importance (three models in the same graph; separate graphs for all, new and old economy)
*---------------------------------------------------------------------------

foreach eco in "" "_Neweconomy" "_Oldeconomy" {
	foreach category in Profitability Growth Industry Financial_soundness Efficiency {
		use ABSSHAP_category_yearly_lnm2b_${mrun}`eco', replace
		keep `category' year
		rename `category' lnm2b
		label variable lnm2b "lnm2b"

		merge 1:1 year using ABSSHAP_category_yearly_lnv2a_${mrun}`eco', keepusing(`category') nogen
		rename `category' lnv2a
		label variable lnv2a "lnv2a"

		merge 1:1 year using ABSSHAP_category_yearly_lnv2s_${mrun}`eco', keepusing(`category') nogen
		rename `category' lnv2s
		label variable lnv2s "lnv2s"

		line lnm2b lnv2a  lnv2s  year, xtitle("") xlabel(, labsize(vlarge)) ylabel(#5, labsize(vlarge))  yscale(range(0 0.5) titlegap(5))  lpattern("l" ".." "__#"  "--..")  graphregion(color(white)) plotregion(color(white))  legend(size(vlarge) rows(1) region(lcolor(white))) 
		graph export ${results}\\Graph_ABSSHAP_`category'_ML_${mrun}`eco'.pdf, replace
	}
}

*---------------------------------------------------------------------------
* (4) time-series of category var importance (all, new and old economy in the same graph; separate graph for each model)
*---------------------------------------------------------------------------

foreach model in lnm2b lnv2a lnv2s {
	foreach category in Profitability Growth Industry Financial_soundness Efficiency {
		use ABSSHAP_category_yearly_`model'_${mrun}, replace
		keep `category' year
		label variable `category' "All"
		rename `category' All
		

		merge 1:1 year using ABSSHAP_category_yearly_`model'_${mrun}_Neweconomy, keepusing(`category') nogen
		label variable `category' "New"
		rename `category' New
		

		merge 1:1 year using ABSSHAP_category_yearly_`model'_${mrun}_Oldeconomy, keepusing(`category') nogen
		label variable `category' "Old"
		rename `category' Old
		

		line All New Old  year, xtitle("") xlabel(, labsize(vlarge)) ylabel(#5, labsize(vlarge))  yscale(range(0 0.5) titlegap(10))  lpattern("l" ".." "__#"  "--..")  graphregion(color(white)) plotregion(color(white))  legend(size(vlarge) rows(1) region(lcolor(white))) 
		graph export ${results}\\Graph_ABSSHAP_`category'_ML_`model'_${mrun}_comb.pdf, replace
	}
}



*---------------------------------------------------------------------------
* (5) top variables all, New and Old economy
*---------------------------------------------------------------------------

* gen rho variable (rank correlation between a feature and predicted target variable): the average of monthly rank correlation 
local ml_models ML_lnv2a ML_lnv2s ML_lnm2b

foreach eco in "" "_Neweconomy" "_Oldeconomy" {
* save smaller files with only the info we need.
	foreach model in `ml_models' {
		use combined_full_${mrun}, clear
		
		if "`eco'" != "" {
			merge 1:1 gvkeynum mth using neweconomy, keep(master match) nogen
			local v = substr("`eco'",2,.)
			keep if `v' == 1
			drop `v'
		}
			
		unab features: CAPMbeta industry book sale_ac assets debt_book_value *_wr *_an  
		
		* get target multiple for this particular model
		local multiple = substr("`model'",-5,.)
		
		* generate straight predicted multiple from predicted multiple
		gen pred_`multiple' = exp(y_pred_ML_`multiple')
		
		keep gvkeynum mth pred_`multiple' `features' 
		tsset gvkeynum mth
		sort gvkeynum mth
		save vi_`model'_${mrun}, replace
	}

	foreach model in `ml_models' {
		use vi_`model'_${mrun}, clear

		* get multiple used as target
		local multiple = substr("`model'",-5,.)
		
		* generate ranks
		foreach v in pred_`multiple' `features' {
			sort mth `v'
			gquantiles rank_`v' = `v', xtile nquantiles(1000) by(mth)
		}
		
		keep mth rank_*
		save temp_${mrun}`model', replace
	}	

	* calculate rank correlations
	foreach model in `ml_models' {
		
		use vi_`model'_${mrun}, clear
		unab features: CAPMbeta industry book sale_ac assets debt_book_value *_wr *_an 

		* get multiple used as target
		local multiple = substr("`model'",-5,.)
		
		local thefile ${results}\\Base${mrun}`model'_rho`eco'.csv
		tempvar myfile
		file open `myfile' using `thefile', write replace
		
		foreach var in `features' {
			use temp_${mrun}`model', clear
			bys mth: asreg rank_`var' rank_pred_`multiple'
			di "`var' -> `=_R2''"
			gen rho = _R2 ^ 0.5
			replace rho = -rho if _b_rank_pred_`multiple' < 0 
			gcollapse (mean) rho, by(mth)
			sum rho
			capture drop _Nobs _R2 _adjR2  _b_rank_pred_`multiple' _b_cons
			file write `myfile' "`var'" "," "`r(mean)'" _n
		}
		
		file close `myfile'
	}	

	* merge in category names, expected signs in the percentage SHAP file for the full sample	

	foreach model in `ml_models' {	

		import delimited ${results}\\Base${mrun}`model'_rho`eco'.csv, clear

		ren v1 variable 
		ren v2 rho
		merge 1:1 variable using ${source}\MLvars_category, keep(master match using) nogen

		local multiple = substr("`model'",-5,.)
		merge 1:1 variable using Base${mrun}`multiple'_ABS_SHAP`eco'_combined, keep(master match using) nogen

		keep category variable scaledimportance cumulativescaledimportance rho
		gsort -scaledimportance 
		rename category Category
		rename scaledimportance SHAP
		rename cumulativescaledimportance CSHAP
		rename variable Variable
		replace SHAP = SHAP* 100
		replace CSHAP = CSHAP * 100
		
		* include expected signs
		gen Expected_sign = ""
		replace Expected_sign = "-" if Category == "CAPMbeta"
		replace Expected_sign = "+/-" if Category == "Capitalisation"
		replace Expected_sign = "-" if Category == "Payout"
		if "`multiple'" == "lnv2s" {
			replace Expected_sign = "-" if Category == "Efficiency"
		}
		else {
			replace Expected_sign = "+" if Category == "Efficiency"
		}
		replace Expected_sign = "+/-" if Category == "Financial_soundness"
		replace Expected_sign = "+" if Category == "Growth"
		replace Expected_sign = "N.A." if Category == "Industry"
		replace Expected_sign = "+/-" if Category == "Liquidity"
		replace Expected_sign = "+" if Category == "Profitability"
		replace Expected_sign =  "-" if Category == "Size"
		replace Expected_sign = "+/-" if Category == "Solvency"
		
		save ${mrun}`model'_ABS_SHAP`eco', replace
	}


	foreach model in `ml_models' {	
		
		use ${mrun}`model'_ABS_SHAP`eco', clear
		merge 1:1 Variable using ${results}\\variable_label, keep(master match) nogen
		gsort -SHAP
		* save the top 20 (fits three models vertically in a page)
		drop if _n > 10
		* replace _ with \_ for latex
		foreach v in Variable Description Category {
		   replace `v' = subinstr(`v',"_", "\_", .) 
		   replace `v' = subinstr(`v',"&", "\&", .)
		}

		local varlist  Variable Description Category SHAP CSHAP rho Expected_sign
		local formatlist  %5s  %5s %5s  %5.1f  %5.1f  %5.3f  %5s 
		local alignlist  lllrrrc
		
		file close _all
		di "output ${results}\\${mrun}`model' feature importance using data2tex"
		data2tex `varlist' using ${results}\\${mrun}`model'_ABS_SHAP1`eco'.tex, f(`formatlist') a(`alignlist') replace

		
		di "trying to file filter ${results}\\${mrun}`model' [1st time]"
		file close _all
		sleep 1000
		capture filefilter ${results}\\${mrun}`model'_ABS_SHAP1`eco'.tex  ${results}\\${mrun}`model'_ABS_SHAP2`eco'.tex, from("Expected\BS_sign") to("Expected sign") replace

		di "trying to filefilter ${results}\\${mrun}`model' [2nd time]"
		file close _all
		sleep 1000
		filefilter ${results}\\${mrun}`model'_ABS_SHAP2`eco'.tex  ${results}\\${mrun}`model'_ABS_SHAP`eco'.tex, from("Financial\BS_soundness") to("Financial soundness") replace
		
	}	


	* combine panels into one table
	file close _all

	panelcombine, use(${results}\\${mrun}ML_lnm2b_ABS_SHAP`eco'.tex  ${results}\\${mrun}ML_lnv2a_ABS_SHAP`eco'.tex  ${results}\\${mrun}ML_lnv2s_ABS_SHAP`eco'.tex )  columncount(7) paneltitles("ML\_lnm2b" "ML\_lnv2a" "ML\_lnv2s") save(${results}\ABS_SHAP_${mrun}`eco'.tex)
}


*---------------------------------------------------------------------------
* (6) category summary, reverse some ranks so that all varaibles are consistent (a bigger value == more solvent, more sound, better capitalised, more profitable, etc.)	
*---------------------------------------------------------------------------

* reverse rank the following, to aggregate at category level, so that a bigger value == more solvent, more sound, better capitalised, more profitable, etc.
local ml_models ML_lnv2a ML_lnv2s ML_lnm2b
foreach model in `ml_models' {

	use vi_`model'_${mrun}, clear
	unab features: CAPMbeta industry book sale_ac assets debt_book_value *_wr *_an 
	
	* get multiple used as target
	local multiple = substr("`model'",-5,.)
	
	* generate ranks
	foreach v in pred_`multiple' `features' {
	    
		if "`v'" == "capital_ratio_wr" | "`v'" == "debt_invcap_wr" | "`v'" == "totdebt_invcap_wr" | "`v'" == "curr_debt_wr" | "`v'" == "debt_ebitda_wr" | "`v'" == "dltt_be_wr" | "`v'" == "int_debt_wr" | "`v'" == "int_totdebt_wr" | "`v'" == "invt_act_wr" | "`v'" == "lt_debt_wr" | "`v'" == "lt_ppent_wr"| "`v'" == "rect_act_wr" | "`v'" ==  "short_debt_wr" | "`v'" ==  "efftax_wr" | "`v'" == "de_ratio_wr"| "`v'" ==  "debt_assets_wr"| "`v'" == "debt_at_wr" | "`v'" == "debt_capital_wr" {
			sort mth `v'
			gquantiles rank_`v' = `v', xtile nquantiles(1000) by(mth)
			* reverse ranking for these variables
			replace rank_`v' = (1000 - rank_`v') + 1
		}
		else {
		    sort mth `v'
			gquantiles rank_`v' = `v', xtile nquantiles(1000) by(mth)
		}		
	}
	keep mth rank_*
	save temp_${mrun}`model'_2cat, replace
}	

*---------------------------------------------------------------------------
* average rank in each category
* correlation between category rank and target rank 
*---------------------------------------------------------------------------

* get category definitions (saved in locals, see local categories for list)
* use -include- rather than -do- to keep local variables available
include ${code}\\categories.do

foreach list in `categories' {
    local `list'_list ""
	foreach v in ``list'' {
	    local `list'_list ``list'_list' rank_`v'
	}
	display "`list' :: ``list'_list'"
}

foreach model in `ml_models' {
    use temp_${mrun}`model'_2cat, clear
	di "model = `model'"
	su rank_dpr_wr

	foreach list in `categories' {
		egen mrank_`list' = rowmean(``list'_list')
	}
	save temp_${mrun}`model'_2cat1, replace
	
	* get multiple used as target
	local multiple = substr("`model'",-5,.)
	
	local thefile ${results}\\Base${mrun}`model'_rho_2cat.csv
	tempvar myfile
	file open `myfile' using `thefile', write replace
	
	foreach cat in `categories'  {
	    use temp_${mrun}`model'_2cat1, clear
	    bys mth: asreg mrank_`cat' rank_pred_`multiple'
		gen rho = _R2 ^ 0.5
		replace rho = -rho if _b_rank_pred_`multiple' < 0 
		gcollapse (mean) rho, by(mth)
		sum rho
		capture drop _Nobs _R2 _adjR2 _b_rank_pred_`multiple' _b_cons
		file write `myfile' "`cat'" "," "`r(mean)'" _n
	}
	file close `myfile'
}	
	
* import category average rank correlation files 
foreach model in `ml_models' {	
    import delimited ${results}\\Base${mrun}`model'_rho_2cat.csv, clear
	ren v1 Category
	ren v2 rho
	save ${results}\\Base${mrun}`model'_rho_2cat, replace
}

*---------------------------------------------------------------------------
* Feature importance by category and across time
*---------------------------------------------------------------------------

local ml_models ML_lnv2a ML_lnv2s ML_lnm2b
foreach model in `ml_models' {
	local i 1980
	local multiple = substr("`model'",-5,.)
	use Base${mrun}`multiple'_ABS_SHAP_combined_`i', clear
	keep variable scaledimportance
	rename scaledimportance SHAP1980
	forvalues i = 1990(10)2010 {
		merge 1:1 variable using Base${mrun}`multiple'_ABS_SHAP_combined_`i', keep(master match) nogen
		keep variable SHAP* scaledimportance
		rename scaledimportance SHAP`i'
	}

	gsort -SHAP1980
	gsort -SHAP2010

	merge 1:1 variable using ${source}\MLvars_category, keep(master match) nogen
	gcollapse (sum) SHAP*, by(category)
	ren category Category 
	foreach v in SHAP1980 SHAP1990 SHAP2000 SHAP2010 {
		replace `v' = `v' * 100
	}
	
	gen Chg = SHAP2010 - SHAP1980
	save Base${mrun}`multiple'_decade_ABS, replace
}


local ml_models ML_lnv2a ML_lnv2s ML_lnm2b
foreach model in `ml_models' {	
		
	local multiple = substr("`model'",-5,.)
	use Base${mrun}`multiple'_ABS_SHAP_combined, clear
	
	merge 1:1 variable using ${source}\MLvars_category, keep(master match using) nogen
	rename category Category
	rename scaledimportance SHAP
	rename variable Variable
	replace SHAP = SHAP * 100
	sort Category 
	gcollapse (sum) SHAP, by(Category)
	merge 1:1 Category using ${results}\\Base${mrun}`model'_rho_2cat, keep(match) nogen
	
	* include expected signs
	gen Expected_sign = ""
	replace Expected_sign = "-" if Category == "CAPMbeta"
	replace Expected_sign = "+/-" if Category == "Capitalisation"
	replace Expected_sign = "-" if Category == "Payout"
	if "`multiple'" == "lnv2s" {
		replace Expected_sign = "-" if Category == "Efficiency"
	}
	else {
		replace Expected_sign = "+" if Category == "Efficiency"
	}
	replace Expected_sign = "+/-" if Category == "Financial_soundness"
	replace Expected_sign = "+" if Category == "Growth"
	replace Expected_sign = "N.A." if Category == "Industry"
	replace Expected_sign = "+/-" if Category == "Liquidity"
	replace Expected_sign = "+" if Category == "Profitability"
	replace Expected_sign =  "-" if Category == "Size"
	replace Expected_sign = "+/-" if Category == "Solvency"
	
	merge 1:1 Category using Base${mrun}`multiple'_decade_ABS, keep(master match) nogen
	
	
	foreach v in Category {
	   replace `v' = subinstr(`v',"_", "\_", .) 
	   replace `v' = subinstr(`v',"&", "\&", .)
	}
	 
	gsort -SHAP
	
	file close _all
	local varlist  Category SHAP rho Expected_sign SHAP1980 SHAP1990 SHAP2000 SHAP2010 Chg
	local formatlist   %5s  %5.1f  %5.3f  %5s %5.1f %5.1f %5.1f %5.1f %5.1f
	local alignlist  lrrcrrrrr
	data2tex `varlist' using ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP1.tex, f(`formatlist') a(`alignlist') replace
	
	file close _all
	sleep 1000
	filefilter ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP1.tex ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP2.tex, from("SHAP1980") to("1980") replace
	
	file close _all
	sleep 1000		
	filefilter ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP2.tex ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP3.tex, from("SHAP1990") to("1990") replace
	
	file close _all
	sleep 1000		
	filefilter ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP3.tex ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP4.tex, from("SHAP2000") to("2000") replace
	
	file close _all
	sleep 1000		
	filefilter ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP4.tex ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP5.tex, from("SHAP2010") to("2010") replace
	
	file close _all
	sleep 1000		
	filefilter ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP5.tex ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP6.tex, from("Expected\BS_sign") to("Expected sign") replace
	
	file close _all
	sleep 1000		
	filefilter ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP6.tex ${results}\\Base${mrun}`multiple'_cat_ABS_SHAP.tex, from("Financial\BS_soundness") to("Financial soundness") replace
}	

file close _all

* combine panels into one table

panelcombine, use(${results}\\Base${mrun}lnm2b_cat_ABS_SHAP.tex ${results}\\Base${mrun}lnv2a_cat_ABS_SHAP.tex ${results}\\Base${mrun}lnv2s_cat_ABS_SHAP.tex )  columncount(3) paneltitles("MLlnm2b" "MLlnv2a" "MLlnv2s") save(${results}\cat_ABS_SHAP_${mrun}.tex)



*---------------------------------------------------------------------------
* (7) top 10 variables in 2010 decade and in 1980 decade(show all four decades): all, New and Old economy
*---------------------------------------------------------------------------

local model1 Base${mrun}lnm2b 
local model2 Base${mrun}lnv2a
local model3 Base${mrun}lnv2s 

foreach eco in "" "_Neweconomy" "_Oldeconomy" {
	foreach model in `model1' `model2'  `model3' {
		local i 1980
		use `model'_ABS_SHAP_combined_`i'`eco', clear
		keep variable scaledimportance
		rename scaledimportance SHAP1980
		forvalues i = 1990(10)2010 {
			merge 1:1 variable using `model'_ABS_SHAP_combined_`i'`eco', keep(master match) nogen
			keep variable SHAP* scaledimportance
			rename scaledimportance SHAP`i'
		}

		gsort -SHAP1980
		gsort -SHAP2010

		merge 1:1 variable using ${source}\MLvars_category, keep(master match) nogen
		*gcollapse (sum) SHAP*, by(category)
		ren category Category 
		foreach v in SHAP1980 SHAP1990 SHAP2000 SHAP2010 {
			replace `v' = `v' * 100
		}
		
		gen Pctchg = (SHAP2010 / SHAP1980 - 1) * 100
		save `model'_decade_ABS`eco', replace
	}
	
	* most important variables
	foreach model in `model1' `model2'  `model3' {
		use `model'_decade_ABS`eco', clear
		merge 1:1 variable using  `model'_ABS_SHAP`eco'_combined, keep(match) nogen
		ren scaledimportance SHAP
		replace SHAP = SHAP * 100
		
		rename variable Variable
		merge 1:1 Variable using ${results}\\variable_label, keep(master match) nogen
		gsort -SHAP2010
		* save the top 10 (fits three models vertically in a page)
		gen drop = ( _n > 10 )
		gsort -SHAP1980
		replace drop = 0 if (_n <= 10)
		drop if drop == 1
		
		gen Chg = (SHAP2010 - SHAP1980)
		gen diff = abs(Chg)
		gsort -diff
		drop if _n > 10
		gsort -SHAP2010
		
		capture drop drop
		* replace _ with \_ for latex
		foreach v in Variable Description Category {
		   replace `v' = subinstr(`v',"_", "\_", .) 
		   replace `v' = subinstr(`v',"&", "\&", .)
		}

		local varlist  Variable Description Category SHAP SHAP1980 SHAP1990 SHAP2000 SHAP2010 Chg
		local formatlist  %5s    %5s          %5s    %5.1f  %5.1f  %5.1f   %5.1f        %5.1f %5.1f  
		local alignlist  lllrrrrrr
		
		file close _all
		di "output ${results}\\${mrun}`model' feature importance using data2tex"
		data2tex `varlist' using ${results}\\`model'_ABS_SHAP1`eco'_decade.tex, f(`formatlist') a(`alignlist') replace

		
		di "trying to file filter ${results}\\${mrun}`model' [1st time]"
		file close _all
		sleep 1000
		capture filefilter ${results}\\`model'_ABS_SHAP1`eco'_decade.tex  ${results}\\`model'_ABS_SHAP2`eco'_decade.tex, from("Expected\BS_sign") to("Expected sign") replace

		di "trying to filefilter ${results}\\${mrun}`model' [2nd time]"
		file close _all
		sleep 1000
		filefilter ${results}\\`model'_ABS_SHAP2`eco'_decade.tex  ${results}\\`model'_ABS_SHAP`eco'_decade.tex, from("Financial\BS_soundness") to("Financial soundness") replace
		
	}	


	* combine panels into one table
	file close _all

	panelcombine, use(${results}\\Base${mrun}lnm2b_ABS_SHAP`eco'_decade.tex  ${results}\\Base${mrun}lnv2a_ABS_SHAP`eco'_decade.tex  ${results}\\Base${mrun}lnv2s_ABS_SHAP`eco'_decade.tex )  columncount(7) paneltitles("ML\_lnm2b" "ML\_lnv2a" "ML\_lnv2s") save(${results}\ABS_SHAP_${mrun}`eco'_decade.tex)
}

*---------------------------------------------------------------------------
*(8) SHAP values of important vairables for most mis-valued firms
*---------------------------------------------------------------------------

* average for each decile by decade 
* present the 10 most important vars 

local ml_models  ML_lnm2b  ML_lnv2a ML_lnv2s 
local err "abserr"
foreach eco in "" "_Neweconomy" "_Oldeconomy" {
* assign decile number by mth for aberr; keep deciles 1 and 10
	foreach model in `ml_models' {
		use combined_full_${mrun}, clear
		
		if "`eco'" != "" {
			merge 1:1 gvkeynum mth using neweconomy, keep(master match) nogen
			local v = substr("`eco'",2,.)
			keep if `v' == 1
			drop `v'
		}
		keep gvkeynum mth  `err'_`model' 
		tsset gvkeynum mth
		sort gvkeynum mth
		gquantiles rank_`err'_`model' = `err'_`model', xtile nquantiles(10) by(mth)
		keep if rank_`err'_`model' == 1 | rank_`err'_`model' == 10
		keep gvkeynum mth rank_`err'_`model'
		save `err'_`model'`eco'_${mrun}, replace
	}
	
	* full sample SHAP
	foreach model in `ml_models' {
		local multiple = substr("`model'",-5,.)
		use ABS_SHAP_Base${mrun}`multiple'_combined.dta, clear
		merge 1:1 gvkeynum mth using `err'_`model'`eco'_${mrun}, keep(match) nogen
		* average for each decile
		unab features: CAPMbeta industry book sale_ac assets debt_book_value *_wr *_an  
		gcollapse (mean) `features', by(rank_`err'_`model')
		
		xpose, clear
		drop in 1
		ren v1 SHAPE
		ren v2 SHAPH
		gen variable = ""
		local k = 0
		foreach v in `features' {
			local ++k
			replace variable = "`v'" in `k'
		}
		save SHAP_misvalued_`err'_`model'`eco'_${mrun}, replace
	}
	
	* SHAP by decade
	* assign decile number by mth for aberr; keep deciles 1 and 10
	foreach model in `ml_models' {
		* get target multiple for this particular model
		local multiple = substr("`model'",-5,.)
		use ABS_SHAP_Base${mrun}`multiple'_combined.dta, clear
		merge 1:1 gvkeynum mth using `err'_`model'`eco'_${mrun}, keep(match) nogen
		* average for each decile by decade
		unab features: CAPMbeta industry book sale_ac assets debt_book_value *_wr *_an  
		* generate decade 
		gen decade = floor(year(dofm(mth))/10)*10
		sort decade rank_`err'_`model'	
		gcollapse (mean) `features', by(decade rank_`err'_`model')
		
		xpose, clear
		drop in 1
		drop in 1
	
		ren v1 E80
		ren v2 H80
		ren v3 E90
		ren v4 H90
		ren v5 E00
		ren v6 H00
		ren v7 E10
		ren v8 H10
		
		gen variable = ""
		local k = 0
		foreach v in `features' {
			local ++k
			replace variable = "`v'" in `k'
		}
		save SHAP_D_misvalued_`err'_`model'`eco'_${mrun}, replace
	}
	
	* merge SHAP values
	foreach model in `ml_models' {
		use SHAP_misvalued_`err'_`model'`eco'_${mrun}, clear
		merge 1:1 variable using SHAP_D_misvalued_`err'_`model'`eco'_${mrun}, keep(match) nogen
		unab vars: SHAP* E* H*
		foreach v in `vars' {
			replace `v' = `v' * 100
		}
		* merge in catetory names
		merge 1:1 variable using ${source}\MLvars_category, keep(master match using) nogen
		
		* rank the top 10 for hardest to value in 1980 and 2010 decades
		rename variable Variable
		merge 1:1 Variable using ${results}\\variable_label, keep(master match) nogen
		
		gsort -H10
		* save the top 10 (fits three models vertically in a page)
		gen drop = ( _n > 10 )
		gsort -H80
		replace drop = 0 if (_n <= 10)
		drop if drop == 1
			
		gen ChgH = (H10 - H80)
		gen diff = abs(ChgH)
		gsort -diff
		drop if _n > 10
		gsort -H10
		
		gen ChgE = (E10 - E80)
		capture drop drop
		
		rename category Category
		* replace _ with \_ for latex
		foreach v in Variable Description Category {
		   replace `v' = subinstr(`v',"_", "\_", .) 
		   replace `v' = subinstr(`v',"&", "\&", .)
		}

		local varlist  Variable Description Category SHAPE SHAPH E80 H80 E90 H90  E00  H00 E10  H10   ChgE ChgH
		local formatlist  %5s    %5s        %5s  %5.1f  %5.1f %5.1f %5.1f %5.1f %5.1f %5.1f  %5.1f  %5.1f  %5.1f  %5.1f %5.1f  
		local alignlist  lllrrrrrrrrrrrr
			
		file close _all
		di "output ${results}\\${mrun}`model' feature importance of misvalued firms using data2tex"
		data2tex `varlist' using ${results}\\Base${mrun}`model'_ABS_SHAP1`eco'_misvalued_decade.tex, f(`formatlist') a(`alignlist') replace

			
		di "trying to file filter ${results}\\${mrun}`model' [1st time]"
		file close _all
		sleep 1000
		capture filefilter ${results}\\Base${mrun}`model'_ABS_SHAP1`eco'_misvalued_decade.tex  ${results}\\Base${mrun}`model'_ABS_SHAP2`eco'_misvalued_decade.tex, from("Expected\BS_sign") to("Expected sign") replace

		di "trying to filefilter ${results}\\${mrun}`model' [2nd time]"
		file close _all
		sleep 1000
		filefilter ${results}\\Base${mrun}`model'_ABS_SHAP2`eco'_misvalued_decade.tex  ${results}\\Base${mrun}`model'_ABS_SHAP`eco'_misvalued_decade.tex, from("Financial\BS_soundness") to("Financial soundness") replace
			
	}	
		* combine panels into one table
	file close _all
	panelcombine, use(${results}\\Base${mrun}ML_lnm2b_ABS_SHAP`eco'_misvalued_decade.tex  ${results}\\Base${mrun}ML_lnv2a_ABS_SHAP`eco'_misvalued_decade.tex  ${results}\\Base${mrun}ML_lnv2s_ABS_SHAP`eco'_misvalued_decade.tex )  columncount(7) paneltitles("ML\_lnm2b" "ML\_lnv2a" "ML\_lnv2s") save(${results}\ABS_SHAP_${mrun}`eco'_misvalued_decade.tex)

}
	
	
	
	
	
	
	
	
	