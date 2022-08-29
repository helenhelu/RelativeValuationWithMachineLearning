#!/usr/bin/env python

# coding: utf-8

# Code for "Relative Valuation with Machine Valuation", Geertema and Lu  (2022)
# Copyright (C) Paul Geertsema and Helen Lu 2019 - 2022
print("Valuation project (C) Paul Geertsema and Helen Lu 2019 - 2022")


# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the 
# Free Software Foundation, either version 3 of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

print("Valuation project (C) Paul Geertsema and Helen Lu 2020, 2021")

# project directories
DATAFILE = 'valuation_data_filtered_blocks.dta'
PG = 1

if PG == 1:
    RESULTS = 'C:/Paul/Dropbox/Valuation/results/'  
    CODE = 'C:/Paul/Dropbox/Valuation/MLCode'
    DATA = 'D:/Data/Valuation/Work/'

if PG != 1:
    RESULTS = 'C:/Users/Helen/Dropbox/Valuation/results/'
    CODE = 'C:/Users/Helen/Dropbox/Valuation/MLCode'
    DATA = 'E:/data/Valuation/Work/'

# import standard packages
from re import M
import numpy as np
import pandas as pd
from sklearn.tree import DecisionTreeRegressor
from sklearn.impute import SimpleImputer
from sklearn.metrics import mean_squared_error

import os
import random
import sys

# import mv project packages
os.chdir(CODE)
from mvprocessing import (calc_predictions,
    drop_target_na,    get_data,    output_predictions,    split_data
)

# dictionary containing the correct scaling variable for each possible target
scale_dict = {
    'lnm2b' : 'book',
    'lnv2a' : 'assets',
    'lnv2s' : 'sale_ac',
    'm2b'   : 'book',
    'm'     : 'unit',
    'lnm'   : 'unit',
}

if len(sys.argv) == 4:
    
    # run with arguments
    print('run in shell')

    filter   = sys.argv[1]
    filename = sys.argv[2]
    target   = sys.argv[3]
    
    if target in scale_dict:
        scale = scale_dict[target]
    else: 
        print(f"unrecognised target = {target}")
        input("Press Enter to continue...")

    print(f"filter = {filter} datafile = {filename} target = {target} scale = {scale}")

elif len(sys.argv) == 1:

    # being run inside dev environment
    print('run from dev environment')

    # lauchMLcode filtered BLdata_filtered.dta lnm2b
    filter   = 'filtered'
    filename = 'valuation_filtered.dta'
    target   = 'lnm2b'
    scale    = 'book'

    if target in scale_dict:
        scale = scale_dict[target]
    else: 
        print(f"unrecognised target = {target}")
        input("Press Enter to continue...")
    
    print(f"filter = {filter} datafile = {filename} target = {target} scale = {scale}")

else:
    print(f"You supplied incorrect arguments {sys.argv}")

# input("Press Enter to continue...")


print("Starting Valuation")
print("Using DecisionTreeRegressor from Scikit Learn")

#---------------------------------------------------------------------------------------------------------
#  Main Loop
#---------------------------------------------------------------------------------------------------------

