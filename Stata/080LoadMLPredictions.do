* ----------------------------------------------------------------------------
* LoadMLPredictions
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


*------------------------------------------------------------------------------
* Load predictions from ML 
*------------------------------------------------------------------------------

* load ML model predictions
foreach model in lnv2s lnm2b lnv2a lnm m m2b {

	load_predictions Base${mrun}`model' ${startperiod} ${endperiod}
	keep gvkeynum mth value_* y_* *_train_mean
	sort gvkeynum mth
	save ML_`model'_${mrun}, replace

}


* load AltSplit model predictions
foreach model in lnv2s lnm2b lnv2a {

	load_predictions AltSplit${mrun}`model' ${startperiod} ${endperiod}
	keep gvkeynum mth value_* y_* *_train_mean
	sort gvkeynum mth
	save AS_`model'_${mrun}, replace

}


* load Tree model predictions
foreach model in lnv2s lnm2b lnv2a {

	load_predictions Tree${mrun}`model' ${startperiod} ${endperiod}
	keep gvkeynum mth value_* y_* *_train_mean
	sort gvkeynum mth
	save Tree_`model'_${mrun}, replace

}



