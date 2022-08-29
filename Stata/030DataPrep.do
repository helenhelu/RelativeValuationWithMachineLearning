* ----------------------------------------------------------------------------
* DataPrep
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


timer clear
timer on 1
*----------------------------------------------------------------------------------------------------------
* (1) process and clean all (rolling four-month data, filling in missing quarterly from year-to-date data)
*----------------------------------------------------------------------------------------------------------
*------------------------------------------------------------------------------
* Variable lists
*------------------------------------------------------------------------------

* everything needed for wrds ratios, Bartram and Greenblatt
* list of non-accounting variables to keep
local keeplist gvkey permno permco datadate mth acc_mth fyear year sicn compustat_equity_value debt_book_value industry  be 

* balance sheet
local bsitems act che rect invt aco ppent alt ao at lct dlc ap txp lco llt dltt txditc lo lt pstk ceq be icapt mib seq teq pstkr mibn txdb

* income statement & cashflow (these include vars needed for BG)
* isitems include isitems and y2ditems (two categories because they need to be dealt with differently)
* later fill in missing isitems from their y2d items
* y2ditems only has y2d vars, quarterly data need to be generted from them

local isitems sale cogs gp xsga ebitda ebit ebt dp  xint  nopi spi pi txt ibmii mii ib dvp ibcom cstke ibadj xido ni xrd capx do revt ibc dpc xopr oancf 

local isinputs sale cogs gp xsga ebitda ebit ebt dp xint nopi spi pi txt ibmii mii ib dvp ibcom cstke ibadj xido ni xrd capx do revt   xopr      

local y2ditems ibc dpc oancf

*------------------------------------------------------------------------------
* Compustat quarterly
*------------------------------------------------------------------------------

use ${source}\\compustatq_notccm_processed, clear

gsort gvkey mth -at -saleq -bookequityq permno
duplicates drop gvkey mth, force
* 10 dropped

* rename to easier to understand nmemonics
ren oibdpq ebitdaq
ren oiadpq ebitq
ren oibdpy ebitday
ren oiadpy ebity

* total long-term assets / liabilities
gen altq = (atq - actq)
la var altq "Long-term assets (=at-act)"

*gen lltq = (ltq - lctq)
la var lltq "Long-term liabilities (=lt-lct)"

* If preferred stock is missing, replace with sum of redeemable and non-redeemable preferred stock
replace pstkq = cond(missing(pstknq), 0, pstknq) + cond(missing(pstkrq), 0, pstkrq) if missing(pstkq)

* Book equity (preferred shares treated as liabilities, not equity)
gen beq = bookequityq 
la var beq "Book equity as per Davis Fama French (2000)"

* Gross profit
gen gpq = saleq - cogsq
la var gpq "Gross Profit (=sale-cogs)"
gen gpy = saley - cogsy

* Earnings before tax
gen ebtq = ebitq - xintq
la var ebtq "Earnings before tax (=ebit-xint)"
gen ebty = ebity - xinty

* ibmiiq is only around 10% populated, even though piq and txtq has good coverage
replace ibmiiq = piq - txtq if missing(ibmiiq)
replace ibmiiy = piy - txty if missing(ibmiiy)

* recreate quarterly capx
sort gvkey datadate
gen     capxq = capxy if fqtr == 1
replace capxq = capxy - capxy[_n-1] if fqtr > 1 & gvkey == gvkey[_n-1]
la var  capxq "Capital Expenditure"

local keepers 
foreach v in `isitems' `bsitems' {
	local keepers `keepers' `v'q
}

local ykeepers
foreach v in `isinputs' `y2ditems' {
	local ykeepers `ykeepers' `v'y
}

*------------------------------------------------------------------------------
* Augment missing quarterly income statement data with year-to-date totals
*------------------------------------------------------------------------------

sort gvkey datadate

* these variables already exist, so we replace them if missing

foreach v in `isinputs' {
	qui gen     `v'temp = `v'y if fqtr == 1
	qui replace `v'temp = `v'y - `v'y[_n-1] if fqtr > 1 & gvkey == gvkey[_n-1]
	qui replace `v'q = `v'temp if missing(`v'q)
	qui drop    `v'temp
}

*------------------------------------------------------------------------------
* Generating quarterly from cash flow y2d data
*------------------------------------------------------------------------------

* these variables do not exist, so we create them
sort gvkey mth
foreach v in $bg_cfitems `y2ditems' {
	display "`v'"
	capture drop  `v'temp
	qui gen     `v'temp = `v'y if fqtr == 1
	qui replace `v'temp = `v'y - `v'y[_n-1] if fqtr > 1 & gvkey == gvkey[_n-1]
	capture drop `v'q
	qui gen `v'q = `v'temp 
	qui drop    `v'temp
}

* rename to annual equivalent

foreach v in `bsitems' `isitems' $bg_cfitems  {
	capture drop `v'_orig
	qui gen `v'_orig = `v'q
	capture drop `v'
	qui ren `v'q `v'
	
}

*------------------------------------------------------------------------------
* Flow variables based on 4 quarters
*------------------------------------------------------------------------------

sort gvkey mth
foreach v in `isitems'  $bg_cfitems  {
	capture drop `v'_ae
	by gvkey: gen `v'_ae = cond(missing(`v'),0,`v') + cond(missing(`v'[_n-1]),0,`v'[_n-1]) + cond(missing(`v'[_n-2]),0,`v'[_n-2]) + cond(missing(`v'[_n-3]),0,`v'[_n-3])
	local lbl : variable label `v'
	label var `v'_ae `"`lbl'"'  
	qui drop `v'
	qui ren `v'_ae `v'
}

la var dv "cash dividend"

*------------------------------------------------------------------------------
* Equity value and debt value
*------------------------------------------------------------------------------


sort gvkey mth
tsset gvkey mth

* common sense transforms
replace at = . if at <= 0
replace sale = . if sale <= 0

la var sicn "SIC code (numeric)"

* market value of equity and book value of debt; needed to calculate firm value
gen compustat_equity_value = prccq * cshoq
replace compustat_equity_value = . if compustat_equity_value < 0
la var compustat_equity_value "Compustat equity value at accounting date in millions (not deflated)"

* use book value of debt since market value of debt not known for bank loans / non-traded bonds
egen debt_book_value = rowtotal(dltt dlc pstk)
replace debt_book_value = . if debt_book_value < 0
la var debt_book_value "Book value of debt"
notes debt_book_value : Book value of debt (rowtotal(dltt dlc pstk)) in millions
notes debt_book_value : Size

*------------------------------------------------------------------------------
* Fama - French Industry classification (49 industries)
*------------------------------------------------------------------------------

merge m:1 sicn using ${source}\\sic2ff49map, keep(master match) keepusing(ff49) nogen
ren ff49 industry
la var industry "Fama French 49 industries"
sort gvkey mth

*------------------------------------------------------------------------------
* Lags and differences
*------------------------------------------------------------------------------

local all_acc_vars `bsitems' `isitems' $bg_cfitems

sort gvkey mth

local all_lag_vars

foreach v in `all_acc_vars' {
	
	* note, still at quarterly frequency. want lags and diffs at annual frequency, so use _n-4
	qui by gvkey: gen l_`v' = `v'[_n-4] if gvkey == gvkey[_n-4] 
	
	local lbl : variable label `v'
	label var l_`v' `"`lbl' (lagged)"'  
	
	qui by gvkey: gen d_`v' = `v' - `v'[_n-4] if gvkey == gvkey[_n-4]
	label var d_`v' `"`lbl' (difference)"' 

	local all_lag_vars `all_lag_vars' l_`v' d_`v'
}

*------------------------------------------------------------------------------
* Count missing variables
*------------------------------------------------------------------------------

local all_vars `all_acc_vars' `all_lag_vars'

di "keep `keeplist' `all_vars'"
keep `keeplist' `all_vars' 

count
* 1,816,831
save compustat_cleaned, replace

*------------------------------------------------------------------------
* (2) calculate WRDS ratios
*-----------------------------------------------------------------------
*------------------------------------------------------------------------------
* Calculated metrics and ratios (following WRDS ratio suite)
*------------------------------------------------------------------------------

* NOTE: Must try and calculate everything using only the variables available
* hence the calcutions won't follow WRDS exactly. It is defined as it is coded!
* roughly a SAS-to-Stata conversion of the WRDS ratio suite code 
* https://wrds-www.wharton.upenn.edu/pages/support/manuals-and-overviews/wrds-financial-ratios/financial-ratios-sas-code/

