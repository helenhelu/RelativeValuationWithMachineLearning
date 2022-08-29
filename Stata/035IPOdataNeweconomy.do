* ----------------------------------------------------------------------------
* IPOdataNeweconomy
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


* (1) start with cleaned crsp file (only contains shrcd 10 11 and exchgcd 1 2 3); gen ncusip6 for merging with SDCIPOs
* (2) import Ritter IPO data
* (3) Import SDC IPO data
* (4) merge SDC and Ritter IPOs (get price from SDC, use Ritter issue date, cusip and permno when avaiable); merge in crsp from step (1)
* (5) import SCOOP to fill in missing IPO prices (drop 112 IPOs without price in the end, out of about 10k) 
* (6) nearmrg with CRSP daily on IPOdate (date); obtain IPO initial return and closing market cap on the first trading day


* ----------------------------------------------------------------------------
* (1) start with cleaned crsp file (only contains shrcd 10 11 and exchgcd 1 2 3); gen ncusip6 for merging with SDCIPOs
* ----------------------------------------------------------------------------

* format ncusip to six digits in crsp
use ${source}\\crsp_msf_processed.dta, clear
gen ncusip6 = substr(ncusip,1,6)
* missing ncusips earlier than 1966 
drop if ncusip6 == ""
* keep unique ncuip6 mth IPO combination
gen mtkcap = abs(prc) * shrout
gsort ncusip6 mth -mtkcap
duplicates drop ncusip6 mth, force

duplicates tag ncusip6 mth, gen(rep)
count if rep >= 1
drop rep
save ${source}\\crsp_msf_processed1.dta, replace

* ----------------------------------------------------------------------------
* (2) import Ritter IPO data
* ----------------------------------------------------------------------------

