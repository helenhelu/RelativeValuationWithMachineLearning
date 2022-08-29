* ----------------------------------------------------------------------------
* CompustatqClean
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

*------------------------------------------------------------------------
* (1) clean compustat quarterly and merge in permno
*------------------------------------------------------------------------

use ${source}\\compustatq.dta, clear

destring gvkey, replace

if "${debugmode}" == "1" {
	keep if (datadate >= td(01jan2005)) & (mod(gvkey,12) == 2)
}

* ----------------------------------
* 	Compustat Quarterly file PART 1
* ----------------------------------

* drop long strings to save space
drop conm add1 add2 add3 add4 busdesc city conml county phone
compress


* duplicates are due to change in balancesheet date, leading to overlap (1,135 observations deleted)
duplicates drop gvkey datadate, force

duplicates report gvkey datadate

*--------------------------------------
*   copies | observations       surplus
*----------+---------------------------
*        1 |      1816831               0
*--------------------------------------

*------------------------------------------------------------------------------
* Time indices: must be done before merging in permno
* mth is use to merge in CRSP and permno
*------------------------------------------------------------------------------

* accounting month
gen acc_mth = mofd(datadate)
format acc_mth %tm
la var acc_mth "Balance sheet date month"

gen fyear = year(dofm(acc_mth))
format fyear %ty
la var fyear "Year of balance sheet date"

* prediction month (for returns 4 months after balance sheet date, 
* available 3 months after balance sheet date)
* following Hou, Xue & Zhang (2018)

gen mth = acc_mth + 3
format mth %tm
la var mth "Firm value month (at least 4 months after balance sheet date)"

gen year = year(dofm(mth))
format year %ty
la var year "Year of firm value (predictor available)"  

*---------------------------------------------------------------
* link in permno from gvkey permno daily link; created from Compustatcrsplink file, keep primary links, filled to daily
*---------------------------------------------------------------

* daily date of data availability
gen date = dofm(mth)
format date td
la var date "Date of firm value (predictor availabilty)"
merge 1:1 gvkey date using ${source}\\gvkeypermno, keep(master match) nogen keepusing(permno permco)


* sort order is needed for time-series calculations
sort gvkey mth datadate

* follows Davis, Fama and French (2000), table 1 definitions
* modified for quarterly data as per Chen, Novy-Marx and Zhang (2011) (ssrn)

* [sh_book_equity] *
gen double sh_book_equity = .

* seq = "Stockholders Equity - Parent" (old data 216)
replace sh_book_equity = seqq if sh_book_equity == .
* ceq = "Common/Ordinary Equity - Total" (old data 60)
* pstk = "Preferred/Preference Stock (Capital) - Total" (old data 130)
replace sh_book_equity = ceqq + pstkq if sh_book_equity == .
* at = "Assets - Total"
* lt = "Liabilities - Total"
replace sh_book_equity = atq - ltq if sh_book_equity == .

* [bs_def_tax_and_inv_credit] *

* if ultimately missing, assume zero
gen double bs_def_tax_and_inv_credit = 0
* txditc = "Deferred Taxes and Investment Tax Credit"
replace bs_def_tax_and_inv_credit = txditcq if txditcq != .

* [bv_pref_stock] *

* if ultimately missing, assume zero
gen double bv_pref_stock = 0

* pstkrv = "Preferred Stock - Redemption Value" (old data 56)
* --- DOES NOT EXIST IN QUARTERLY VERSION!

replace bv_pref_stock = pstkrq if bv_pref_stock == 0 & pstkrq != .
* pstkl = "Preferred Stock - Liquidating Value" (old data 10)
* --- DOES NOT EXIST IN QUARTERLY VERSION!

*replace bv_pref_stock = pstkq if bv_pref_stock == 0 & pstkq != .
* pstk = "Preferred/Preference Stock (Capital) - Total" (old data 130)
replace bv_pref_stock = pstkq if bv_pref_stock == 0 & pstkq != .

gen double bookequityq = .
replace bookequityq = sh_book_equity + bs_def_tax_and_inv_credit - bv_pref_stock
la var bookequityq "Book equity of firm as per Davis, Fama and French (2000) (q)"


* --------------------------------------
* sic codes
* --------------------------------------

* 4-digit numeric sic adjusted for historical changes
gen int    sicn  = real(sic)
gen        sic2  = substr(sic,1,2)
gen int    sic2n = real(sic2)


compress

sort gvkey mth datadate
save ${source}\\compustatq_notccm_processed, replace
