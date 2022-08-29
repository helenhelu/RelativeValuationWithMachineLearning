#!/usr/bin/env python

# coding: utf-8

# Code for "Relative Valuation with Machine Valuation", Geertema and Lu (2022)
# Copyright (C) Paul Geertsema and Helen Lu 2019 - 2022

# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the 
# Free Software Foundation, either version 3 of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.


#---------------------------------------------------------------------------------------------------------
#  Processing Functions
#---------------------------------------------------------------------------------------------------------
import numpy as np
import pandas as pd
from scipy import stats
import datetime as dt
import lightgbm as lgb
from sklearn.metrics import (mean_absolute_error, mean_squared_error, median_absolute_error)
import statsmodels.api as sm

# project directories
DATAFILE = 'valuation_data_filtered_blocks.dta'
PG = 1

if PG == 1:
    DATA = 'D:/Data/Valuation/Work/'
    RESULTS = 'C:/Paul/Dropbox/Valuation/results/'
    CODE = 'C:/Paul/Dropbox/Valuation/MLCode'

if PG != 1:
    RESULTS = 'C:/Users/Helen/Dropbox/Valuation/results/'
    CODE = 'C:/Users/Helen/Dropbox/Valuation/MLCode'
    DATA = 'E:/data/Valuation/Work/'



import os
os.chdir(CODE)
from mvutils import (make_colvec, make_value, mean_absolute_percentage_error, mean_absolute_log_percentage_error, 
    median_absolute_percentage_error, median_absolute_log_percentage_error)

###### READ DATA ######
def get_data(source):
    df = pd.read_stata(source)
    print("Read "+source+":", len(df), len(df.columns))
    return df


def fix_categoricals(df, categoricals):
    # categorical variables need to be stored as ints (LightGBM)
    for x in categoricals:
        # note, LightGBM interpret negative categorical ints as missing
        df[x] = df[x].fillna(-1).astype('int64')
    return df
   

def drop_target_na(df, target):
    df.dropna(subset=df[[target]].columns, inplace=True)
    return df


def split_data(df, target, features, train_start, train_end, dev_start, dev_end, test_start, test_end, train_blocks, dev_blocks, test_blocks):
    ''' splits data into train, dev and test using period boundaries and cross-sectional blocks (inclusive boundaries) '''
    
    # cross-sectional range is 0 to 100, integer only
    # currently use 5 equal sized blocks as defined below

    # blocks is a dictionary of non-overlapping cross-sectional ranges
    block_hash = {}

    block_hash[1] = range(0,20)
    block_hash[2] = range(20,40)
    block_hash[3] = range(40,60)
    block_hash[4] = range(60,80)
    block_hash[5] = range(80,100)
    block_hash[6] = range(100,101)

    train_hash_set = set()
    for block_number in train_blocks:
        train_hash_set = train_hash_set | set(block_hash[block_number])

    dev_hash_set = set()
    for block_number in dev_blocks:
        dev_hash_set = dev_hash_set | set(block_hash[block_number])

    test_hash_set = set()
    for block_number in test_blocks:
        test_hash_set = test_hash_set | set(block_hash[block_number])

    # first filter for the correct time-series ranges
    train  = df.loc[(df['month'] >= train_start) & (df['month'] <= train_end) ]
    dev    = df.loc[(df['month'] >= dev_start)   & (df['month'] <= dev_end)   ]
    test   = df.loc[(df['month'] >= test_start)  & (df['month'] <= test_end)  ]

    # then filter for the correct cross-sectional ranges
    train  = train[train['hash100'].isin(list(train_hash_set))]
    dev    =     dev[dev['hash100'].isin(list(dev_hash_set))]
    test   =   test[test['hash100'].isin(list(test_hash_set))]

    d = {}
    
    d['y_train']  = train[target]
    d['X_train']  = train[[x for x in features]]
    d['id_train'] = train[['gvkeynum', 'mth']]
                         
    d['y_dev']    = dev[target]
    d['X_dev']    = dev[[x for x in features]]
    d['id_dev']   = dev[['gvkeynum', 'mth']]

    d['y_test']   = test[target]
    d['X_test']   = test[[x for x in features]]
    d['id_test']  = test[['gvkeynum', 'mth']]
        
    print('y_train : ', len(d['y_train']), train_start, train_end, train_blocks)
    print('X_train : ', len(d['X_train']), train_start, train_end, train_blocks)
    print('y_dev   : ', len(d['y_dev']),   dev_start,   dev_end,   dev_blocks)
    print('X_dev   : ', len(d['X_dev']),   dev_start,   dev_end,   dev_blocks)
    print('y_test  : ', len(d['y_test']),  test_start,  test_end,  test_blocks)
    print('X_test  : ', len(d['X_test']),  test_start,  test_end,  test_blocks)
    
    del train
    del dev
    del test
    
    return d


