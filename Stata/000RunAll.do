* ----------------------------------------------------------------------------
* RunAll
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

*-----------------------------------------------------------------------------
* Definitions
*-----------------------------------------------------------------------------

* enable debugmode (small datasets)
global debugmode = 0

* set mrun to "filtered"
global mrun filtered

* check which machine code is running on
* then set file locations accordingly

* helen local computer
capture confirm file "c:\helen.txt"
if _rc==0 {
	global code    C:\Users\Helen\Dropbox\\Valuation\Stata
	global source  D:\data\Valuation\source
	global work    D:\data\Valuation\work
	global results C:\Users\Helen\Dropbox\\Valuation\results2\
	global activate C:/Users/Helen/Anaconda3/Scripts/activate
	global python "C:/Users/Helen/anaconda3/envs/valuation/python.exe"
	global pythonenvir "conda activate valuation"
	global pythoncode "C:/Users/Helen/Dropbox/Valuation/MLCode/ValuationGBM.py"
	global pythontreecode "C:/Users/Helen/Dropbox/Valuation/MLCode/ValuationTree.py"
	global peerpythoncode "C:/Users/Helen/Dropbox/Valuation/MLCode/PeerGroup.py"
}

* paul local computer
capture confirm file "C:\Paul\paul.txt"
if _rc==0 {
	global code    C:\Paul\Dropbox\Valuation\Stata
	global source  D:\data\Valuation\source
	global work    D:\data\Valuation\work
	global results C:\Paul\Dropbox\Valuation\results\
	global activate C:/ProgramData/Anaconda3/Scripts/activate
	global python "C:/Users/Paul/.conda/envs/valuation/python.exe"
	global pythonenvir "conda activate valuation"
	global pythoncode "C:/Paul/Dropbox/Valuation/MLCode/ValuationGBM.py"
	global pythontreecode "C:/Paul/Dropbox/Valuation/MLCode/ValuationTree.py"
	global peerpythoncode "C:/Paul/Dropbox/Valuation/MLCode/PeerGroup.py"	
}

cd ${work}

* load utility routines
include ${code}\Utils.do

* 1980m1 = 240
global startperiod 240

* decade boundaries
global Decade1980start = tm(1980m1) 
global Decade1980end   = tm(1989m12)
global Decade1990start = tm(1990m1)
global Decade1990end   = tm(1999m12)
global Decade2000start = tm(2000m1)
global Decade2000end   = tm(2009m12)
global Decade2010start = tm(2010m1)
global Decade2010end   = tm(2019m12)

* 2019m12 = 719
global endperiod = tm(2019m12)

* datecutoff is used to generate the master dataset for ML and RRV and BG
global datecutoff (mth >= tm(1980m1) & mth <= tm(2019m12))

* variables used in Bartram and Grinblat (2018)
* See appendix B, 145
global bg_bsitems at seq icapt teq pstkr ppent ceq pstk dltt ao lt lo che aco lco ap

* income statement items with y2d, to fill in missing before obtaining rolling 4-q sums
global bg_y2ditems dvp sale ib ni xido ibadj ibcom pi txt nopi do
global bg_cfitems dv

* datecutoff used for BG regressionss
global bg_datecutoff (mth >= tm(1980m1) & mth <= tm(2019m12))

* models in main text
global models_main ML_lnm2b ML_lnv2a ML_lnv2s BL_m2b BL_v2a BL_v2s IND_m2b IND_v2a IND_v2s HP_m2b HP_v2a HP_v2s RRV BG 

* all models
global models ML_lnm2b ML_lnv2a ML_lnv2s ML_m ML_lnm ML_m2b BL_m2b BL_v2a BL_v2s IND_m2b IND_v2a IND_v2s HP_m2b HP_v2a HP_v2s RRV BG Tree_lnm2b Tree_lnv2a Tree_lnv2s AS_lnm2b AS_lnv2a AS_lnv2s

* python ML code launcher
capture program drop lauchMLcode
program lauchMLcode
	version 16
	
	syntax anything
	di "`anything'"
	
	local cmd1 `"${activate}"'
	local cmd2 `"${pythonenvir}"'
	local cmd3 `"${python} ${pythoncode} `anything'"'
	
	di `"Command passed to Operating Sytem : `cmd1' && `cmd2' && `cmd3'"'
	shell `cmd1' && `cmd2' && `cmd3'
	
end


* python ML code launcher for Tree predictor
capture program drop lauchTreecode
program lauchTreecode
	version 16
	
	syntax anything
	di "`anything'"
	
	local cmd1 `"${activate}"'
	local cmd2 `"${pythonenvir}"'
	local cmd3 `"${python} ${pythontreecode} `anything'"'
	
	di `"Command passed to Operating Sytem : `cmd1' && `cmd2' && `cmd3'"'
	shell `cmd1' && `cmd2' && `cmd3'
	
end


*-----------------------------------------------------------------------------
* Data preparation
*-----------------------------------------------------------------------------

* Clean compustat quarterly data (not CCM)
do ${code}\\010CompustatqClean.do

* Prepare data for ML models
do ${code}\\030DataPrep.do

* Clean IPO data, merge with compustatq_notccm_processed from CompustatqClen.do to generate an indicator variable for Neweconomy
do ${code}\\035IPOdataNeweconomy.do

*-----------------------------------------------------------------------------
* Classic models
*-----------------------------------------------------------------------------

do ${code}\\040BartramRegressions.do
do ${code}\\050RRV.do
do ${code}\\060BL.do
do ${code}\\070LNT.do
do ${code}\\075HP.do

* run ML model code for each target 
foreach t in lnm2b lnv2a lnv2s m2b m lnm {
	di "DOING: lauchMLcode ${mrun} valuation_${mrun}.dta `t' Base"
	lauchMLcode ${mrun} valuation_${mrun}.dta `t' Base
}

* run **Tree** model code for each target
foreach t in lnv2a lnv2s lnm2b {
	di "DOING: lauchTreecode ${mrun} valuation_${mrun}.dta `t'"
	lauchTreecode ${mrun} valuation_${mrun}.dta `t' 
}

* run ML model code for each target (**ON BL DATA**)
foreach t in lnm2b lnv2a lnv2s {
	di "DOING: lauchMLcode ${mrun} valuation_${mrun}.dta `t' BLVars"
	lauchMLcode ${mrun} BLdata_${mrun}.dta `t' BLVars
}

* run ML model code for using alternative splits (80%:0%:20%)
foreach t in lnm2b lnv2a lnv2s {
	di "DOING: lauchMLcode ${mrun} valuation_${mrun}.dta `t' AltSplit"
	lauchMLcode ${mrun} valuation_${mrun}.dta `t' AltSplit
}

* (re-)load utility routines
include ${code}\Utils.do

do ${code}\\080LoadMLPredictions.do
do ${code}\\085CombinePredictions.do
do ${code}\\100EvaluatePerformance.do
do ${code}\\102EvaluatePerformanceInternet.do
do ${code}\\103EvaluatePerformanceSubsamples.do

do ${code}\\105VariableImportanceData.do
do ${code}\\110Graphs.do
do ${code}\\115GraphsSub.do

do ${code}\\120VariableImportanceResults.do
do ${code}\\125VariableImportanceSub.do

do ${code}\\130Predictability.do
do ${code}\\150AppendixVariables.do
do ${code}\\160BenchmarkModelEstimations.do

global mrun filtered
do ${code}\\170ReconciliationModels.do
do ${code}\\180ReconciliationResults.do

* Peer weight code
do ${code}\\200Leaves.do
do ${code}\\201ExamplePeerFirms.do