* import IPO data from Ritter (Credit: Loughran and Ritter (2004 Financial Management) "Why Has IPO Underpricing Changed over Time?"
* "including IPOs with an offer price of below $5.00 before 1984"
* "N=11,159 IPOs for which founding dates are available"

import excel ${source}\\Ritter_IPO_andage19752019.xlsx, sheet("Sheet1") firstrow clear
* drop note
drop J
* gen ncusip6
gen ncusip6 = substr(CUSIP, 1, 6)
rename CUSIP cusip_ritter
rename CRSPperm permno
destring permno, replace
tostring Offerdate, replace
gen date = date(Offerdate, "YMD")
format date %td
drop Offerdate
gen Offerdate = date
drop date
format Offerdate %td
gen IPOyear = year(Offerdate)

drop if permno == .
drop if IPOyear == .
save ${source}\\RitterIPOs, replace

* ----------------------------------------------------------------------------
* (3) Import SDC IPO data
* ----------------------------------------------------------------------------

* import SDC IPO data

import excel ${source}\\SDC_19_7_2019_cleaned_long.xlsx, sheet("Data") firstrow clear

ren CUSIP ncusip6

* duplicates cusips (issued in multiple markets)
* keep the one with largest total proceeds (only 7 has different total proceeds)
duplicates tag ncusip6, gen(rep)
count if rep >= 1
* 2,396
* some are one IPO in two markets, some are in different years; keep unique ncusip6 IPOyear copy
gen IPOyear = year(IssueDate)
sort ncusip6 IPOyear
count
*  15,410
gsort ncusip6 IssueDate -ProceedsAmtsumofallMkts
duplicates drop ncusip6 IPOyear, force
drop if IssueDate == .
	
gen mth = mofd(IssueDate)
format mth %tm
ren ProceedsAmtsumofallMkts IPOsize

keep ncusip6 FilingDate IssueDate IPOsize OfferPrice mth IPOyear TickerSymbol

la var FilingDate "Filing date in SDC"
la var IssueDate "IssueDate in SDC"
la var IPOsize "IPO deal size in SDC"
la var OfferPrice "IPO price in SDC" 
*la var StockPrice1DayAfter "Stock price 1 day after in SDC" -- PG - not used 
*la var SharesOutstandingBeforeO "Shares outstanding before offering in SDC" -- PG - not used 
*la var OrdinarySharesOfferedsum  "Ordinary Share Offered - sum of all Mkts from SDC" -- PG - not used 
save ${source}\\SDCIPOs, replace

* ----------------------------------------------------------------------------
* (4) merge SDC and Ritter IPOs: use Ritter IPO info if SDC info is missing or different
* ----------------------------------------------------------------------------

use ${source}\\SDCIPOs, clear
* use 1:m because Ritter IPOs include those missing from SDC (hence no cusip)
merge 1:m ncusip6 IPOyear using ${source}\\RitterIPOs, keep(master match using)
gen RitterIPOsonly = (_merge == 2)
gen SDCIPOsonly = (_merge == 1)
gen RitterSDC = (_merge == 3)
drop _merge
* fill in missing mth from RitterIPOs
replace mth = mofd(Offerdate) if mth == .
format mth %tm

la var IPOname "Company name in Ritter"
la var Ticker "Ticker in Ritter"
la var postissueshares "Post-issue shares in Ritter"
la var dualdum "Dual share structure dummy in Ritter"
la var Founding "Company founding year in Ritter"
la var Rollupdum "Rollup offer dummy in Ritter"
la var Offerdate "Offer date in Ritter"

count
* 15,875
count if OfferPrice == .
*  1,598
save ${source}\\RitterSDCIPOs, replace

* merge IPOs with ncusip6 with US common equities in CRSP
use ${source}\\RitterSDCIPOs, clear
* same IPO in SDC and Ritter has different ncusip in two databases
gen IPOdate = Offerdate
replace IPOdate = IssueDate if IPOdate == .
format IPOdate %td
la var IPOdate "Issue date from Ritter, if missing from SDC Offerdate"

gen IPOticker = Ticker
replace IPOticker = TickerSymbol if IPOticker == ""
la var IPOticker "IPO ticker from RItter, if missing from SDC TickerSymbol"

* duplicates IPOs in the same month with same ticker
gsort IPOdate IPOticker -RitterIPOsonly
gen IPOmth = mofd(IPOdate)
format IPOmth %tm
capture drop rep
duplicates tag IPOmth IPOticker if IPOticker != "", gen(rep)
count if rep>=1  & rep != .
* 926

gsort IPOmth IPOticker -RitterIPOsonly
gen IPOprice = OfferPrice
la var IPOprice "IPO price from SDC"
* fill in missing IPO price
foreach v in FilingDate IssueDate TickerSymbol IPOsize OfferPrice IPOprice {
		replace `v' = `v'[_n + 1] if rep == 1 & IPOprice == . & IPOticker == IPOticker[_n+1]  &  IPOmth == IPOmth[_n + 1] & IPOticker != ""
}

* (453 real changes made)
duplicates drop IPOmth IPOticker if IPOticker != "", force
* (464 observations deleted)

capture drop rep
duplicates tag IPOmth IPOticker if IPOticker != "", gen(rep)
count if rep>=1  & rep != .
* 0
capture drop rep


sort IPOmth IPOticker
keep if ncusip6 != ""
count if IPOprice == .
* 1,132

* IPOs without ncusip6 cannot be matched on permno either
rename permno permno_Ritter
merge 1:1 ncusip6 mth using ${source}\\crsp_msf_processed1.dta, keep(match) keepusing(permno permco hsiccd comnam) nogen

* replace permno with permno_Ritter if nonmissing and different
replace permno = permno_Ritter if !missing(permno_Ritter) & permno != permno_Ritter
* 10 changed

count if OfferPrice == .
*  215: in Ritter only. Should try to fill in missing offerprice from SCOOP
count if SDCIPOsonly == 1
* 752: in SDC only, perhaps Ritter cannot find the founding year of the firm
sort IPOyear
save ${source}\\temp1, replace

* ----------------------------------------------------------------------------
* (5) import SCOOP to fill in missing IPO prices (drop 112 IPOs without price in the end, out of about 10k)
* ----------------------------------------------------------------------------

* Fill in missing offerprice from SCOOP

import excel ${source}\\SCOOP-Rating-Performance.xls, sheet("SCOOP Scorecard") cellrange(A36:L3757) firstrow clear
* drop non-data rows between years
drop if strlen(Date) < 9
* (105 observations deleted)
gen IPOdate_SCOOP = date(Date, "DMY")
format IPOdate_SCOOP %td
gen IPOmth = mofd(IPOdate_SCOOP)
format IPOmth %tm
rename Symbol IPOticker
la var Issuer "Issuer in SCOOP"

* 3 pairs of duplicates, drop
gsort IPOticker IPOmth -IPOdate
duplicates drop IPOticker IPOmth, force

keep IPOticker IPOmth IPOdate_SCOOP Price Issuer 
* use 1 to many because using file has empty IPOticker
merge 1:m IPOticker IPOmth using ${source}\\temp1, keep(match using)

count if _merge == 3 & IPOprice == .
destring Price, replace
replace IPOprice = Price if _merge == 3 & IPOprice == .
* (93 real changes made)

count
* 9,962
count if IPOprice == .
*  122

keep comnam FilingDate FilingDate IPOsize IPOmth postissueshares dualdum Founding Rollupdum IPOdate IPOprice permno permco hsiccd

sort IPOdate
* var for merging: assume IPOs are priced one month before the listing date; merge the previous month to IPO mth  (comparable companies' stock price information must be avaible at the time of training)
gen mth = IPOmth
format mth %tm
save ${source}\\temp, replace

* ----------------------------------------------------------------------------
* (6) nearmrg with CRSP daily on IPOdate (date); obtain IPO initial return and closing market cap on the first trading day
* ----------------------------------------------------------------------------

use ${source}\\crsp_daily.dta, clear
sort permno date PRC SHROUT
duplicates drop permno date, force
save ${source}\\crsp_daily.dta, replace

use ${source}\\crsp_daily.dta, clear
gen IPOdate = date
nearmrg permno using ${source}\\temp, nearvar(IPOdate) keep(master match) lower type(1:m) genmatch(IPOdate_raw) limit(183)
tab _merge
format IPOdate %td
sort permno date
gen dist = abs(IPOdate_raw - date)

count if IPOdate_raw == date
* 5,241
distinct permno
*  9937

* drop if no price
drop if missing(PRC)
* 1,140 observations deleted)

sort permno IPOdate_raw dist
duplicates drop permno IPOdate_raw, force
count
* 9,759
sum dist
* max = 35
duplicates tag permno, gen(rep)
count if rep >= 1
* 50
count if missing(IPOprice)
* 122
drop if missing(IPOprice)
* (122 observations deleted)
 count if missing(PRC)
* 0

gen initial_ret = abs(PRC) / IPOprice - 1

sum initial_ret, detail
gen value = abs(PRC) * SHROUT
keep permno date IPOdate_raw initial_ret value IPOmth FilingDate IPOsize IPOprice ewretd vwretd SHRCD mth
ren IPOdate_raw IPOdate
ren SHRCD shrcd
ren date ftdate
la var ftdate "First trading date after IPO"
la var initial_ret "IPO initial return, first-day closing price/IPO price-1"
* create first trading month to merge with CRSP
replace mth = mofd(ftdate)
la var mth "First trading month after IPO"
ren value ftdvalue
la var ftdvalue "First trading day closing market capitalisation (abs(prc) * shrout)"
* create IPO pricing month to merge with accounting data for ML
gen IPOprcmth = IPOmth - 1
format IPOprcmth  %tm
la var IPOprcmth "IPO pricing month (IPO month-1)"
* create IPO event month 0
gen IPOeventmth = mofd(ftdate) - 1
format IPOeventmth %tm
save ${source}\\IPOs_all, replace

* assign new economy dummy
use ${source}\\compustatq_notccm_processed, clear
keep gvkey mth ipodate permno fyr
nearmrg permno using ${source}\\IPOs_all, lower nearvar(mth) type(m:1) keepusing(IPOdate)
drop if _merge == 2
sort gvkey mth
* keep the correct IPOdate: compare IPOmth (from Ritter, SDC and scoop), if <= mth , keep; fill in missing from ipodate from Compustat when mod(ipodate) <=mth
gen IPOmth = mofd(IPOdate)
format IPOmth %tm
replace IPOdate = . if IPOmth >= mth
* (39 real changes made, 39 to missing)
gen IPOdate1 = ipodate if missing(IPOdate) & mofd(ipodate) <= mth
format IPOdate1 %td
replace IPOdate = IPOdate1 if missing(IPOdate)
keep gvkey permno mth IPOdate fyr
rename gvkey gvkeynum
save temp, replace

use valuation_data_all_blocks, clear
merge 1:1 gvkeynum mth using temp, keep(master match) nogen
* fill forward the missing values because compustat is quarterly but valuation data are monthly
sort gvkeynum mth
by gvkeynum: replace IPOdate = IPOdate[_n -1] if missing(IPOdate)
by gvkeynum: replace fyr = fyr[_n -1] if missing(fyr)

* P18. Barth, Li and McClure (2021) "Prior research identifies the technology industry,
*loss, and newer cohorts of firms as emblematic of the new economy (Collins et al. 1997; Francis
*and Schipper 1999; Core et al. 2003; Srivastava 2014). Consistent with these characteristics, we
*classify a firm as a New Economy firm ""
* (a) if it is in a technology industry 
* or (b) had its IPO in 1971 or later and reported a loss in the year of its IPO.
*Technology firms are those in three-digit SIC industries with large unrecognized intangible assets, i.e., industries
* 283, 357, 360-368, 481, 737, and 873 (Francis and Schipper 1999; Core et al. 2003), which include computer
* hardware and software, pharmaceuticals, electronic equipment, and telecommunications. 
gen sic3 = int(sicn / 10)
gen tech = (sic3 == 283 | sic3 == 357 | (sic3 >= 360 & sic3 <=368) | sic3 == 481 | sic3 == 737 | sic3 == 873 )

* P18. Barth, Li and McClure (2021). "Loss firms have negative earnings. The year of a firm's IPO would be, e.g., 2012 (2013) for a firm that has its IPO on May 12, 2012 and has a December (March) 31 fiscal year."
* absolute distance in days from IPO
gen dist = abs(datadate - IPOdate)
sort gvkeynum dist
by gvkeynum: gen n = _n
gen loss = 1 if (year(IPOdate) >= 1971 & !missing(IPOdate) & ni_ac < 0 & n == 1)
* fill in missing loss key if the same gvkey and IPOdate
by gvkeynum: replace loss = loss[_n -1] if missing(loss) & IPOdate == IPOdate[_n - 1]
* other loss set to 0
replace loss = 0 if missing(loss)
gen Neweconomy = (tech | loss)

* P24 Barth, Li and McClure (2021)."Table 4 presents descriptive statistics and value relevance of accounting amounts for New Economy, Old Economy Profit, and Old Economy Loss firms from 1971 to 2018, which comprise 81,569, 129,795, and 25,714 observations." 34% obs in BLM are new economy firms. 31% in ours are new economy firms.
sum Neweconomy
sort gvkeynum mth Neweconomy
keep gvkeynum mth Neweconomy
gen Oldeconomy = 1 - Neweconomy
save neweconomy, replace