def lgb_data(d, categoricals):
    # ADD categorical_feature=['sic'] - see https://lightgbm.readthedocs.io/en/latest/Python-Intro.html#training
    # categorical features must be of type int
    D_train = lgb.Dataset(d['X_train'], label=d['y_train'], free_raw_data=False,  categorical_feature=categoricals)
    D_dev   = lgb.Dataset(d['X_dev'],   label=d['y_dev'],   free_raw_data=False,  categorical_feature=categoricals)
    
    return D_train, D_dev


def remove_outlier_targets(target, features, sd=2):
    
    ''' drop outliers withing x standard deviation from columns in columns '''

    drop_condition = (np.abs(stats.zscore(target)) < sd)    
    print('before target',len(target))
    print('before features',len(features))

    newtarget = target[drop_condition]
    newfeatures = features[drop_condition]
    
    print('after target',len(newtarget))
    print('after features',len(newfeatures))
    
    return newtarget, newfeatures

def calc_predictions(model, d, scalevar, debtvar, target):

    p = {} # contains predictions, both of target and converted value via scaling variable

    # predict

    p['y_train_hat'] = make_colvec(model.predict(d['X_train']))
    p['y_dev_hat']   = make_colvec(model.predict(d['X_dev']))
    p['y_test_hat']  = make_colvec(model.predict(d['X_test']))
   
    # reshape to numpy column vector
    y_train_np  = make_colvec(d['y_train'])
    y_dev_np    = make_colvec(d['y_dev'])
    y_test_np   = make_colvec(d['y_test'])
    
    c_train     = make_colvec(d['X_train'][scalevar])
    c_dev       = make_colvec(d['X_dev'][scalevar])
    c_test      = make_colvec(d['X_test'][scalevar])
    
    d_train     = make_colvec(d['X_train'][debtvar])
    d_dev       = make_colvec(d['X_dev'][debtvar])
    d_test      = make_colvec(d['X_test'][debtvar])
    
    # also record actuals (as numpy column vectors), used for performance evaluation
    p['y_train'] = y_train_np
    p['y_dev']   = y_dev_np
    p['y_test']  = y_test_np

    # create value predictions
    p['y_train_value_hat'] = make_value(p['y_train_hat'], c_train, d_train, target)
    p['y_dev_value_hat']   = make_value(p['y_dev_hat'],   c_dev,   d_dev,   target)
    p['y_test_value_hat']  = make_value(p['y_test_hat'],  c_test,  d_test,  target)
    
    p['y_train_value']     = make_value(y_train_np,  c_train,  d_train, target)
    p['y_dev_value']       = make_value(y_dev_np,    c_dev,    d_dev,   target)
    p['y_test_value']      = make_value(y_test_np,   c_test,   d_test,  target)

    # POST CONDITION:
    # y_*_value  now refers to value (valuation of firm)
    # for train, dev and test, for both true and estimated (_hat)

    print([x for x in p])
    return p