* NB: rely on 3 preconditions
* 1) data is ts-filled monthly
* 2) data is sorted by gvkey mth
* 3) all accounting data is non-missing

* Note: use ebit in place of oiadp, better coverage and the same when both not missing

use compustat_cleaned, clear
sort gvkey mth

* Invested Capital and Operating Cash Flow*
* WRDS ratio SAS code: icapt=coalesce(icapt,sum(dltt,pstk,mib,ceq))
egen icapt_temp = rowtotal(dltt pstk mib ceq), missing
replace icapt = icapt_temp if missing(icapt)
drop icapt_temp
* (393,041 real changes made)
egen icapt_temp = rowtotal(l_dltt l_pstk l_mib l_ceq), missing
replace l_icapt = icapt_temp if missing(l_icapt)
* (363,029 real changes made)
drop icapt_temp

* SAS code: ocf=coalesce(oancf,ib-sum(dif(act),-dif(che),-dif(lct),dif(dlc),dif(txp),-dp))
gen ocf = oancf 
gen nd_che = -d_che
gen nd_lct = -d_lct
gen ndp = -dp
egen ocf_temp = rowtotal(d_act nd_che nd_lct  d_dlc  d_txp ndp), missing
replace ocf = ib - ocf_temp if missing(ocf)
*(0 real changes made)
drop nd_che nd_lct ndp ocf_temp
	
gen noa =  (ppent + act - lct)
la var noa "Net Operating Assets"
notes noa: Net Operating Assets: ppent+act-lct

* access notes by notes _fetch localvarname: varname #
* notes _fetch noanote: noa 1
* fetch the first note of noa to noanote

gen earnat =  (ppent+act)
la var earnat "Total Earning Assets"
notes earnat: Total Earning Assets: ppent+act

gen totdebt = (dltt + dlc) 
la var totdebt "Total Debt"
notes totdebt:  Total Debt: dltt+dlc
	
*-----------------------------------------------
*Capitalisation Ratios 
*-----------------------------------------------

egen temp1 = rowtotal(ceq pstk), missing
gen capital_ratio_wr =dltt/(dltt+temp1)
drop temp1
la var capital_ratio_wr "Capitalisation Ratio"
notes capital_ratio_wr: Capitalisation Ratio: dltt/(dltt+sum(ceq, pstk))
notes capital_ratio_wr: Capitalisation


gen equity_invcap_wr = ceq / icapt if icapt > 0 
la var equity_invcap_wr "Common Equity/Invested Capital"
notes equity_invcap_wr: Common Equity/Invested Capital: ceq/icapt if icapt > 0
notes equity_invcap_wr: Capitalisation
	     
gen debt_invcap_wr =dltt/icapt if icapt > 0 
la var debt_invcap_wr "Long-term Debt/Invested Capital"	 
notes debt_invcap_wr: Long-term Debt/Invested Capital: dltt/icapt if icapt > 0 
notes debt_invcap_wr: Capitalisation

gen totdebt_invcap_wr = (dltt+dlc)/icapt if icapt > 0 
la var totdebt_invcap_wr "Total Debt/Invested Capital"
notes totdebt_invcap_wr: Total Debt/Invested Capital: (dltt+dlc)/icapt if icapt > 0
notes totdebt_invcap_wr: Capitalisation

*-----------------------------------------------
*Efficiency Ratios
*-----------------------------------------------

gen at_turn_wr = sale/at if at > 0
replace at_turn_wr = revt/at if at > 0 & at_turn_wr == .
la var at_turn_wr "Asset Turnover"
notes at_turn_wr: Asset Turnover: sale/at
notes at_turn_wr: Efficiency

gen invturn_wr = cogs/((invt + l_invt)/2) if (invt + l_invt)/2 > 0
la var invturn_wr "Inventory Turnover"
notes  invturn_wr : Inventory Turnover: cogs/((invt+l_invt)/2) if (invt + l_invt)/2>0
notes  invturn_wr : Efficiency                 

gen pay_turn_wr = (cogs + d_invt)/((ap + l_ap)/2) if (ap + l_ap)/2>0
la var pay_turn_wr "Payables Turnover"
notes pay_turn_wr: Payables Turnover: (cogs+d_invt)/((ap+l_ap)/2) if (ap+l_ap)/2>0
notes pay_turn_wr:  Efficiency  

gen rect_turn_wr = sale/((rect + l_rect)/2) if (rect + l_rect)/2 > 0
la var rect_turn_wr "Receivables Turnover"
notes  rect_turn_wr : Receivables Turnover: sale/((rect+l_rect)/2)
notes  rect_turn_wr : Efficiency

*-----------------------------------------------
*Financial Soundness Ratios
*-----------------------------------------------

gen invt_act_wr = invt / act
la var invt_act_wr "Inventory/Current Assets"
notes  invt_act_wr : Inventory/Current Assets: invt/act
notes  invt_act_wr : Financial soundness

gen rect_act_wr = rect/act
la var rect_act_wr "Receivables/Current Assets"
notes rect_act_wr : Receivables/Current Assets: rect/act
notes rect_act_wr : Financial soundness

gen fcf_ocf_wr = (ocf-capx)/ocf if ocf>0
la var fcf_ocf_wr "Free Cash Flow/Operating Cash Flow"
notes  fcf_ocf_wr : Free Cash Flow/Operating Cash Flow: (ocf-capx)/ocf if ocf>0
notes  fcf_ocf_wr : Financial soundness

gen ocf_lct_wr=ocf/lct
la var ocf_lct_wr "Operating  Cash Flow/Current Liabilities"
notes  ocf_lct_wr : Operating  Cash Flow/Current Liabilities: ocf/lct
notes  ocf_lct_wr : Financial soundness

*cash_debt_wr=ocf/coalesce(lt,dltt+dlc)
gen temp1 = dltt + dlc
egen temp2 = rowfirst(lt temp1)
gen cash_debt_wr=ocf/temp2
drop temp1 temp2
la var cash_debt_wr "Cash Flow/Total Debt"
notes  cash_debt_wr: Cash Flow/Total Debt: ocf/lt
notes  cash_debt_wr : Financial soundness

gen cash_lt_wr = che/lt
la var cash_lt_wr "Cash Balance/Total Liabilities"
notes  cash_lt_wr : Cash Balance/Total Liabilities: che/lt
notes  cash_lt_wr  : Financial soundness

*cfm=coalesce(ibc+dpc,ib+dp)/sale
gen cfm_wr = (ib + dp)/sale
replace cfm_wr = (ibc+dpc)/sale if missing(cfm_wr)
la var cfm_wr "Cash Flow Margin"
notes cfm_wr : Cash Flow Margin: (ib+dp)/sale
notes cfm_wr : Profitability

gen short_debt_wr =dlc/(dltt+dlc)
la var short_debt_wr "Short-term Debt/Total Debt"
notes short_debt_wr : Short-Term Debt/Total Debt: dlc/(dltt+dlc)
notes short_debt_wr : Financial soundness 

gen temp1 = sale - xopr
egen temp2 = rowfirst(ebitda temp1)
gen profit_lct_wr = temp2/lct
drop temp1 temp2
la var profit_lct_wr "EBITDA/Current Liabilities"
notes profit_lct_wr : EBITDA/Current liabilities: ebitda/lct
notes profit_lct_wr : Financial soundness 

gen curr_debt_wr=lct/lt
la var curr_debt_wr "Current Liabilities/Total Liabilities"
notes curr_debt_wr : Current Liabilities/Total Liabilities: lct/lt
notes curr_debt_wr : Financial soundness 

*debt_ebitda=(dltt+dlc)/coalesce(ebitda,oibdp,sale-cogs-xsga)
gen temp1 = sale-cogs-xsga
egen temp2 = rowfirst(ebitda temp1)
gen debt_ebitda_wr = (dltt+dlc)/temp2
drop temp1 temp2
la var debt_ebitda_wr "Total Debt/EBITDA"
notes debt_ebitda_wr : Total Debt/EBITDA: (dltt+dlc)/ebitda
notes debt_ebitda_wr : Financial soundness 

gen dltt_be_wr = dltt/be if be>0
la var dltt_be_wr "Long-term Debt to Equity"
notes dltt_be_wr: Long-term Debt to Equity: dltt/be if be>0
notes dltt_be_wr : Financial soundness

gen int_debt_wr = xint/dltt 
la var int_debt_wr "Interest/Long-term Debt"
notes int_debt_wr : Interest/Long-term Debt: xint/dltt
notes int_debt_wr  : Financial soundness

