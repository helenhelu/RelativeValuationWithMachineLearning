* ----------------------------------------------------------------------------
* BenchmarkModelEstimation
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
* RRV summary statistics
*---------------------------------------------------------------------------

use RRVdata_${mrun}, clear

rename LEV LEV1
rename LEV_book LEV2
rename LEV_mkt LEV3
keep if !missing(lnm) &  !missing(lnb) &  !missing(lnni) &  !missing(negni) &  !missing(LEV1) &  !missing(LEV2) &  !missing(LEV3)
local thefile ${results}\\RRVsummarystats.csv
tempvar myfile
file open `myfile' using `thefile', write replace
foreach v in lnm lnb lnni negni LEV1 LEV2 LEV3 {
    local lab : var label `v'
	sum `v', detail
	file write `myfile' "`v'" "," "`lab'" "," "`r(N)'" "," "`r(mean)'" ","  "`r(sd)'" "," "`r(p1)'" "," "`r(p10)'" "," "`r(p50)'" "," "`r(p99)'"  "," "`r(p99)'"  _n
	
}
file close `myfile'

import delimited  ${results}\\RRVsummarystats.csv, clear
ren v1 Variable
ren v2 Description
ren v3 N
ren v4 Mean
ren v5 SD
ren v6 p1
ren v7 p10
ren v8 p50
ren v9 p90
ren v10 p99


foreach v in Variable {
	replace `v' = subinstr(`v',"&", "\&", .)
	replace `v' = subinstr(`v',"_", "\_", .)
	replace `v' = subinstr(`v',"%", "\%", .)
}

local varlist Variable  N Mean SD p1 p10 p50 p90 p99
local formatlist  %5s   %9.0fc %5.2fc  %5.2fc   %5.2fc  %5.2fc %5.2fc  %5.2fc  %5.2fc  
local alignlist  llrrrrrrr
data2tex_longtable `varlist' using ${results}\\${mrun}RRVsummarystats.tex, f(`formatlist') a(`alignlist') title(Summary statistics of variables used in RRV models) reference(MLsum) replace

*---------------------------------------------------------------------------
* RRV avg coefficiets, R2
*---------------------------------------------------------------------------

use RRVdata_${mrun}, clear

rename LEV LEV1
rename LEV_book LEV2
rename LEV_mkt LEV3
keep if !missing(lnm) &  !missing(lnb) &  !missing(lnni) &  !missing(negni) &  !missing(LEV1) &  !missing(LEV2) &  !missing(LEV3)

gen m = dofm(mth)
gen year = year(m) 

drop if missing(industry)
gen indmth = mth * 1000 + industry
tsset gvkeynum indmth

* describe variables (RRV)
describevariables lnm lnb lnni negni LEV1 LEV2 LEV3 using ${results}\\variables_used_RRV_${mrun}.tex, title(Rhodes-Kropf, Robinson and Viswanathan (2005)) reference(vardesc)

 
eststo clear
sort indmth
bysort indmth: asreg lnm lnb lnni negni LEV1, fmb newey(3) save(FirstStage)
eststo Model1

bysort industry indmth: asreg lnm lnb lnni negni LEV2, save(FirstStage) fmb  newey(3)
eststo Model2
bysort industry indmth: asreg lnm lnb lnni negni LEV3, save(FirstStage) fmb  newey(3)
eststo Model3
local thefile ${results}\RRV_coefficients_${mrun}.tex
* estout using `thefile',  notype starlevels (* 0.1 ** 0.05 *** 0.01) stardetach nonumbers collabels(none) stats(adjr2 N N_g, fmt(%9.2fc %9.0fc %9.0fc) labels("Avg. Adj. R2" "N of obs"  "N of models")) cells (b (star fmt(2)) t (par fmt(2))) labcol2( "ln(book equity)" "ln($ \sum_{t-3}^{t}NI_{t} $)" "$ \sum_{t-3}^{t}NI_{t} $ <= 0" "debt/total assets"  "1-book/total assets"  "1-market/(market+debt)", title("Descr."))  style(tex) substitute(_cons Const ) prehead(\begin{tabular} {l l *{@span}{r@{}l}} ) posthead("\hline") prefoot("\hline") postfoot(\hline\end{tabular}) replace 
estout using `thefile',  notype starlevels (* 0.1 ** 0.05 *** 0.01) stardetach nonumbers collabels(none)  stats(adjr2 N N_g, fmt(%9.2fc %9.0fc %9.0fc) labels("Avg. Adj. R2" "N of obs"  "N of models")) cells (b (star fmt(2)) t (par fmt(2)))  style(tex) substitute(_cons Const _ \_ ) prehead(\begin{tabular} {l *{@span}{r@{}l}} \hline) posthead("\hline") prefoot("\hline") postfoot(\hline\end{tabular}) replace 
					