def main_loop(df, comment, target, featureset, scalevar, debtvar, save_predictions, predictions_filename,  this_month, this_block):
    print('')
    print('Main loop')
    print('target : ', target)
    print('comment=', comment, 'scalevar=', scalevar, 'debtvar=', debtvar, 'this_month=', this_month, 'this_block=', this_block)
    # print('featureset:', featureset)

    print("orig df : (cols, rows) = ", len(df.columns), len(df))

    # --- data splitting

    assert(this_block >=1 and this_block <=5)

    blocks = {1,2,3,4,5}
    test   = {this_block}
    dev    = set(random.sample(list(blocks - test), 1))
    train  = blocks - test - dev

    assert(blocks == train | dev | test)

    datasets = split_data(df=df, target=target, features=featureset, 
                       train_start  = this_month-0,           train_end = this_month-0,
                       dev_start    = this_month-0,           dev_end   = this_month-0,
                       test_start   = this_month+0,           test_end  = this_month+0, 
                       train_blocks = train,  
                       dev_blocks   = dev, 
                       test_blocks  = test)

  
    ## Find optimal tree depth on validation data (to avoid overfitting)
    dev_mse_list = []

    # validated depths range from 3 to 6 (3,4,5 or 6)
    min_depth = 3
    max_depth = 6
    for depth in range(min_depth, max_depth+1):
        tree = DecisionTreeRegressor(random_state=42, max_depth=depth)
        model = tree.fit(datasets['X_train'], datasets['y_train'])
        y_pred = model.predict(datasets['X_dev'])
        y_true = datasets['y_dev'].to_numpy()
        mse = mean_squared_error(y_true, y_pred)
        #print("depth",depth,"mse",mse)
        dev_mse_list.append(mse)

    print('dev_mse_list', dev_mse_list)
    # remember python lists are base zero, so add min_depth to argmin
    best_depth = np.argmin(dev_mse_list)+min_depth
    print('best_depth', best_depth)

    ## predict with optimal tree depth
    tree = DecisionTreeRegressor(random_state=42, max_depth=best_depth)
    model = tree.fit(datasets['X_train'], datasets['y_train'])

    # should work with any model... 
    predictions = calc_predictions(model=model, d=datasets, scalevar=scalevar, debtvar=debtvar, target=target)
   
    if save_predictions: 
        print("saving predictions to :", DATA + predictions_filename)
        output_predictions(filename=DATA + predictions_filename, datasets=datasets, pred=predictions)
    else:
        print("not saving predictions")
       

# ===========================================================================
# MAIN ML Models
# ===========================================================================

# read data

df = get_data(source=DATA + filename)
print("Length of df = ",len(df))
print(f"doing {target} scale by {scale} in data {filter} ")

# convert categorical variables (industry) to one-hot-encoding representation
# (DecisionTreeRegressor cannot natively deal with categorical values)
one_hot_industry = pd.get_dummies(df['industry'], prefix="ind")
df = pd.concat([df,one_hot_industry],axis=1)
print("Used one-hot-encoding for industry")

# selected features        
scaling          = set(['assets', 'book', 'sale_ac', 'debt_book_value', 'unit'])
ratios           = set([v for v in df.columns if v[-3:] == '_wr'])
anomalies        = set([v for v in df.columns if v[-3:] == '_an'])
industry_dummies = set([v for v in df.columns if v[:4] == 'ind_'])      
auto_featureset  = (industry_dummies | scaling | ratios | anomalies  | set(['CAPMbeta']) )


# drop n/a targets
df = drop_target_na(df=df, target=target)

# impute missing values
imputer = SimpleImputer(strategy='median')
flist = list(auto_featureset)
df[flist] = imputer.fit_transform(df[flist])

#---------------------------------------------------------------------------------------------------------
# Rolling Windows
#---------------------------------------------------------------------------------------------------------

random.seed(42)   # needed for random validation blocks in main_loop
# run name
runname = "Tree"+filter+target

for month_t in range(240, 719+1):
#for month_t in range(717, 717+1):
    for block in range(1, 5+1):

        auto_target = target
        auto_scalevar = scale
        auto_debtvar = 'debt_book_value'
        
        # modified settings
        # filename format is <runname>_<month>_<block>
        auto_comment    = runname+"_"+str(month_t)+"_"+str(block)
        auto_filename   = runname+"_"+str(month_t)+"_"+str(block)
    
        print('auto_comment : ', auto_comment, '; auto_target : ', auto_target, "count of features = ", len(auto_featureset))

        main_loop(df=df, comment=auto_comment, 
                                    target=auto_target, 
                                    featureset=auto_featureset, 
                                    scalevar=auto_scalevar, 
                                    debtvar=auto_debtvar,
                                    save_predictions=True,
                                    predictions_filename=auto_filename, 
                                    this_month=month_t, 
                                    this_block=block)


print("=========================================")
print("Done!")