gen int_totdebt_wr = xint/totdebt
la var int_totdebt_wr "Interest/Total Debt"
notes int_totdebt_wr : Interest/Total Debt : xint/((dltt + dlc)
notes int_totdebt_wr  : Financial soundness

gen lt_debt_wr=dltt/lt
la var lt_debt_wr "Long-term Debt/Total Liabilities"
notes lt_debt_wr : Long-term Debt/Total Liabilities: dltt/lt
notes lt_debt_wr  : Financial soundness

gen lt_ppent_wr=lt/ppent
la var lt_ppent_wr "Total Liabilities/PP&E"
notes lt_ppent_wr : Total Liabilities/PP&E: lt/ppent
notes lt_ppent_wr   : Financial soundness

*-----------------------------------------
* Liquidity Ratios
*-----------------------------------------

gen cash_conversion_wr = (invt+l_invt)/2/(cogs/365)+(rect+l_rect)/2/(sale/365)-(ap+l_ap)/2/(cogs/365)
la var cash_conversion_wr "Cash Conversion Cycle (Days)"
notes cash_conversion_wr : Cash Conversion Cycle (Days): (invt+l_invt)/2/(cogs/365)+(rect+l_rect)/2/(sale/365)-(ap+l_ap)/2/(cogs/365)
notes cash_conversion_wr : Liquidity

gen cash_ratio_wr=che/lct if lct>0
la var cash_ratio_wr "Cash Ratio"
notes cash_ratio_wr: Cash Ratio: che/lct if lct>0
notes cash_ratio_wr : Liquidity

*curr_ratio=coalesce(act,che+rect+invt)/LCT
gen temp1 = che+rect+invt
egen temp2 = rowfirst(act temp1)
gen curr_ratio_wr = temp2/lct if lct>0 
drop temp1 temp2  
la var curr_ratio_wr "Current Ratio"
notes curr_ratio_wr : Current Ratio: act/lct 
notes curr_ratio_wr : Liquidity

*quick_ratio=coalesce(act-invt, che+rect)/lct
gen quick_ratio_wr = (act-invt)/lct if lct>0
replace quick_ratio_wr = (che+rect)/lct if missing(quick_ratio_wr)
la var quick_ratio_wr "Quick Ratio"
notes quick_ratio_wr : Quick Ratio: (act-invt)/lct if lct>0
notes quick_ratio_wr  : Liquidity

*-----------------------------------------
* Other Ratios
*-----------------------------------------

* accrual = coalesce(oancf-ib,-sum(dif(act),-dif(che),-dif(lct),dif(dlc),dif(txp),-dp))/mean(AT,lag(AT))

gen temp1 = oancf-ib
gen nd_che = -d_che
gen nd_lct = -d_lct+d_dlc
gen ndp = -dp 
egen temp2 = rowtotal(d_act nd_che nd_lct d_dlc d_txp ndp), missing
gen temp3 = -temp2
egen temp4 = rowfirst(temp1 temp3)
gen Accrual_wr = temp4/at
drop temp1 temp2 temp3 temp4
la var Accrual_wr "Accruals/Total Assets"
notes Accrual_wr : Accruals/Total Assets: (oancf-ib)/at

* rd_sale=sum(xrd,0)/sale; if rd_sale<0 then rd_sale=0; /*R&D as % of sales*/
gen rd_sale_wr = max(cond(missing(xrd),0,xrd/sale),0)
la var rd_sale_wr "R&D/Sales"
notes rd_sale_wr : R&D/Sales: max(xrd/sale,0), missing xrd replaced with zero
notes rd_sale_wr : Growth

*----------------------------------------*
*Profitability Ratios 
*----------------------------------------*

* if coalesce(pi,oiadp-xint+spi+nopi)>0 then efftax=txt/coalesce(pi,oiadp-xint+spi+nopi)

gen efftax_wr = txt/(ebit - xint + spi + nopi) if (ebit - xint + spi + nopi) > 0 & !missing(ebit - xint + spi + nopi)
replace efftax_wr = txt/pi if pi>0 & !missing(pi) & missing(efftax_wr)
la var efftax_wr "Effective Tax Rate"
notes efftax_wr : Effective Tax Rate: txt/pi
notes efftax_wr : Profitability
    
*GProf=coalesce(gp,revt-cogs,sale-cogs)/at

gen temp1 = revt - cogs-xsga-dp
gen temp2 = sale - cogs
egen temp3 = rowfirst(gp temp1 temp2)
gen gprof_wr  = temp3/at
drop temp1 temp2 temp3
la var gprof_wr "Gross Profit/Total Assets"	
notes gprof_wr: Gross Profit/Total Assets: (sale-cogs)/at	
notes gprof_wr : Profitability

*aftret_eq=coalesce(ibcom,ib-dvp)/((ceq+lag(ceq))/2)

gen aftret_eq_wr = ibcom/ ceq 
replace aftret_eq_wr = (ib - dvp) / ceq if missing(aftret_eq)
la var aftret_eq_wr "After-tax Return on  Common Equity"
notes aftret_eq_wr : After-tax Return on  Common Equity: ibcom/ceq
notes aftret_eq_wr: Profitability
*after tax return on total stock holder's equity

gen aftret_equity_wr=ib/ seq
la var aftret_equity_wr "After-tax Return on Stockholders' Equity"
notes aftret_equity_wr : After-tax Return on Stockholders' Equity: ib/seq
notes aftret_equity_wr : Profitability
* if sum(icapt,TXDITC,-mib)>0 then aftret_invcapx=sum(ib+xint,mii)/lag(sum(icapt,TXDITC,-mib))

gen temp1 = ib + xint 
egen temp2 = rowtotal(temp1 mii), missing
gen l_nmib = -l_mib
egen temp3 = rowtotal(l_icapt l_txditc l_nmib), missing
gen aftret_invcapx_wr = temp2 / temp3 if temp3 > 0 
drop temp1 temp2 temp3 l_nmib
la var aftret_invcapx_wr "After-tax Return on Invested Capital"
notes aftret_invcapx_wr : After-tax Return on Invested Capital: sum(ib+xint,mii)/sum(l_icapt,l_txditc,-l_mib), for postive denominator only
notes aftret_invcapx_wr  : Profitability	

*gpm=coalesce(gp,revt-cogs,sale-cogs)/sale

gen gpm_wr = gp / sale
replace gpm_wr = (sale - cogs) / sale if missing(gpm_wr)
la var gpm_wr "Gross Profit Margin"
notes gpm_wr : Gross Profit Margin: (sale-cogs)/sale
notes gpm_wr : Profitability
*net profit margin*
gen npm_wr =ib/sale  
la var npm_wr "Net Profit Margin"
notes npm_wr : Net Profit Margin: ib/sale
notes npm_wr :  Profitability

*opmbd=coalesce(oibdp,sale-xopr,revt-xopr)/sale

gen opmbd_wr= ebitda /sale
replace opmbd_wr = (sale-xopr) / sale if missing(opmbd_wr)
replace opmbd_wr = (revt-xopr) / sale if missing(opmbd_wr)
la var opmbd_wr "EBITDA Margin"
notes opmbd_wr : EBITDA Margin: ebitda/sale
notes opmbd_wr : Profitability

* opmad=coalesce(oiadp,oibdp-dp,sale-xopr-dp,revt-xopr-dp)/sale

gen opmad_wr = ebit / sale
replace opmad_wr = (ebitda - dp) / sale if missing(opmad_wr)
replace opmad_wr = (revt - xopr - dp) / sale if missing(opmad_wr)
la var opmad_wr "EBIT Margin"
notes opmad_wr : EBIT Margin: ebit/sale
notes opmad_wr : Profitability

* pretret_earnat=coalesce(oiadp,oibdp-dp,sale-xopr-dp,revt-xopr-dp)/((lag(ppent+act)+(ppent+act))/2)

gen temp1 = ebitda - dp
gen temp2 = sale-xopr-dp
gen temp3 = revt-xopr-dp
egen temp4 = rowfirst(ebit temp1 temp2 temp3)
gen pretret_earnat_wr = temp4 / earnat 
drop temp1 temp2 temp3 temp4	
la var pretret_earnat_wr "Pre-tax Return on Total Earning Assets"
notes pretret_earnat_wr : Pre-tax Return on Total Earning Assets: ebitda/earnat; Total Earning Assets: ppent+act
notes  pretret_earnat_wr  : profitability

* pretret_noa=coalesce(oiadp,oibdp-dp,sale-xopr-dp,revt-xopr-dp)/((lag(ppent+act-lct)+(ppent+act-lct))/2)

gen temp1 = ebitda-dp
gen temp2 = sale-xopr-dp
gen temp3 = revt-xopr-dp
egen temp4 = rowfirst(ebit temp1 temp2 temp3)
gen pretret_noa_wr = temp4 / noa
drop temp1 temp2 temp3 temp4
la var pretret_noa_wr "Pre-tax Return on Net Operating Assets"
notes pretret_noa_wr : Pre-tax Return on Net Operating Assets: ebit/noa; Net operating assets: ppent+act-lct
notes pretret_noa_wr : Profitability

* ptpm=coalesce(pi,oiadp-xint+spi+nopi)/sale

gen ptpm_wr = pi / sale
replace ptpm_wr = (ebit - xint + spi + nopi) / sale if missing(ptpm_wr)
la var ptpm_wr "Pre-tax Profit Margin"
notes ptpm_wr : Pre-tax Profit Margin: (ebit-xint+spi+nopi)/sale
notes ptpm_wr : Profitability

* roa=coalesce(oibdp,sale-xopr,revt-xopr)/((at+lag(at))/2)

gen roa_wr = ebitda/at
replace roa_wr = (sale - xopr) / at if missing(roa_wr)
replace roa_wr = (revt - xopr) / at if missing(roa_wr)
la var roa_wr "Return on Assets"
notes roa_wr : Return on Assets: ebitda/at
notes roa_wr : Profitability

* roce=coalesce(ebit,sale-cogs-xsga-dp)/((dltt+lag(dltt)+dlc+lag(dlc)+ceq+lag(ceq))/2)

gen roce_wr = ebit/(dltt + pstk + dlc + ceq)
replace roce_wr = (sale - cogs - xsga - dp) / (dltt + pstk + dlc + ceq) if missing(roce_wr)
la var roce_wr "Return on Capital Employed"
notes roce_wr : Return on Capital Employed: ebit/(dltt + pstk + dlc + ceq)
notes roce_wr : Profitability
* if ((be+lag(be))/2)>0 then roe=ib/((be+lag(be))/2)

gen roe_wr = ib/be if be>0
la var roe_wr "Return on Equity"
notes roe_wr : Return on Equity: ib/be if be>0
notes roe_wr : Profitability

*-----------------------------------------------
*Solvency Ratios
*-----------------------------------------------

* de_ratio=lt/sum(ceq,pstk_new)

egen temp1 = rowtotal(ceq pstk), missing
gen de_ratio_wr =lt/temp1 if temp1 > 1
drop temp1
la var de_ratio_wr  "Total Debt/Equity"
notes de_ratio_wr : Total Debt/Equity : lt/sum(ceq, pstk)
notes de_ratio_wr : Solvency

gen debt_assets_wr=lt/at
la var debt_assets_wr "Total Liabilities/Total Assets"
notes debt_assets_wr : Total Liabilities/Total Assets: lt/at
notes debt_assets_wr : Solvency

gen debt_at_wr = (dltt+dlc)/at
la var debt_at_wr "Long-term Debt/Total Assets"
notes debt_at_wr : Long-term Debt/Total Assets: (dltt+dlc)/at
notes  debt_at_wr : Solvency
*debt_capital=(ap+sum(dlc,dltt))/(ap+sum(dlc,dltt)+sum(ceq,pstk_new))

egen temp1 = rowtotal(dlc dltt), missing
egen temp2 = rowtotal(ceq pstk), missing
gen debt_capital_wr = (ap + temp1) / (ap + temp1 + temp2)
drop temp1 temp2
la var debt_capital_wr "Total Debt/Capital"
notes debt_capital_wr : Total Debt/Capital: (ap+sum(dlc,dltt))/(ap+sum(dlc,dltt)+sum(ceq,pstk))
notes  debt_capital_wr : Solvency

gen intcov_wr = (xint+ib)/xint 
la var intcov_wr 
la var intcov_wr "After-tax Interest Coverage"
notes intcov_wr : After-tax Interest Coverage: (xint+ib)/xint
notes intcov_wr  : Solvency

* intcov_ratio=coalesce(ebit,OIADP,sale-cogs-xsga-dp)/xint

gen intcov_ratio_wr = ebit/xint
replace intcov_ratio_wr = sale-cogs-xsga-dp/xint if missing(intcov_ratio)
la var intcov_ratio_wr "Interest Coverage Ratio"
notes intcov_ratio_wr : Interest Coverage Ratio: ebit/xint
notes intcov_ratio_wr  : Solvency

*-----------------------------------------------
* Valuation: Dividend Payout Ratio (only this one not using any market data)
*-----------------------------------------------

gen dpr_wr =  dv/ibadj if ibadj>0 
la var dpr_wr "Dividend Payout Ratio"
notes  dpr_wr : Dividend Payout Ratio: dv/ibadj
notes  dpr_wr : Divyield

unab wrdsratios : *_wr

di `"count of accounting vars and wrds ratios `=wordcount("`all_acc_vars' `wrdsratios'")'"'
egen missing_vars = rowmiss(`all_acc_vars' `wrdsratios')
la var missing_vars "Count of missing accounting variables and WRDS ratios" 

save compustat_wrds_ratios, replace
 
*------------------------------------------------------------------------------
* (4) Monthly folding (quarterly wrds ratios to monthly)
*------------------------------------------------------------------------------

use compustat_wrds_ratios, clear
* acc_mth is period ending month, mth is the prediction month, or the month the accounting info would have been available.
keep gvkey acc_mth mth

* fill in months between quarter ends...
sort gvkey mth
tsset gvkey mth
tsfill 

* fill forward acc_mth (2 further months)
fillforward acc_mth, cf(2) by(gvkey)

* merge in all the compustat quartely data - now by month
* because we are merging on accounting date (acc_mth), quarterly data are 
* automatically expanded to fill each month in the quarter

* note, include on "match" only
* note: rename mth to avoid being over-written
merge m:1 gvkey acc_mth using compustat_wrds_ratios, keep(match) nogen
sort gvkey mth
* TO ensure pre-IPO financials can be matched can be matched with CRSP returns, fill backward permno permco for three months 
forvalues i = 1/3 {
 	by gvkey: replace permno = permno[_n + 1] if missing(permno)
 	by gvkey: replace permco = permco[_n + 1] if missing(permco)	
}

drop if missing(permno)
* (1,900,057 observations deleted)
* keep the permno with the fewest missing_vars
sort permno mth missing_vars
duplicates drop permno mth, force
* (405 observations deleted)
count
* 3,470,061

*------------------------------------------------------------------------------
* ------------------- NOW AT MONTHLY FREQUENCY --------------------------------
*------------------------------------------------------------------------------

save compustat_wrds_ratios_monthly, replace

*------------------------------------------------------------------------------
* CRSP company-level (permco) market-weighted total returns
*------------------------------------------------------------------------------

use ${source}\\crsp_msf_processed, clear

gen crsp_market_equity = value  * 1000
la var crsp_market_equity "Market cap"
notes crsp_market_equity : Market capitalisation (shrout * abs(altprc)

drop if missing(shrcd)
count if shrcd != 10 & shrcd != 11

*using delisting adjusted total return
sort permno mth
tsset permno mth

by permno: gen mv = 1 if _n == 1
by permno: replace mv = l.mv*(1+daret) if _n > 1

gen return = daret
la var return "Monthly delisting adjusted total return in current month"

gen freturn = f.daret
la var return "Monthly delisting adjusted total return in next month"

save crsp_permno_returns, replace


*------------------------------------------------------------------------------
* CRSP returns merged into compustat
*------------------------------------------------------------------------------

use compustat_wrds_ratios_monthly, clear

* merge in CRSP returns
merge 1:1 permno mth using crsp_permno_returns, keep(master match) keepusing( shrcd exchcd altprc return freturn  crsp_market_equity shrout)
* matched   2,763,746  
* not matched 706,315 
sort gvkey mth
tsset gvkey mth
* current mth is month of firm value
* grow compustat equity value as of balancesheet date (month t) at total returns to current month (month t+4)
* this effectively adjusts for post-balance sheet data equity issuance or stock buybacks
gen gap = mth - acc_mth
la var gap "Gap between current month and balance sheet date month"


* replace debt value and cash value to zero if missing
replace debt_book_value = 0 if missing(debt_book_value)
gen cash = che
replace cash = 0 if missing(cash)
gen net_debt_book_value = debt_book_value - cash
*
gen firm_value = crsp_market_equity + debt_book_value
replace firm_value = . if firm_value <= 0
la var firm_value "Firm value"
notes firm_value : Firm value,  sum of equity market cap and total debt in millions

*------------------------------------------------------------------------------
* Total assets
*------------------------------------------------------------------------------

gen assets = at
la var assets "Total book assets"
notes assets: Total book assets
notes assets: Size

*------------------------------------------------------------------------------
* Target value
*------------------------------------------------------------------------------

* market - to - book ratio
gen m2b = crsp_market_equity / be
la var m2b "Market value to book equity"
notes m2b: Market value to book equity

* take logs (mitigates effect of outliers)
* in trees, equivalent to taking geometric avg of target values in leaves
* instead of arithmetic average
gen lnm2b = ln(m2b)
la var lnm2b "Natural logarithm of market value to book equity"
notes lnm2b: Natural logarithm of market value to book equity

gen v2a = ( firm_value / assets)
la var v2a "Enterprise value to total assets"
notes v2a: Enterprise value to total assets
gen lnv2a = ln(v2a)
la var lnv2a "Natural logarithm of enterprise value to total assets"
notes lnv2a: Natural logarithm of enterprise value to total assets

gen v2s = ( firm_value / sale)
la var v2s "Enterprise value to sales"
gen lnv2s = ln(v2s)
la var lnv2s "Natural logarithm of enterprise value to sales"
notes lnv2s : Natural logarithm of enterprise value to sales

gen m2s = crsp_market_equity / sale
la var m2s "Market value to sales"
notes m2s : Market value to sales

gen lnm2s = ln(m2s) 
la var lnm2s "Natural logarithm of market value to sales"
notes lnm2s : Natural logarithm of market value to sales

* m (market value of equity)
gen m = crsp_market_equity
* lnm (log of market value of equity)
gen lnm = ln(m)
* unit as a scalevar in Python code when using m and lnm as target vars
gen unit = 1

sort mth gvkey

*------------------------------------------------------------------------------
* Risk premia (borrowed from anomalies project)
*------------------------------------------------------------------------------

* NOTE: Close duplicates relative to WRDS are not included
* NOTE: Only anomalies based on accounting data (no market data)

* =inventorygrowth=
gen  inventorygrowth_an = d_invt / l_invt 
la var inventorygrowth_an "Inventory Growth" 
notes  inventorygrowth_an : Inventory Growth: d_invt/l_invt
notes  inventorygrowth_an : Growth
** sum inventorygrowth, detail

* =salesgrowth=
gen  salesgrowth_an = ( sale / l_sale ) - 1 
la var salesgrowth_an "Sales Growth" 
notes  salesgrowth_an: Sales Growth: (sale/l_sale)-1
notes  salesgrowth_an: Growth
** sum salesgrowth, detail

* =inventorychange=
gen  inventorychange_an = d_invt / ( 0.5 * l_at + 0.5 * at ) 
la var inventorychange_an "$ \Delta $ Inventory" 
notes  inventorychange_an : $ \Delta $ Inventory: d_invt/(0.5*l_at+0.5*at)
notes inventorychange_an: Growth  
** sum inventorychange, detail

* =capexgrowth=
gen  capexgrowth_an = d_capx / l_capx 
la var capexgrowth_an "Capex Growth" 
notes capexgrowth_an : Capex Growth: d_capx/l_capx
notes  capexgrowth_an : Growth
** sum capexgrowth, detail

* =assetgrowth=
gen  assetgrowth_an = d_at / l_at 
la var assetgrowth_an "Asset Growth" 
notes assetgrowth_an : Asset Growth: d_at/l_at 
notes  assetgrowth_an: Growth
** sum assetgrowth, detail

* =opleverage=
gen  opleverage_an = ( cogs + xsga ) / at 
la var opleverage_an "Operating Leverage" 
notes opleverage_an : Operating Leverage: (cogs+xsga)/at 
notes opleverage_an : Efficiency
** sum opleverage, detail

* =grossmargin=
gen  grossmargin_an = ( sale - cogs ) / sale 
la var grossmargin_an "Gross Profit Margin" 
notes grossmargin_an : Gross Profit Margin: (sale-cogs)/sale
notes grossmargin_an : Profitability
** sum grossmargin, detail

* =grossprofit=
gen  grossprofit_an = ( sale - cogs ) / at 
la var grossprofit_an "Gross Profit" 
notes grossprofit_an : Gross Profit: (sale-cogs)/at
notes grossprofit_an : Profitability
** sum grossprofit, detail

* =assetturnover=
gen  assetturnover_an = sale / at 
la var assetturnover_an "Asset Turnover" 
notes assetturnover_an : Asset Turnover: sale/at
notes assetturnover_an : Efficiency
** sum assetturnover, detail

* =chlt=
gen  chlt_an = ( lt / l_lt ) - 1 
la var chlt_an "$ \Delta $ Total Liabilities" 
notes chlt_an : $ \Delta $ Total Liabilities: (lt/l_lt)-1 
notes chlt_an : Growth
** sum chlt, detail

* =chceq=
gen  chceq_an = ( ( ceq - l_ceq ) / l_ceq ) 
la var chceq_an "$ \Delta $ Book Equity" 
notes chceq_an : $ \Delta $ Book Equity: (ceq-l_ceq)/l_ceq
notes chceq_an : Growth
** sum chceq, detail

* =chca=
gen  chca_an = ( d_act - d_che ) / l_at 
la var chca_an "$ \Delta $ Non-cash Current Assets" 
notes chca_an : $ \Delta $ Non-cash Current Assets: (d_act-d_che)/l_at 
notes chca_an: Growth
** sum chca, detail

* =chcl=
gen  chcl_an = ( d_lct - cond( missing( d_dlc ) , 0 , d_dlc ) ) / l_at 
la var chcl_an "$ \Delta $ Non-debt Current Liabilities" 
notes chcl_an : $ \Delta $ Non-debt Current Liabilities: (d_lct-cond(missing(d_dlc),0,d_dlc))/l_at
notes chcl_an : Growth
** sum chcl, detail

* =liquid2assets=
gen  liquid2assets_an = ( che + 0.75 * ( act - che ) + 0.5 * ( at - act ) ) / l_at 
la var liquid2assets_an "Liquid Assets" 
notes liquid2assets_an : Liquid Assets: (che+0.75*(act-che)+0.5*(at-act))/l_at 
notes liquid2assets_an : Liquidity
** sum liquid2assets, detail

* =chnccl=
gen  chnccl_an = ( d_lt - d_lct - cond( missing( d_dltt ) , 0 , d_dltt ) ) / l_at 
la var chnccl_an "$ \Delta $ Non-current Operating Liabilities" 
notes chnccl_an : $ \Delta $ Non-current Operating Liabilities: (d_lt-d_lct-cond(missing(d_dltt),0,d_dltt))/l_at 
notes chnccl_an : Growth
** sum chnccl, detail

* =chfnl=
egen __nm = rownonmiss( d_dltt d_dlc d_pstk ) 
gen  chfnl_an = ( cond( missing( d_dltt ) , 0 , d_dltt ) + cond( missing( d_dlc ) , 0 , d_dlc ) + cond( missing( d_pstk ) , 0 , d_pstk ) ) / l_at  if ( __nm >= 1  ) & ( ( !( sicn >= 6000 & sicn <= 6999 ) )  ) 
la var chfnl_an "$ \Delta $ Financial Liabilities" 
notes chfnl_an: $ \Delta $ Financial Liabilities: (cond(missing(d_dltt ), 0, d_dltt) + cond(missing(d_dlc),0,d_dlc) + cond(missing(d_pstk),0,d_pstk)) / l_at
drop __nm 
notes chfnl_an : Growth
** sum chfnl, detail

* =chbe=
gen  chbe_an = ( be - l_be ) / l_at 
la var chbe_an "$ \Delta $  Book Equity" 
notes chbe_an : $ \Delta $  Book Equity: (be-l_be)/l_at 
notes chbe_an  : Growth
** sum chbe, detail

* =investment=
gen  investment_an = d_at / at 
la var investment_an "Investment" 
notes investment_an : Investment: d_at/at
notes  investment_an : Growth
** sum investment, detail

* =profitability=
gen  profitability_an = ( sale - cogs - xint - xsga ) / be
la var profitability_an "Profitability (pbt/equity)"
notes profitability_an : Profitability: (sale-cogs-xint-xsga)/be
notes profitability_an : Profitability
** sum profitability, detail


* =cash2assets=
gen  cash2assets_an = che / at  if ( ( !( sicn >= 6000 & sicn <= 6999 ) ) & ( !( sicn >= 4900 & sicn <= 4949 ) )  ) & ( ( !( sicn >= 6000 & sicn <= 6999 ) )  ) 
la var cash2assets_an "Cash/Total Assets" 
notes cash2assets_an: Cash/Total Assets: che/at for non-financial firms 
notes cash2assets_an: Liquidity
** sum cash2assets, detail

* =chcurrentratio=
gen  chcurrentratio_an = ( ( act / lct ) - ( l_act / l_lct ) ) / ( l_act / l_lct ) 
la var chcurrentratio_an "$ \Delta $ Current Ratio" 
notes chcurrentratio_an : $ \Delta $ Current Ratio: ((act/lct)-(l_act/l_lct))/(l_act/l_lct)
notes chcurrentratio_an: Liquidity
** sum chcurrentratio, detail

* =pchquickratio=
gen  pchquickratio_an = ( ( act - invt ) / lct - ( l_act - l_invt ) / l_lct ) / ( ( l_act - l_invt ) / l_lct ) 
la var pchquickratio_an "$ \Delta $ Quick Ratio" 
notes pchquickratio_an : $ \Delta $ Quick Ratio: ((act-invt)/lct-(l_act-l_invt)/l_lct)/((l_act-l_invt)/l_lct)
notes pchquickratio_an : Liquidity
** sum pchquickratio, detail

* =sales2cash=
gen  sales2cash_an = sale / che 
la var sales2cash_an "Sales/Cash"
notes sales2cash_an : Sales/Cash: sale/che 
notes sales2cash_an : Efficiency
** sum sales2cash, detail

* =sales2rec=
gen  sales2rec_an = sale / rect 
la var sales2rec_an "Sales/Receivables" 
notes sales2rec_an : Sales/Receivables: sale/rect
notes sales2rec_an : Efficiency
** sum sales2rec, detail

* =sales2inv=
gen  sales2inv_an = sale / invt 
la var sales2inv_an "Sales/Inventory" 
notes sales2inv_an : Sales/Inventory: sale/invt
notes sales2inv_an : Efficiency
** sum sales2inv, detail

* =pchsales2inv=
gen  pchsales2inv_an = ( ( sale / invt ) - ( l_sale / l_invt ) ) / ( l_sale / l_invt ) 
la var pchsales2inv_an "$ \Delta $ Sales/Inventory" 
notes pchsales2inv_an : $ \Delta $ Sales/Inventory: ((sale/invt)-(l_sale/l_invt))/(l_sale/l_invt)
notes pchsales2inv_an : Efficiency
** sum pchsales2inv, detail

* =cf2debt=
gen  cf2debt_an = ( ib + dp ) / ( ( lt + l_lt ) / 2 ) 
la var cf2debt_an "Cash Flow/Total Liabilities" 
notes cf2debt_an : Cash Flow/Total Liabilities: (ib+dp)/((lt+l_lt)/2)
notes cf2debt_an : Solvency
** sum cf2debt, detail

* =deprn=
gen  deprn_an = dp / ppent 
la var deprn_an "Depreciation Rate" 
notes deprn_an : Depreciation Rate: dp/ppent
notes deprn_an : Growth
** sum deprn, detail

* =pchdeprn=
gen  pchdeprn_an = ( ( dp / ppent ) - ( l_dp / l_ppent ) ) / ( l_dp / l_ppent ) 
la var pchdeprn_an "$ \Delta $ Depreciation Rate" 
notes pchdeprn_an : $ \Delta $ Depreciation Rate: ((dp/ppent)-(l_dp/l_ppent))/(l_dp/l_ppent)
notes pchdeprn_an : Growth
** sum pchdeprn, detail

* =pchsale2pchinvt=
gen  pchsale2pchinvt_an = ( ( sale - l_sale ) / l_sale ) - ( ( invt - l_invt ) / l_invt ) 
la var pchsale2pchinvt_an "$ \Delta $ Sales$ -\Delta $ Inventory" 
notes pchsale2pchinvt_an : $ \Delta $ Sales$ -\Delta $ Inventory: ((sale-l_sale)/l_sale)-((invt-l_invt)/l_invt)
notes pchsale2pchinvt_an : Efficiency
** sum pchsale2pchinvt, detail

* =pchsale2pchrect=
gen  pchsale2pchrect_an = ( ( sale - l_sale ) / l_sale ) - ( ( rect - l_rect ) / l_rect ) 
la var pchsale2pchrect_an "$ \Delta $ Sales$ -\Delta $ Receivables" 
notes pchsale2pchrect_an : $ \Delta $ Sales$ -\Delta $ Receivables: ((sale-l_sale)/l_sale)-((rect-l_rect)/l_rect)" 
notes pchsale2pchrect_an : Efficiency
** sum pchsale2pchrect, detail

* =pchgm2pchsale=
gen  pchgm2pchsale_an = ( ( ( sale - cogs ) - ( l_sale - l_cogs ) ) / ( l_sale - l_cogs ) ) - ( ( sale - l_sale ) / l_sale ) 
la var pchgm2pchsale_an "$ \Delta $ Gross Profit$ -\Delta $ Sales" 
notes pchgm2pchsale_an: $ \Delta $ Gross Profit$ -\Delta $ Sales: (((sale-cogs)-(l_sale-l_cogs))/(l_sale-l_cogs))-((sale-l_sale)/l_sale)
notes pchgm2pchsale_an: Efficiency
** sum pchgm2pchsale, detail

* =pchsale2pchxsga=
gen  pchsale2pchxsga_an = ( ( sale - l_sale ) / l_sale ) - ( ( xsga - l_xsga ) / l_xsga ) 
la var pchsale2pchxsga_an "$ \Delta $ Sales$ -\Delta $ SGA" 
notes pchsale2pchxsga_an: $ \Delta $ Sales$ -\Delta $ SGA: ((sale- l_sale)/l_sale)-((xsga-l_xsga)/l_xsga )
notes pchsale2pchxsga_an: Efficiency
** sum pchsale2pchxsga, detail

* =roic=
gen  roic_an = ( ebit - nopi ) / ( ceq + lt - che ) 
la var roic_an "Return on Invested Capital" 
notes roic_an : Return on Invested Capital: (ebit-nopi)/(ceq+lt-che)
notes roic_an : Profitability
** sum roic, detail

* =debt2tang=
gen  debt2tang_an = ( che + rect * 0.715 + invt * 0.547 + ppent * 0.535 ) / at 
la var debt2tang_an "Debt Capacity to Tangibility" 
notes debt2tang_an: Debt Capacity to Tangibility: (che+rect*0.715+invt *0.547+ppent*0.535)/at
notes debt2tang_an: Solvency
** sum debt2tang, detail

* =marginch=
gen  marginch_an = ( ib / sale ) - ( l_ib / l_sale ) 
la var marginch_an "$ \Delta $ Profit Margin" 
notes marginch_an: $ \Delta $ Profit Margin: (ib/sale)-(l_ib/l_sale) 
notes marginch_an: Profitability
** sum marginch, detail

* =assetturnover2=
gen  assetturnover2_an = ( sale / ( ( at + l_at ) / 2 ) ) 
la var assetturnover2_an "Asset Turnover" 
notes assetturnover2_an: Asset Turnover: (sale/((at+l_at)/2))
notes assetturnover2_an: Efficiency
** sum assetturnover2, detail

* =ebitda2revenue=
gen  ebitda2revenue_an = ebitda / sale 
la var ebitda2revenue_an "EBITDA Margin" 
notes ebitda2revenue_an: EBITDA Margin: ebitda/sale
notes ebitda2revenue_an: Profitability
** sum ebitda2revenue, detail

* =bookequitygrowth=
gen  bookequitygrowth_an = ( be / l_be ) - 1 
la var bookequitygrowth_an "Growth in Book Equity" 
notes bookequitygrowth_an: Growth in Book Equity: (be/l_be)-1
notes bookequitygrowth_an: Growth
** sum bookequitygrowth, detail


*------------------------------------------------------------------------------
* WRDS median ratios
*------------------------------------------------------------------------------

unab wrdsratios : *_wr

sort industry mth gvkey

foreach v in `wrdsratios' {
	di "doing `v'..."
	sort industry mth `v'
	local r = subinstr("`v'","_wr","",.)
	* quick and dirty median (if even nr of firms, take avg of middle two
	qui by industry mth: gen `r'_wm = cond(mod(_N,2)==1,`r'_wr[ceil(_N/2)],(`r'_wr[floor(_N/2)] + `r'_wr[ceil(_N/2)])/2)
	qui gen `r'_wd = `v' - `r'_wm
}

compress
memory

* postfix _ac indicates accounting variables
foreach v in `all_acc_vars' `all_lag_vars'{
	ren `v' `v'_ac
}

*  scale by book equity

* postfix _at indicates scaled by total assets, _be indicates scaled by book equity
foreach v in `all_acc_vars' `all_lag_vars' {
	
	gen `v'_at = `v'_ac / at_ac
	local lbl : variable label `v'_ac
	label var `v'_at `"`lbl' (scaled by assets)"'  
	
	gen `v'_be = `v'_ac / be_ac
	local lbl : variable label `v'_ac
	label var `v'_be `"`lbl' (scaled by book equity)"'  
	
}

drop be_be
drop at_at

* Python code will create year
drop year

gen book = be_ac
la var book "Book equity"
notes book : Book equity as per Davis Fama French (2000) 
notes book : Size
rename gvkey gvkeynum

unab wrdsratios : *_wr
unab anomalies : *_an

* count number of missing vars needed for ML
capture drop missing_vars
di `"count of anomaly vars and wrds ratios `=wordcount("`anomalies' `wrdsratios'")'"'
egen missing_vars = rowmiss(`anomalies' `wrdsratios')
la var missing_vars "Count of missing WRDS ratios and anomalies"

capture drop _merge
count
* 3,470,061

drop if crsp_market_equity == .
*(712,145 observations deleted)
save temp, replace


* merge in CAPM beta
*------------------------------------------------------------------------------
* Save final data (unfiltered -- to merge to generate portfolio returns)
*------------------------------------------------------------------------------

use ${source}\\factorloadings_crspmonthly, clear
sort permno mth CAPMbeta
duplicates drop permno mth, force
save capm_betas, replace

use temp, clear
merge 1:1 mth permno using capm_betas, keep(master match) nogen keepusing(CAPMbeta)
* matched                          2,757,916   

la var CAPMbeta "CAPM beta"
notes CAPMbeta: Beta on MKTRF estimated over 60 months (using CAPM)
notes CAPMbeta: Beta

notes sale_ac : Sales/Turnover (Net)
notes sale_ac : Size

notes industry : Fama French 49 industries
notes industry : Industry

* month is saved as a number, not a date - usefull in python code
gen month = mth
la var month "Month of valuation date (at least 3 month after BS date) - numeric"

sort gvkeynum mth

* create an ex-post 3-year growth in sales measure (used in SHAP analysis - VariableImportanceSub.do)

sort gvkeynum mth
by gvkeynum: gen SalesGrowth = (sale_ac[_n+36] / sale_ac) - 1 if gvkeynum == gvkeynum[_n+36]
la var SalesGrowth "Ex-post 3-year sales growth"


*------------------------------------------------------------------------------
* (4) Final sample (filtering)
*------------------------------------------------------------------------------

file close _all
tempvar fh
file open `fh' using ${results}\\sample_selection.tex, write text replace

file write `fh' "\begin{tabular}{lrrr}" _n
file write `fh' "\hline" _n
file write `fh' "Steps & Firm-Months & Firms \\" _n
file write `fh' "\hline" _n

* [1] Share code 10 or 11 and dates within sample period

local cond1 ( (shrcd == 10 | shrcd == 11) & (exchcd == 1 | exchcd == 2 | exchcd == 3) & (${datecutoff}) )
local conddesc "Common domestic stocks listed on NYSE, NASDAQ or AMEX"

local conditions `cond1'
qui distinct gvkey if `conditions'
local fycount : di %9.0fc =  r(N)
local fcount : di %9.0fc =  r(ndistinct)
qui su crsp_market_equity if `conditions'
local asum_start = round(r(sum)/1000)
local asum = round( ((r(sum)/1000) / `asum_start')*100 )
local finaldesc = "`conddesc' & `fycount' & `fcount' "
file write `fh' "`finaldesc' \\" _n
di "`finaldesc'"

* [2] Positive and non-missing target ratios (m2b, v2a, v2s)

local cond2 ( (!missing(lnm2b)) & (!missing(lnv2a)) & (!missing(lnv2s)) & (m2b > 0) & (v2a > 0) & (v2s > 0) )
local conddesc "Positive and non-missing targets (m2b, v2a, v2s)"

local conditions `cond1' & `cond2'
qui distinct gvkey if `conditions'
local fycount : di %9.0fc =  r(N)
local fcount : di %9.0fc =  r(ndistinct)
qui su crsp_market_equity if `conditions'
local asum_start = round(r(sum)/1000)
local asum = round( ((r(sum)/1000) / `asum_start')*100 )
local finaldesc = "`conddesc' & `fycount' & `fcount' "
file write `fh' "`finaldesc' \\" _n
di "`finaldesc'"

* [3] Identify variables above 10th percentile in each month

capture drop be_ac_q20 at_ac_q20 sale_ac_q20
local scalevars be_ac at_ac sale_ac
foreach v in `scalevars' {
	sort mth `v'
	gquantiles `v'_q20 = `v' if `cond1' & `cond2', xtile nquantiles(20) by(mth)
	la var `v'_q20 "20 quantiles of `v' (1 - 20)"
}

su at_ac_q20, detail
count if !missing(at_ac)

local cond3 ( (be_ac_q20 > 2) & (at_ac_q20 > 2) & (sale_ac_q20 > 2) & !missing(be_ac_q20) & !missing(at_ac_q20) & !missing(sale_ac_q20))
local conddesc "All scale variables above 10th percentile in each month"

local conditions `cond1' & `cond2' & `cond3'
qui distinct gvkey if `conditions'
local fycount : di %9.0fc =  r(N)
local fcount : di %9.0fc =  r(ndistinct)
qui su crsp_market_equity if `conditions'
local asum_start = round(r(sum)/1000)
local asum = round( ((r(sum)/1000) / `asum_start')*100 )
local finaldesc = "`conddesc' & `fycount' & `fcount' "
file write `fh' "`finaldesc' \\" _n
di "`finaldesc'"

* filtering complete

file write `fh' "\hline" _n
file write `fh' "\end{tabular}" _n
file close `fh'

* sample indicator variables

capture drop full_sample
gen full_sample =  `cond1' & `cond2'
la var full_sample "Full sample indicator variable"
count if full_sample

capture drop filtered_sample
gen filtered_sample =  `cond1' & `cond2'  & `cond3'
la var filtered_sample "Final filtered sample indicator variable"
count if filtered_sample

count
count if full_sample
count if filtered_sample

save valuation_data_unfiltered, replace

* set cross-sectional hash (for allocating to blocks in each month)
use valuation_data_unfiltered, clear
keep if full_sample
sort mth gvkeynum
set seed 1000
by mth: gen hash100 = runiformint(1,99)

* year variable as integer - used by ML code for sample splitting
gen int year = year(dofm(mth))

save valuation_data_all_blocks, replace

keep gvkeynum mth month year hash100 lnm2b lnv2a m2b lnv2s m lnm industry assets book sale_ac debt_book_value unit CAPMbeta *_wr *_an 

save valuation_all, replace

*------------------------------------------------------------------------------
* Save final data (filtered - for training)
*------------------------------------------------------------------------------

use valuation_data_all_blocks, clear
keep if filtered_sample

* create pretend data for use as dummy dev set 
* (for AltSplit that does not use dev set)
* (ML code breaks if dev set is empty, so ... a pragmatic solution)

levelsof(mth), local(mth_list)

local new_obs = wordcount("`mth_list'")
local oldN = _N
local total_obs =  `oldN' + `new_obs'
set obs `total_obs'

local k = 0
forvalues ob = `=`oldN'+1'(1)`total_obs' {
	local ++k
	di "k = `k', ob = `ob'"
	replace gvkeynum = 0 in `ob'
	local curdate = word("`mth_list'",`k')
	replace mth = `curdate' in `ob'
	replace month = `curdate' in `ob'
	* hash 100 corresponds to block 6 in ML code
	replace hash100 = 100 in `ob'	
	* ensure non-missing targets, so it does not get filtered out
	foreach v in lnm2b lnv2a lnv2s m2b m lnm {
		replace `v' = 1 in `ob'
	}
	* ensure a few non-missing inputs
	foreach v in industry assets book sale_ac debt_book_value unit CAPMbeta {
		replace `v' = 1 in `ob'
	}
}

sort mth gvkeynum

* all filtered data
save valuation_data_filtered_blocks, replace

keep gvkeynum mth month year hash100 lnm2b lnv2a m2b lnv2s m lnm industry assets book sale_ac debt_book_value unit CAPMbeta *_wr *_an 

* filtered data - only what is required by ML code
save valuation_filtered, replace

*------------------------------------------------------------------------------
* (5) Save data for RRV
*------------------------------------------------------------------------------

foreach v in filtered all {
	
	use valuation_data_`v'_blocks, clear
	merge m:1 sicn using ${source}\\FF12_sic, nogen keep(master match)

	sort gvkeynum mth 
	duplicates drop gvkey mth, force

	keep permco gvkeynum permno mth acc_mth crsp_market_equity be_ac industry ni_ac dltt_ac  dlc_ac  at_ac hash100 m2b book ff12 ff12_des sicn book assets debt_book_value
	* Golubov and Constantiniti definition
	gen LEV = (dltt_ac + dlc_ac) /  at_ac
	la var LEV "Leverage"
	notes LEV : Leverage ((dltt+dlc)/at) as in Golubov and Konstantinidi (2019) 
	* RRV definitions
	gen LEV_book = (1 - book / assets)
	la var LEV_book "Book Leverage"
	notes LEV_book : Book leverage (1-book/at) as in Rhodes-Kropf, Robinson and Viswanathan (2005)
	gen LEV_mkt = (1 - m2b * book  / (m2b * book + debt_book_value))
	la var LEV_mkt "Market Leverage"
	note LEV_mkt : Market leverage (1 - m2b * book  / (m2b * book + debt_book_value)) as in Rhodes-Kropf, Robinson and Viswanathan (2005)

	gen lnni = ln(abs(ni_ac)) 
	la var lnni "Natural logarithm of the absolute value of net income"
	notes lnni : Natural logarithm of absolute value of the last four-quarter net income (ln(abs(ni_ac)))
	gen  negni = (ni_ac < 0 & ni_ac != .) 
	la var negni  "Loss indicator"
	notes negni : An indicator variable for loss (ni_ac < 0 & ni_ac != .)
	gen lnm = ln(crsp_market_equity)
	la var lnm "Natural logaritm of market cap"
	notes lnm: "Natural logarithm of market value of equity from CRSP (ln(crsp_market_equity))"
	gen lnb = ln(be_ac)
	la var lnb "Natural logarithm of book equity"
	notes lnb: Natural logarithm of book equity(ln(be_ac))

	gstats winsor lnb lnni negni LEV_book, cuts(1 99) replace by(mth)
	
	sum permco permno gvkeynu acc_mth lnm lnb lnni negni LEV LEV_book LEV_mkt industry acc_mth hash100  m2b book ff12 sicn 
	
	
	keep mth permco permno gvkeynu acc_mth lnm lnb lnni negni LEV  LEV_book LEV_mkt industry acc_mth hash100 crsp_market_equity m2b book  ff12 ff12_des sicn

	save RRVdata_`v', replace
}


*------------------------------------------------------------------------------
* (6) Save data for BG
*------------------------------------------------------------------------------

foreach d in filtered all {
	
	use valuation_data_`d'_blocks, clear

	sort gvkeynum mth gvkey
	duplicates drop gvkey mth, force

	local bglist
	foreach v in $bg_bsitems  $bg_cfitems  $bg_y2ditems {
		local bglist `bglist' `v'_ac
	}

	keep if ${bg_datecutoff}
	
	gstats winsor `bglist', cuts(1 99) replace by(mth)
	
	keep permco gvkeynum permno mth acc_mth crsp_market_equity `bglist' mibn_ac hash100  m2b book  
	sum permco gvkeynum permno mth acc_mth crsp_market_equity `bglist' mibn_ac hash100 m2b book 
	save BGdata_`d', replace
}


*------------------------------------------------------------------------------
* (7) Save data for BL
*------------------------------------------------------------------------------
foreach v in filtered all {
	
	use valuation_data_`v'_blocks, clear

	* treat missing industry as 50
	*replace industry = 50 if missing(industry)

	sort gvkeynum mth gvkey
	duplicates drop gvkey mth, force

	label var v2s "Firm value to sales multiple"
	notes v2s : Firm value (market value of equity + total debt) to sales (sale) multiple
	
	label var v2a "Firm value to assets multiple"
	notes v2a : Firm value (market value of equity + total debt) to assets (at) multiple
	
	* indv2s: industry v2s, harmonic mean of enterprise to sales
	gen v2s_inv = 1/v2s
	sort mth industry
	by mth industry: egen indv2s = sum(v2s_inv)
	by mth industry: egen N = count(v2s_inv)
	replace indv2s = N/indv2s
	drop N
	label var indv2s "Cross-sectional industry harmonic mean of v2s"
	notes indv2s : Cross-sectional industry harmonic mean of firm value to sales multiple
	
	* indv2a: industry v2a, harmonic mean of enterprise value to assets
	gen v2a_inv = 1/v2a
	sort mth industry
	by mth industry: egen indv2a = sum(v2a_inv)
	by mth industry: egen N = count(v2a_inv)
	replace indv2a = N/indv2a
	drop N
	label var indv2a "Cross-sectional industry harmonic mean of v2a"
	notes indv2a : Cross-sectional industry harmonic mean of firm value to total assets multiple
	
	* indm2b: industry m2b, harmonic mean of market to book 
	gen m2b_inv = 1/m2b
	sort mth industry
	by mth industry: egen indm2b = sum(m2b_inv)
	by mth industry: egen N = count(m2b_inv)
	replace indm2b = N/indm2b
	drop N
	label variable indm2b  "Cross-sectional industry harmonic mean of m2b"
	notes indm2b :  Cross-sectional industry harmonic mean of market to book multiple
	
	* adj operating profit margin after depreciation (opmad_wr): opmad_wr - median
	gen adjopmad = opmad_wr - opmad_wm
	label var adjopmad "Industry adjusted opearting profit margain"
	notes adjopmad : Industry adjusted opearting profit margain (actual - median); opmad_wr-opmad_wm
	
	* negopmad
	gen negadjopmad = adjopmad if adjopmad <= 0
	replace negadjopmad = 0 if missing(negadjopmad)
	label var negadjopmad  "Negative adjopmad" 
	notes negadjopmad : adjopmad * an indicator variable for negative adjopmad
	
	* adjsalesgrowth
	sort mth industry
	by mth industry: egen salesgrowth_anm = median(salesgrowth_an)
	gen adjsalesgrowth = salesgrowth_an - salesgrowth_anm
	label var adjsalesgrowth "Industry adjusted sales growth"
	notes adjsalesgrowth : "Industry adjusted sales growth (actual - median)"
	gen d2e = (dltt_ac + dlc_ac) /  book
	label var d2e "Debt to equity"
	notes d2e : Total debt (dltt + dlc) to book equity

	keep permco gvkeynum permno mth acc_mth crsp_market_equity hash100 v2s v2a m2b indv2s indv2a indm2b adjopmad  negadjopmad adjsalesgrowth d2e pretret_noa_wr roe_wr rd_sale_wr debt_book_value sale_ac book assets hash100
	
	local vars indv2s indv2a indm2b adjopmad negadjopmad adjsalesgrowth d2e pretret_noa_wr roe_wr rd_sale_wr 
	gstats winsor `vars', cuts(1 99) replace by(mth)
	
	sum permco gvkeynum permno mth acc_mth crsp_market_equity hash100 v2s v2a m2b indv2s indv2a indm2b adjopmad  negadjopmad adjsalesgrowth d2e pretret_noa_wr roe_wr rd_sale_wr debt_book_value sale_ac book assets 
	
	* for use by Python ML code
	gen month = mth
	la var month "Month of valuation date (at least 4 month after BS date) - numeric"
	
	* year variable as integer - used by ML code for sample splitting
	gen int year = year(dofm(mth))
	
	* for use in ReconciliatoinResults.do
	gen lnm2b = ln(m2b)
	gen lnv2a = ln(v2a)
	gen lnv2s = ln(v2s)

	save BLdata_`v', replace

}	
timer off 1
timer list 1









