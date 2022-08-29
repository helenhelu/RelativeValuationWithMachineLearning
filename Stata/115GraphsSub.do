* ----------------------------------------------------------------------------
* GraphsSub
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

local sort_vars size m2b roe

* create terciles for sorting variables

foreach target in m2b v2a v2s {
	foreach sv in `sort_vars' {
		
		use combined_full_${mrun}, clear

		* drop dummy observations (used in ML code)
		drop if hash100 == 100

		* selected sorting variables
		gen size = m
		gen roe = profitability_an
		
		sort mth
		gquantiles quintile_`sv' = `sv', xtile by(mth) nq(5)
		
		gcollapse (median) abserr* , by(quintile_`sv') fast
		
		tsset quintile_`sv'
		
		* Targeted model comparison
		local vars ML_ln`target' IND_`target' BL_`target' HP_`target'
		local plotvars
		foreach v in `vars' {
			local plotvars `plotvars' abserr_`v'
			la var abserr_`v' "`v'"
		}
		
		line `plotvars' quintile_`sv', xtitle("Quintiles of `sv'") ytitle("Median absolute percentage valuation error", height(7)) ylabel(#5)    lpattern(solid shortdash longdash_dot longdash dash_dot dot) lcolor(black navy dkgreen maroon gs7 cranberry)  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white))) 
		
		graph export ${results}\\Graph_abserr_subsample_`sv'_`target'_comp_${mrun}.pdf, replace
		
		
		* RRV and BG comparison
		local vars ML_ln`target' RRV BG
		local plotvars
		foreach v in `vars' {
			local plotvars `plotvars' abserr_`v'
			la var abserr_`v' "`v'"
		}
		
		line `plotvars' quintile_`sv', xtitle("Quintiles of `sv'") ytitle("Median absolute percentage valuation error", height(5)) ylabel(#5)    lpattern(solid shortdash longdash_dot longdash dash_dot dot) lcolor(black navy dkgreen maroon gs7 cranberry)  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white))) 
		
		graph export ${results}\\Graph_abserr_subsample_`sv'_`target'_RRV_BG_${mrun}.pdf, replace

		
	}	

}




* by quintile: alt models vs ML_lnm2b
local sort_vars size m2b roe
foreach sv in `sort_vars' {
	
	use combined_full_${mrun}, clear

	* drop dummy observations (used in ML code)
	drop if hash100 == 100

	* selected sorting variables
	gen size = m
	gen roe = profitability_an
	
	sort mth
	gquantiles quintile_`sv' = `sv', xtile by(mth) nq(5)
	
	gcollapse (median) abserr* , by(quintile_`sv') fast
	
	tsset quintile_`sv'
	
	* Targeted model comparison
	local vars ML_lnm2b ML_m2b ML_lnm ML_m
	local plotvars
	foreach v in `vars' {
		local plotvars `plotvars' abserr_`v'
		la var abserr_`v' "`v'"
	}
	
	line `plotvars' quintile_`sv', xtitle("Quintiles of `sv'") ytitle("Median absolute percentage valuation error", height(5)) ylabel(#5)    lpattern(solid shortdash longdash_dot longdash dash_dot dot) lcolor(black navy dkgreen maroon gs7 cranberry)  graphregion(color(white)) plotregion(color(white))  legend(size(medium) rows(1) region(lcolor(white))) 
	
	graph export ${results}\\Graph_abserr_subsample_`sv'_altMLtargets_comp_${mrun}.pdf, replace
	
}	