*---------------------------------------------------------------------------
* BL summary statistics
*--------------------------------------------------------------------------

use BLdata_${mrun}, clear

reg m2b v2a v2s indm2b indv2a indv2s adjopmad negadjopmad adjsalesgrowth d2e pretret_noa_wr roe_wr  rd_sale_wr
gen incl = e(sample)

keep if incl == 1


local thefile ${results}\\BLsummarystats.csv
tempvar myfile
file open `myfile' using `thefile', write replace
foreach v in m2b v2a v2s indm2b indv2a indv2s adjopmad negadjopmad adjsalesgrowth d2e pretret_noa_wr roe_wr  rd_sale_wr {
    local lab : var label `v'
	sum `v', detail
	file write `myfile' "`v'" "," "`lab'" "," "`r(N)'" "," "`r(mean)'" ","  "`r(sd)'" "," "`r(p1)'" "," "`r(p10)'" "," "`r(p50)'" "," "`r(p99)'"  "," "`r(p99)'"  _n
	
}
file close `myfile'

import delimited  ${results}\\BLsummarystats.csv, clear
ren v1 Variable
ren v2 Description
ren v3 N
ren v4 Mean
ren v5 SD
ren v6 p1
ren v7 p10
ren v8 p50
ren v9 p90
ren v10 p99


foreach v in Variable {
	replace `v' = subinstr(`v',"&", "\&", .)
	replace `v' = subinstr(`v',"_", "\_", .)
	replace `v' = subinstr(`v',"%", "\%", .)
}

local varlist Variable  N       Mean SD        p1       p10     p50   p90  p99
local formatlist  %5s  %9.0fc %5.2fc  %5.2fc   %5.2fc  %5.2fc %5.2fc %5.2fc   %5.2fc   
local alignlist  llrrrrrrr
data2tex_longtable `varlist' using ${results}\\${mrun}BLsummarystats.tex, f(`formatlist') a(`alignlist') title(Summary statistics of variables used in BL models) reference(MLsum) replace

*---------------------------------------------------------------------------
* BL avg coefficiets, R2
*--------------------------------------------------------------------------

use BLdata_${mrun}, clear

capture drop incl2
reg m2b v2a v2s indm2b indv2a indv2s adjopmad negadjopmad adjsalesgrowth d2e pretret_noa_wr roe_wr  rd_sale_wr
gen incl2 = e(sample)

keep if incl2 == 1
local vars   indm2b indv2a indv2s adjopmad negadjopmad adjsalesgrowth d2e pretret_noa_wr roe_wr  rd_sale_wr
* make a list of variables used
describevariables m2b v2a v2s `vars' using ${results}\\variables_used_BL_${mrun}.tex, title(Bhojraj and Lee (2002)) reference(vardesc)
* require all RHS variables non-missing
gen incl1 = 0
gen incl = 1
foreach v in `vars' {
	replace incl1 =  !missing(`v')
	replace incl = incl * incl1
}
gen _fitted_new = 0 if  incl == 1 
drop if incl != 1
* (262,267 observations deleted)
* in-of-sample prediction

eststo clear
local thefile ${results}\BL_coefficients_${mrun}.tex
foreach v in m2b v2s v2a {
	bysort mth: asreg `v'  `vars', save(FirstStage)  fmb  newey(3)
	eststo `v'
}

* t-state below coefficient
estout using `thefile',  notype starlevels (* 0.1 ** 0.05 *** 0.01) stardetach nonumbers collabels(none) stats(adjr2 N N_g, fmt(%9.2fc %9.0fc %9.0fc) labels("Avg. Adj. R2" "N of obs"  "N of models")) cells (b (star fmt(2)) t (par fmt(2)))  style(tex) substitute(_cons Const _ \_ ) prehead(\begin{tabular} {l *{@span}{r@{}l}} \hline) posthead("\hline") prefoot("\hline") postfoot(\hline\end{tabular}) replace 

*---------------------------------------------------------------------------
* IA. Table  BG summary stats
*---------------------------------------------------------------------------
* BGdata from DataPrepv2
*------------------------------------------------------------------------------
use BGdata_${mrun}, clear

local bglist
foreach v in $bg_bsitems  $bg_cfitems  $bg_y2ditems {
	display "`v'"
	rename `v'_ac `v'
	local bglist  `bglist'  `v'
	display "`bglist'"
	* write label to notes
	local lbl : variable label `v'
	notes `v': `lbl'
}

* teqq is missing many values (200k vs 970k for other)
* as per WRDS balancing model, teqq = seqq + mibnq
replace teq = seq + cond(missing(mibn),0,mibn) if missing(teq)

gen incl1 = 0
gen incl = 1
* require all RHS variables non-missing
foreach v in `bglist' {
	replace incl1 =  !missing(`v')
	replace incl = incl * incl1
}

