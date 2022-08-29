* ----------------------------------------------------------------------------
* Leaves
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


* NOTE: For simple Python code that extracts leaves and calculates "peer weights"
* from LightGBM predictions, see https://github.com/pgeertsema/peerweights

* WARNING: In this code we ASSUME that same prediction implies same leaf; this will not
* always be true, so should not be used in production code. 
* (see reference to python code above)

* Peer weights
global learning_rate = 0.1
local block = 1
forvalues block = 1/5 {
	
	local split train
	use leaves_`block'_`split'.dta, clear
	gen train = 1
	append using leaves_`block'_test.dta
	capture drop y_train_hat
	
	cap ren _0_x _0
	cap drop _0_y

	replace train = 0 if missing(train)
	ren gvkeynum firm
	drop mth
	*** shallow tree test starts here
	* use ${results}\\leaves_HL.dta, replace


	reshape long _, i(firm) j(iteration)
	ren _ tree_pred
	bys iteration: gegen leaf_id = rank(tree_pred), ties(field)
	sort iteration leaf_id
	
	save temp, replace

	* expand the data so that each firm (target firm) has N component firms; 
	use temp, replace

	sum iteration
	local totaltree = `r(max)' + 1

	label var firm "target firm"
	distinct firm if train == 1
	expand `r(ndistinct)'  if train == 1
	local n =  `r(ndistinct)' 
	local max = `totaltree' - 1
	gsort -train iteration leaf_id firm
	gen component= .
	label var component "component firm"
	gsort -train iteration firm
		
	putmata firm = firm leaf_id = leaf_id iteration = iteration if train == 1, replace
	mata {
		n = st_local("n")
		max = st_local("max") 
		c = firm
		c_m = colshape(colshape(c, `n')',1)
		l = (iteration, leaf_id)
		for (i=0; i <= `max' ; i++) {
			
			l_temp = select(l, (l[,1] :== i))
			l_vec_temp = select(l_temp, (0,1))
			l_m_temp = colshape(colshape(l_vec_temp, `n')',1)
			
			if (i == 0) {
				l_m = l_m_temp
			}
			else {
				l_m = l_m \ l_m_temp
			}
		}	
	}
	gen comp_leaf_id = .
	getmata component= c_m comp_leaf_id = l_m, replace force
	gen D = (leaf_id == comp_leaf_id)	
	
	putmata D = D iteration = iteration if train == 1, replace
	distinct firm if train == 1
	local n =  `r(ndistinct)' 
	mata {
		n = st_local("n")
		max = st_local("max")
		one = J(`n',`n',1)
		temp = (iteration, D)
		for (i=0; i <= `max' ; i++) {
			D_temp = select(temp, (temp[,1] :== i))
			D_vec_temp = select(D_temp, (0,1))
			D_m = colshape(D_vec_temp, `n')
			W = D_m :/ (D_m * one)
			W_vec = colshape(W,1)
			if (i == 0) {
				W_m = W_vec
			}
			else {
				W_m = W_m \ W_vec
			}
		}	
	}
	gen rawweight = .
	getmata rawweight = W_m, replace force
	
	* initialising tree 0
	gen predweight = rawweight if iteration == 0
	gen GBMweight = predweight if iteration == 0 
	gen residweight = 1 - GBMweight if firm == component & iteration == 0
	replace residweight = - GBMweight if firm != component & iteration == 0 

	capture drop comp_leaf_id
	* extract matrices

	** extract vectors to make matrices
	* initialising GBMweight, pred and residual matrices
	distinct firm if train == 1
	local n = `r(ndistinct)'
	gsort -train iteration firm component
	putmata firm = firm predweight = predweight  GBMweight = GBMweight residweight = residweight  if iteration == 0 & train == 1, replace

	mata {
		n = st_local("n")
		temp = (firm, predweight, GBMweight, residweight)
		predw0_vector = select(temp, (0,1,0,0))	
		GBMw0_vector = select(temp, (0,0,1,0))
		residw0_vector = select(temp, (0,0,0,1))	
		predw0 =	rowshape(predw0_vector, `n')
		GBMw0 =	rowshape(GBMw0_vector, `n')
		residw0 =	rowshape(residw0_vector, `n')
	
	}

	save train_test, replace

	use train_test, replace
	sum iteration
	local totaltree = `r(max)' + 1
	* calc predweight GBMweight and residweight for later trees
	
	local max = `totaltree' - 1
	distinct firm if train == 1
	local n = `r(ndistinct)'
	
	gsort -train iteration firm component
	putmata iteration = iteration  rawweight = rawweight firm_id = firm if train == 1, replace
		* raw weight matrix for tree 1
		

	mata {
		max = st_local("max")
		n = st_local("n")
		for (c=1; c <= `max'; c++) {
			j = c - 1
			t = c + 1
			temp = (iteration, firm_id, rawweight)
			temp_c = select(temp, (temp[ ,1] :== c))
			raww_vector = select(temp_c, (0,0,1))				
			raww =	colshape(raww_vector, `n')

			if (c == 1) 	{
					residw_comb =colshape(residw0 ,1)
					GBMw_comb = colshape(GBMw0, 1)
					predw_comb = colshape(predw0, 1)
					residw_pre = residw0
					GBMw_pre = GBMw0
				}	
				else {
					j
				}
				
			predw = raww *  (residw_pre)  * ${learning_rate}
			GBMw = GBMw_pre + predw
			k = max( rows(GBMw))
			identity = I(k)
			residw = identity - GBMw
			
			residw_pre = residw
			GBMw_pre = GBMw
			
			predw_comb = predw_comb  \ colshape(predw, 1)
			GBMw_comb = GBMw_comb \ colshape(GBMw, 1)	
			residw_comb = residw_comb \ colshape(residw, 1)						
		}
		
	}

	gsort -train iteration firm component
	getmata predweight= predw_comb GBMweight=GBMw_comb residweight=residw_comb, replace force
	save train_weights_`block', replace
	

	***********************************
	***obtain weights for test sample**
	***********************************
	
	use train_weights_`block', replace

	sum iteration
	local totaltree = `r(max)' + 1
	* generate Pi matrix (i = 1 to totaltree)

	* convert to long format
	distinct firm if train == 1
	local n = `r(ndistinct)'
	distinct firm if train == 0
	local s = `r(ndistinct)'
	gsort -train firm  component iteration 
	putmata  iter = iteration leaf = leaf_id pweight = predweight firm = firm component = component train = train, replace

	mata {	
		totaltree = st_local("totaltree")
		n = st_local("n")
		s = st_local("s")
		max = `totaltree'-1
		for (t=0; t <= max; t++) {
				
			raw = (train, iter, leaf,  firm, component,  pweight)
			temp_train = select(raw, (raw[ ,1] :== 1))
			temp_i = select(temp_train, (temp_train[ ,2] :== t))
			vector_pi = select(temp_i, (0,0,0,0,0,1))
			pi = colshape(vector_pi, `n')
			pi_t = pi'
			
			vector_ltraini = select(temp_i, (0,0,1,0,0,0))
			ltraini = colshape(vector_ltraini, `n')
			ltraini_ns = J(1,`s',ltraini[,1])
			
			temp_test = select(raw, (raw[ ,1] :== 0))
			temptest_i = select(temp_test, (temp_test[,2] :== t))
			vector_li = select(temptest_i, (0,0,1,0,0,0))
			li_ns = J(1,`n',vector_li)
						
			li = (ltraini_ns :== li_ns')
			ones = J(`n', `n', 1)
			li_mean = li :/ (ones * li)
			
			if (t == 0) 	{
				ki = J(1,`s',pi_t[,1])
			}
				else {
				ki = pi_t * li_mean	
			}
			
			
			if (t == 0) 	{
				k_sum  = ki
			}	
				else {
				k_sum = k_sum + ki
			}
		}	
		testid = select(temptest_i, (0,0,0,1,0,0))
		componentid = (colshape(select(temp_i, (0,0,0,0,1,0)), `n') [1,])'
		testweights = (( 0 \ componentid) , (testid' \ k_sum))
		st_matrix("output",testweights)
	}
	matrix weights = output
	* saving weights in a dta file

	putexcel set ${results}\\weights_testblock`block', replace
	putexcel A1 = matrix(weights) 
}
	
	
	
	
	
	
	
	
	
	
	