# Performance evaluation
def performance_evaluation(p, value):
        ''' 
        calculates a dictionary of performance evaluation metrics, based on input dictionary
        obtained from calc_predictions
        if value is true, the predictions are framed in terms of value
        otherwise based on target variable
        '''

        # dictionary containing results
        results = {}
        
        # for each dataset...
        for ds in ['train', 'dev', 'test']:
            
            if not value:
                y     = p['y_'+ds] 
                y_hat = p['y_'+ds+'_hat']
            else:
                y     = p['y_'+ds+'_value']
                y_hat = p['y_'+ds+'_value_hat']

            results['mae_'+ds]    = mean_absolute_error(y, y_hat)
            results['med_'+ds]    = median_absolute_error(y, y_hat)
            results['mape_'+ds]   = mean_absolute_percentage_error(y, y_hat)
            results['malpe_'+ds]  = mean_absolute_log_percentage_error(y, y_hat)
            results['mdalpe_'+ds] = median_absolute_log_percentage_error(y, y_hat)
            results['mdape_'+ds]  = median_absolute_percentage_error(y, y_hat)
            results['rmse_'+ds]   = np.sqrt(mean_squared_error(y, y_hat))
            results['med_'+ds]    = median_absolute_error(y, y_hat)
            results['r2_'+ds]     = (np.corrcoef(y.ravel(), y_hat.ravel())[1,0])**2
            
            # t-stats of coefficient from regressing y on predicted y
            tstats = sm.OLS(y, sm.add_constant(y_hat), missing='drop', hasconst='true').fit().tvalues
            
            # handle cases where no valid t-stats can be obtained
            t = tstats[1] if len(tstats) > 1 else 0
            
            results['tstat_'+ds] = t
                
        return results


def output_predictions(filename, datasets, pred):
    ''' output actual and predicted value and raw targets '''
    print(filename, type(filename))
    print("----------------------")

    # assemble training dataset
    #         true value,        predicted value,         true y,            predicted y,       features

    pr = {}

    for ds in ['train', 'dev', 'test']:
        
        print('==== now doing '+ds)

        ids = datasets['id_'+ds]

        value_true = pd.Series(pred['y_'+ds+'_value'].ravel())
        value_true.rename('value_true', inplace=True)

        value_pred = pd.Series(pred['y_'+ds+'_value_hat'].ravel())
        value_pred.rename('value_pred', inplace=True)

        y_true = pd.Series(pred['y_'+ds].ravel())
        y_true.rename('y_true', inplace=True)

        y_pred = pd.Series(pred['y_'+ds+'_hat'].ravel())
        y_pred.rename('y_pred', inplace=True)
      
        ds_list = [ids, value_true, value_pred, y_true, y_pred] 

        for x in ds_list:
            # reset index
            x.index = range(len(x.index))

        new_col_names = [x for x in ids.columns] + ['value_true', 'value_pred', 'y_true', 'y_pred']
        # see https://pandas.pydata.org/pandas-docs/stable/user_guide/merging.html
        pr[ds] = pd.concat(ds_list, axis=1, ignore_index=True, sort=False)

        pr[ds].columns = new_col_names

        pr[ds]['gvkeynum'] = pr[ds]['gvkeynum'].astype('int64')

        print(ds, len(y_true), len(pr[ds]))

        pr[ds].to_stata(filename+"_"+ds+".dta")
        
        print("predictions saved at : ", filename+"_"+ds+".dta")


def create_results_context(model, X_train, comment, target, target_results, value_results, 
                           booster_param, training_param, target_outlier_sd):
    context = {}

    context['time'] = str(dt.datetime.now())
    context['comment'] = comment
    print("in create_results_context", "comment: ", comment, "target :", target)
    context['target'] = target

    model_detail = {}
    model_detail['modeltype'] = type(model)
    
    if hasattr(model, 'best_iteration'):
        model_detail['iterations'] = model.best_iteration
    else:
        model_detail['iterations'] = 0

    if target_outlier_sd is None:
        model_detail['target_outlier_sd'] = "None"
    else:
        model_detail['target_outlier_sd'] = target_outlier_sd

    predict_variables = {}
    predict_variables['predictors'] = "|".join(X_train.columns)

    combined_results = [
        context,
        target_results,
        value_results,
        model_detail,
        booster_param,
        training_param,
        predict_variables
    ]
       
    return combined_results

def output_results(results, filename):
    ''' appends results dictionary to file '''
    with open(filename,"a") as file:

        # headers
        for dictionary in results:
            for entry in dictionary:
                #print(entry)
                file.write(entry+"|")        
        file.write("\n")

        # values
        for dictionary in results:
            for entry in dictionary.values():
                #print(entry)
                if isinstance(entry, str):
                    file.write(entry+"|")
                else:
                    file.write(str(entry)+"|")
        file.write("\n")
        file.close()