keep if incl == 1 & !missing(crsp_market_equity) & ${bg_datecutoff} 

local thefile ${results}\\BGsummarystats.csv
tempvar myfile
file open `myfile' using `thefile', write replace
foreach v in crsp_market_equity `bglist' {
    local lab : var label `v'
	sum `v', detail
	file write `myfile' "`v'" "," "`lab'" "," "`r(N)'" "," "`r(mean)'" ","  "`r(sd)'" "," "`r(p1)'" "," "`r(p10)'" "," "`r(p50)'" "," "`r(p99)'"  "," "`r(p99)'"  _n
	
}
file close `myfile'

import delimited  ${results}\\BGsummarystats.csv, clear
ren v1 Variable
ren v2 Description
ren v3 N
ren v4 Mean
ren v5 SD
ren v6 p1
ren v7 p10
ren v8 p50
ren v9 p90
ren v10 p99


foreach v in Variable {
	replace `v' = subinstr(`v',"&", "\&", .)
	replace `v' = subinstr(`v',"_", "\_", .)
	replace `v' = subinstr(`v',"%", "\%", .)
}

local varlist Variable  N       Mean SD        p1       p10     p50   p90  p99
local formatlist  %5s  %9.0fc %5.2fc  %5.2fc   %5.2fc  %5.2fc %5.2fc %5.2fc   %5.2fc   
local alignlist  llrrrrrrr
data2tex_longtable `varlist' using ${results}\\${mrun}BGsummarystats.tex, f(`formatlist') a(`alignlist') title(Summary statistics of variables used in BG models) reference(MLsum) replace

*---------------------------------------------------------------------------
* BG avg coefficiets, R2
*---------------------------------------------------------------------------

use BGdata_${mrun}, clear

gen value_true = m2b * book
* variables used in Bartram and Grinblat (2018)
* from DataPrev2
* list defined as global var in _runall
* See appendix B, 145
local bglist
foreach v in $bg_bsitems  $bg_cfitems  $bg_y2ditems {
	display "`v'"
	rename `v'_ac `v'
	local bglist  `bglist'  `v'
	display "`bglist'"
	* write label to notes
	local lbl : variable label `v'
	notes `v': `lbl'
}

* describe variables (BG)
describevariables `bglist' using ${results}\\variables_used_BG_${mrun}.tex, title(Bartram and Grinblatt (2018)) reference(vardesc)


* teqq is missing many values (200k vs 970k for other)
* as per WRDS balancing model, teqq = seqq + mibnq
replace teq = seq + cond(missing(mibn),0,mibn_ac) if missing(teq)

su `bglist'
* smallest non-missing is lcoq = 855162

keep mth permco gvkeynum  crsp_market_equity  `bglist' hash100 value_true

* require all RHS variables non-missing
gen incl1 = 0
gen incl = 1
foreach v in `bglist' {
	replace incl1 =  !missing(`v')
	replace incl = incl * incl1
}
gen _fitted_new = 0 if  incl == 1 
drop if incl != 1
* (262,267 observations deleted)
* in-of-sample prediction

eststo clear
bysort mth: asreg crsp_market_equity `bglist' if ${bg_datecutoff} , save(FirstStage)  fmb  newey(3)
eststo Estimates


local thefile ${results}\BG_coefficients_${mrun}.tex

estout  using `thefile',  notype starlevels (* 0.1 ** 0.05 *** 0.01) stardetach nonumbers collabels("Coeff." "$ t $-stat") stats(adjr2 N N_g,  fmt(%9.2fc %9.0fc %9.0fc) labels("Avg. Adj. R2" "N of obs"  "N of models")) cells ("b (star fmt(2)) t (par fmt(2))")  style(tex) substitute(_cons Const _ \_ ) prehead(\begin{tabular} {l  *{@span}{r@{}l}}  \hline) posthead("\hline") prefoot("\hline") postfoot(\hline\end{tabular}) replace 

