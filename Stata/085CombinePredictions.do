* ----------------------------------------------------------------------------
* CombinePredictions
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



* combine with other models

* scaffold for merging
use valuation_data_${mrun}_blocks, clear
keep gvkeynum mth book assets debt_book_value sale_ac
sort gvkeynum mth 

foreach model in $models {
    
	di "merging model `model'"
	merge 1:1 gvkeynum mth using `model'_${mrun}, keep(master match using) nogen keepusing(value_* y_* *_train_mean)
	sort gvkeynum mth 
	
	rename value_pred          value_pred_`model'
	rename value_true          value_true_`model'
	rename y_pred              y_pred_`model'
	rename y_true              y_true_`model'
	rename y_train_mean        y_train_mean_`model'
	rename value_train_mean    value_train_mean_`model'
	rename logvalue_train_mean logvalue_train_mean_`model'
}

* create model errors (used in reporting later on)
foreach v in $models {
	gen err_`v' = ((value_pred_`v' - value_true_`v') / value_true_`v') * 100 
	gen abserr_`v' = ((abs(value_pred_`v' - value_true_`v')) / value_true_`v') * 100 
	
}

* save "lightweight" combined results
save combined_${mrun}, replace

* create "full data" combined results
use valuation_data_${mrun}_blocks, clear
merge 1:1 gvkeynum mth using combined_${mrun}, keep(master match using) nogen keepusing(value_* y_* y_train_mean_* logvalue_train_mean_* err_* abserr_* )

* generate value_true_train from y_true_train as benchmark in OOS R2
save combined_full_${mrun}, replace
