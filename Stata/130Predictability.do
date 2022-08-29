* ----------------------------------------------------------------------------
* Predictability
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
* One-month ahead predictability  MLlnm2b MLlnv2s  RRVcs INDm2bhm BG RRVcs BLm2b EW VW
*---------------------------------------------------------------------------

* Portfolio Strategy profitability
use combined_full_${mrun}, clear

* generate errors from different models for portfolio sortin
local errlist ""
foreach v in $models_main {
    local errlist `errlist' err_`v'
}
	
* correlation matrix
estpost correlate `errlist' , matrix listwise
esttab using ${results}\${mrun}_firmmth_error_corr.tex, unstack not noobs compress tex replace

save temp1, replace

use crsp_permno_returns, clear
merge 1:m permno mth using temp1, keep(master match) nogen

duplicates tag permno mth, gen(rep)
*different gvkeys matched on the same permno during transitary month
drop rep

* NYSE 20% smallest firms
merge m:1 mth using ${source}\nysebreaks, nogen keep(master match) keepusing(value_bp2)

save strategies_${mrun}, replace

* Benchmark model errors and return predictability
	
foreach w in ew vw {
	foreach smodel in mean ff6 gl_ff6 {
		eststo clear
		foreach model in $models_main  {

			local portfolios 5
			use strategies_${mrun}, clear

			if 0 {
				local w ew
				local smodel mean
				local model ML_lnm2b
			}
			
			
		
			if "`w'" == "ew" {
			    * not missing equity value or NYSE breakpoints
				keep if !missing(value_bp2) & !missing(value)
				count

				* equity value above 20th percentile of NYSE stocks
				keep if (value >= value_bp2)
				count
				
				*quantiles err_`model', by(mth) nq(`portfolios') gen(p)
				local nysefilter       ( (shrcd == 10 | shrcd == 11) & (exchcd == 1) )
				local populationfilter ( (shrcd == 10 | shrcd == 11) )
				breakquantiles err_`model', by(mth) nq(`portfolios') break("`nysefilter'") pop("`populationfilter'") gen(p) 
				local ret freturn
				constructportfolio `ret', s(p) by(mth)			
			}
			else if "`w'" == "vw" {
			    
				* not missing equity value or NYSE breakpoints
				keep if !missing(value_bp2) & !missing(value)
				count
				
				local nysefilter       ( (shrcd == 10 | shrcd == 11) & (exchcd == 1) )
				local populationfilter ( (shrcd == 10 | shrcd == 11) )
				breakquantiles err_`model', by(mth) nq(`portfolios') break("`nysefilter'") pop("`populationfilter'") gen(p) 
				local ret freturn
				constructportfolio `ret', s(p) by(mth) weight(value)
			}


			ren `ret'* P*
			capture drop P0
			gen P`portfolios'm1 = P`portfolios'-P1
			
			* current month is month of predictor availability
			ren mth mth_predictor
			gen mth = mth_predictor + 1
			* anomalies are aligned to month of anomaly return
			merge 1:1 mth using ${source}\\anomalystrategies_clusters, keep(master match) nogen
			sort mth
			tsset mth
			
			foreach v in Accruals STReversal MarginGrowth epsconsistency ExternalFinance seasonality {
				rename `v'_hp `v'
			}
			
			* set control variables to empty
			local control
			
			* enforce same sample for both models (benchmark is FF6)
			qui  ivreg2 P5m1 MKTRF SMB HML RMW CMA UMD, bw(3)
			qui capture gen sample = e(sample)
					
			if "`smodel'" == "ff6" {
				local control MKTRF SMB HML RMW CMA UMD
			}
			else if "`smodel'" == "gl_ff6" {
				local control MKTRF SMB HML RMW CMA UMD EG Accruals STReversal MarginGrowth epsconsistency ExternalFinance seasonality
			}
			else if "`smodel'" == "mean" {
				* no control - just estimate mean
				local control
			}
			else {
				* should not happen
				di "ERROR: unknown smodel in Predictability.do, exiting"
				exit
			}
			
			* perform time-series regression with consistent sample accross models
			ivreg2 P`portfolios'm1 `control' if sample == 1, bw(3)

			local alpha = _b[_cons]
			
			* information ratio = E[tracking error]/SD(tracking error)
			*---------------------------------------------------------			
			
			* need benchmark predictions for information ratio
			predict P`portfolios'm1_hat if sample == 1
			
			* substract alpha from predicted (which includes alpha) to get expected (only sum of factor loadings x factor premia)
			gen P`portfolios'm1_expected = P`portfolios'm1_hat - `alpha'
			* for mean, store Sharpe ratio
			
			gen tracking_error = P`portfolios'm1 - P`portfolios'm1_expected
			su tracking_error
			local te_mean = r(mean)
			local te_var = r(Var)
			local IR_annualised = ((1+`te_mean')^12 - 1) / sqrt((`te_var'*12))
			di "IRR annualised = `IR_annualised'"
			
			* Sharpe ratio = E[excess returns]/SD[excess returns]
			*---------------------------------------------------------				
			
			* note, hedge portfolio returns are already excess returns 
			su P`portfolios'm1
			local er_mean = r(mean)
			local er_var = r(Var)
			local SR_annualised = ((1+`er_mean')^12 - 1) / sqrt((`er_var'*12))
			* store estimated model, including SR and IR
			eststo `model', add(IR `IR_annualised' SR `SR_annualised', replace)
			
		}
		
		local thefile ${results}\retpred_`smodel'_`w'_${mrun}.tex
		
		if "`smodel'" == "ff6" | "`smodel'" == "gl_ff6"{
			
			estout using `thefile',  notype starlevels (* 0.1 ** 0.05 *** 0.01) stardetach nonumbers collabels(none) stats(r2_a IR, fmt( %5.2fc  %5.2fc) labels("Adj. $ R^2 $" "Information Ratio")) cells (b (star fmt(2))) style(tex) substitute(_cons Const _ \_) prehead(\begin{tabular} {l *{@E}{r@{}l}} ) posthead("\hline") prefoot("\hline") postfoot(\hline\end{tabular}) transform(_cons @*100 @) replace 
			
		}
		else if "`smodel'" == "mean"  {
			
			estout using `thefile',  notype starlevels (* 0.1 ** 0.05 *** 0.01) stardetach nonumbers collabels(none) stats(SR, fmt(%5.2fc) labels("Sharpe Ratio"))  cells (b (star fmt(2))) style(tex) substitute(_cons Const _ \_) prehead(\begin{tabular} {l *{@E}{r@{}l}} ) posthead("\hline") prefoot("\hline") postfoot(\hline\end{tabular}) transform(_cons @*100 @) replace 
			
		}	
		
		
	}			
}	

* combine panels into one table
foreach w in ew vw {
	panelcombine, use(${results}\retpred_mean_`w'_${mrun}.tex  ${results}\retpred_ff6_`w'_${mrun}.tex ${results}\retpred_gl_ff6_`w'_${mrun}.tex)  columncount(7) paneltitles("Mean" "FF6" "FF6 + 7 clusters of anomalies") save(${results}\retpred_combined_`w'_${mrun}.tex)
}	



