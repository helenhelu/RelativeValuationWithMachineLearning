* ----------------------------------------------------------------------------
* ExamplePeerFirms
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

local num = 10

* check if weights reconcile with predicted multiples
local block = 3

import excel ${results}\\weights_testblock`block'.xlsx, sheet("Sheet1") firstrow clear

ren A gvkeynum
destring gvkeynum, replace

* return a list of all vars
ds
local varlist "`r(varlist)'"
local exclude `""gvkeynum""'
local test: list varlist  - exclude

foreach v in `test' {
	display "`v'"
	local gvkey: variable label `v'
	display "`gvkey'"
	ren `v' firm`gvkey'	
}
save weights_testblock`block', replace

* generate the predicted value for a firm from weights 
local gvkey = 34410

use weights_testblock`block', replace
keep gvkeynum firm`gvkey'

merge 1:m gvkeynum using valuation_data_filtered_blocks, keep(match) nogen
keep if mth == tm(2019m12)

keep gvkeynum  firm`gvkey' mth lnm2b
gen lnm2b_w= firm`gvkey' * lnm2b
egen lnm2b_pred = sum(lnm2b_w)


* generate tables of peers of selected firms
*company long names

use ${source}\\Compustat.dta, clear
keep gvkey conml datadate
gsort gvkey -datadate 
destring gvkey, replace
ren gvkey gvkeynum
duplicates drop gvkeynum, force
drop datadate
save coname, replace

foreach gvkey in 34410 {
	
	use weights_testblock`block', replace
	keep gvkeynum firm`gvkey'
	ren firm`gvkey' weight
	gen train = 1
	
	* add test firm to the dataset
	set obs `=_N+1'
	replace gvkeynum = `gvkey' in `=_N'
	replace train = 0 if missing(train)

	merge 1:m gvkeynum using valuation_data_filtered_blocks, keep(match) nogen
	keep if mth == tm(2019m12)
	local keeplist gvkeynum weight lnm2b industry sicn roe_wr profitability_an  rd_sale_wr salesgrowth_an aftret_invcapx_wr pretret_noa_wr roic_an roce_wr  CAPMbeta train cash2assets_an de_ratio_wr roe_wr

	keep `keeplist'

	merge 1:1 gvkeynum using coname, keep(match) nogen

	* merge in FF12
	merge m:1 sicn using ${source}\\ff12_sic, keep(master match) nogen keepusing(ff12_des)
	merge m:1 sicn using ${source}\\sic2ff49map, keep(master match) nogen keepusing(ff49)
	merge m:1 ff49 using ${source}\\ff49_2_ff49_desc.dta, keep(master match) nogen keepusing(ffi49_desc)
	replace ffi49_desc = "OTHER" if missing(ffi49_desc)
	
	gsort -train -weight 
	
	* weight graph
	gen t = _n-1
	tsset t
	tsline weight if train == 1, scheme(s1mono) xtitle(observations) ytitle(weight) yline(0) ytitle("GBM peer weight") xtitle("Training data observations (descending order by weight)") ylabel(, angle(0))
	graph export ${results}\\peerweights_`gvkey'.pdf, as(pdf) name("Graph") replace

	
	capture drop cumw
	gen cumw = weight in 1
	replace cumw = cumw[_n-1] + weight if !missing(cumw[_n-1]) & train == 1
	label variable cumw "Cum. weight"
	label variable weight "Weight"
	save peer_temp,replace

	* export test firm
	use peer_temp, replace
	keep if train == 0
	ren conml company
	ren ff12_des ff12
	capture drop ff49
	ren ffi49_desc ff49
	ren cumw cumweight

	* replace _ with \_ for latex
	foreach v in company {
		   replace `v' = subinstr(`v',"_", "\_", .) 
		   replace `v' = subinstr(`v',"&", "\&", .)
		}

	local varlist company lnm2b weight cumweight ff12 ff49  rd_sale_wr cash2assets_an de_ratio_wr roe_wr
	
	local formatlist %15s %5.2f %5.2f %5.2f %9s %9s %5.2f %5.2f %5.2f %5.2f		
	local alignlist  lrrrrrrrrrrrrr
	file close _all
	di "output ${results}\\peer weights using data2tex"
	
	*set missing to -999.00
	foreach v of varlist * {
		local vartype = substr("`:type `v''",1,3)
		if "`vartype'" == "str" {
			replace `v' = "999.00" if missing(`v')
		}
		else {
			replace `v' = 999.00 if missing(`v')
		}
	}
	
	data2tex `varlist' using ${results}\\lnm2b_peerweights_`gvkey'_`num'.tex, f(`formatlist') a(`alignlist') replace
	
	* export top peers
	use peer_temp, replace
	gsort -train -weight
	drop if _n > `num' | train == 0
	ren conml company
	ren ff12_des ff12
	capture drop ff49
	ren ffi49_desc ff49
	ren cumw cumweight

	* replace _ with \_ for latex
	foreach v in company {
		   replace `v' = subinstr(`v',"_", "\_", .) 
		   replace `v' = subinstr(`v',"&", "\&", .)
		}

	local varlist company lnm2b weight cumweight ff12 ff49  rd_sale_wr cash2assets_an de_ratio_wr roe_wr
	
	local formatlist %15s %5.2f %5.2f %5.2f %9s %9s %5.2f %5.2f %5.2f %5.2f
	local alignlist  lrrrllrrrr
	file close _all
	di "output ${results}\\peer weights using data2tex"
	
		*set missing to -999.00
	foreach v of varlist * {
		local vartype = substr("`:type `v''",1,3)
		if "`vartype'" == "str" {
			replace `v' = "999.00" if missing(`v')
		}
		else {
			replace `v' = 999.00 if missing(`v')
		}
	}
	
	data2tex `varlist' using ${results}\\lnm2b_peerweights_`gvkey'_top`num'.tex, f(`formatlist') a(`alignlist') replace
	
	* export bottom 10 peers
	use peer_temp, replace
	gsort -train weight
	drop if _n > `num' | train == 0
	ren conml company
	ren ff12_des ff12
	capture drop ff49
	ren ffi49_desc ff49
	ren cumw cumweight

	* replace _ with \_ for latex
	foreach v in company {
	   replace `v' = subinstr(`v',"_", "\_", .) 
	   replace `v' = subinstr(`v',"&", "\&", .)
	}


	local varlist company lnm2b weight cumweight ff12 ff49  rd_sale_wr cash2assets_an de_ratio_wr roe_wr

	
	local formatlist %15s   %5.2f  %5.2f   %5.2f    %9s %9s  %5.2f   %5.2f			%5.2f		%5.2f		
	local alignlist  lrrrllrrrr
	file close _all
	di "output ${results}\\peer weights using data2tex"
	
	*set missing to -999.00
	foreach v of varlist * {
		local vartype = substr("`:type `v''",1,3)
		if "`vartype'" == "str" {
			replace `v' = "999.00" if missing(`v')
		}
		else {
			replace `v' = 999.00 if missing(`v')
		}
	}
	
	data2tex `varlist' using ${results}\\lnm2b_peerweights_`gvkey'_bottom`num'.tex, f(`formatlist') a(`alignlist') replace
}

* merge top and bottom peers panels into one table

foreach gvkey in 34410 {
	panelcombine, use(${results}\\lnm2b_peerweights_`gvkey'_`num'.tex  ${results}\\lnm2b_peerweights_`gvkey'_top`num'.tex ${results}\\lnm2b_peerweights_`gvkey'_bottom`num'.tex)  columncount(10) paneltitles("Test firm" "Most comparable peers" "Least comparable peers" ) save(${results}\lnm2b_peerweights_`gvkey'_combined_temp.tex)
	
	filefilter ${results}\lnm2b_peerweights_`gvkey'_combined_temp.tex ${results}\lnm2b_peerweights_`gvkey'_combined.tex, from("999.00") to("n/a") replace
}	



