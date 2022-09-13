* ----------------------------------------------------------------------------
* Categories
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


* Category definitions
* execute using -include- instead of -do- so that 
* local variables defined here remain available for use


local CAPMbeta       CAPMbeta
local Capitalisation capital_ratio_wr equity_invcap_wr debt_invcap_wr totdebt_invcap_wr
local Efficiency     opleverage_an at_turn_wr invturn_wr pay_turn_wr rect_turn_wr assetturnover_an sales2cash_an sales2rec_an sales2inv_an pchsales2inv_an pchsale2pchinvt_an pchsale2pchrect_an pchgm2pchsale_an pchsale2pchxsga_an assetturnover2_an 
local Financial_soundness invt_act_wr rect_act_wr  fcf_ocf_wr ocf_lct_wr  cash_debt_wr cash_lt_wr short_debt_wr profit_lct_wr curr_debt_wr debt_ebitda_wr dltt_be_wr int_debt_wr int_totdebt_wr lt_debt_wr lt_ppent_wr Accrual_wr
local Growth         rd_sale_wr salesgrowth_an inventorygrowth_an inventorychange_an capexgrowth_an assetgrowth_an chlt_an chceq_an chca_an chcl_an chnccl_an chfnl_an chbe_an investment_an deprn_an pchdeprn_an  bookequitygrowth_an
local Industry       industry
local Liquidity      cash_conversion_wr cash_ratio_wr curr_ratio_wr quick_ratio_wr liquid2assets_an cash2assets_an chcurrentratio_an pchquickratio_an
local Profitability  efftax_wr gprof_wr aftret_eq_wr aftret_equity_wr aftret_invcapx_wr cfm_wr gpm_wr npm_wr opmbd_wr opmad_wr pretret_earnat_wr pretret_noa_wr ptpm_wr roa_wr roce_wr roe_wr grossmargin_an grossprofit_an profitability_an roic_an marginch_an ebitda2revenue_an
local Size           book sale_ac assets debt_book_value
local Solvency       de_ratio_wr debt_assets_wr debt_at_wr debt_capital_wr intcov_wr intcov_ratio_wr cf2debt_an debt2tang_an
local Payout	     dpr_wr

local categories CAPMbeta Capitalisation Efficiency Financial_soundness Growth Industry Liquidity Profitability Size Solvency Payout