#!/usr/bin/env python

# coding: utf-8

# Code for "Relative Valuation with Machine Valuation", Geertema and Lu (2022)
# Copyright (C) Paul Geertsema and Helen Lu 2019 - 2022
print("Valuation project (C) Paul Geertsema and Helen Lu 2019 - 2022")


# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the 
# Free Software Foundation, either version 3 of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

# project directories
DATAFILE = 'valuation_data_filtered_blocks.dta'
PG = 0

if PG == 1:
    RESULTS = 'C:/Paul/Dropbox/Valuation/results/'  
    CODE = 'C:/Paul/Dropbox/Valuation/MLCode'
    DATA = 'D:/Data/Valuation/Work/'

if PG != 1:
    RESULTS = 'C:/Users/Helen/Dropbox/Valuation/results/'
    CODE = 'C:/Users/Helen/Dropbox/Valuation/MLCode'
    DATA = 'D:/data/Valuation/Work/'

# import standard packages
import numpy as np
import pandas as pd
import lightgbm as lgb
from sklearn.preprocessing import normalize
import os
import random
import gc
import shap
import sys

# import mv project packages
os.chdir(CODE)
from mvprocessing import (calc_predictions,
    create_results_context,    drop_target_na,    fix_categoricals,    get_data,    lgb_data,    output_predictions,    output_results,    performance_evaluation,
    remove_outlier_targets,    split_data
)

# get arguments
# lnm2b lnv2a lnv2s m2b  m    lnm 
# book    assets  sale_ac book unit unit

# dictionary containing the correct scaling variable for each possible target
scale_dict = {
    'lnm2b' : 'book',
    'lnv2a' : 'assets',
    'lnv2s' : 'sale_ac',
    'm2b'   : 'book',
    'm'     : 'unit',
    'lnm'   : 'unit',
}

if len(sys.argv) == 5:
    
    # run with arguments
    print('run in shell')

    filter     = sys.argv[1]
    filename   = sys.argv[2]
    target     = sys.argv[3]
    split_type = sys.argv[4]    
    
    if target in scale_dict:
        scale = scale_dict[target]
    else: 
        print(f"unrecognised target = {target}")
        input("Press Enter to continue...")

    print(f"filter = {filter} datafile = {filename} target = {target} scale = {scale} split_type = {split_type}")

elif len(sys.argv) == 1:

    # being run inside dev environment
    print('run from dev environment')

    # lauchMLcode filtered BLdata_filtered.dta lnm2b
    filter   = 'filtered'
    filename = 'valuation_filtered.dta'
    #filename = 'BLdata_filtered.dta'
    target   = 'lnm2b'
    scale    = 'book'
    split_type = "Base"
    #split_type = "BLVars"

    if target in scale_dict:
        scale = scale_dict[target]
    else: 
        print(f"unrecognised target = {target}")
        input("Press Enter to continue...")
    
    print(f"filter = {filter} datafile = {filename} target = {target} scale = {scale}")

else:
    print(f"You supplied incorrect arguments {sys.argv}")

# input("Press Enter to continue...")

print("lightgbm version = ", lgb.__version__)
print("shap version = ", shap.__version__)

#Original BASE parameters
auto_booster_param = {
    'objective': 'regression',
    'num_threads' : 12,
    'metric': ['rmse', 'mape'],
    'num_leaves': 31,          # ** default 31
    'min_data_in_leaf': 20,    # ** default 20
    'learning_rate': 0.1,      # ** default 0.1
    'random_state': 42,
    'verbosity' : -1,
}

auto_training_param_earlystop = {
    'num_boost_round' : 10000,  # default 100, we use early stopping
    'valid_names' : ["D_dev", "D_train"],
    'early_stopping_rounds' : 10,  # default 0
    'verbose_eval': 100,
}

auto_training_param_fixedtrees = {
    'num_boost_round' : 20,
    'valid_names' : None,
    'early_stopping_rounds' : None,
    'verbose_eval': 100,
}

# set up training parameters based on split_type
if (split_type == "Base") | (split_type == "BLVars"):
    auto_training_param = auto_training_param_earlystop
elif split_type == "AltSplit":
    auto_training_param = auto_training_param_fixedtrees
else: 
    # should not happen
    print(f"Unknown split type {split_type}")        
    input("Press Enter to continue...")
    quit()

auto_training_param

print("Starting Valuation")
print("Using LightGBM version "+lgb.__version__)

def set_defaults():
    # default settings - base - do not change
    global auto_featureset, auto_target, auto_scalevar, auto_debtvar, auto_readdata, auto_do_graphs
    global auto_comment, auto_target_outlier_sd, auto_save_predictions, auto_save_feature_gain, auto_hash_split, auto_filename
    auto_target     = target
    auto_featureset = set([])
    auto_scalevar   = scale
    auto_debtvar    = 'debt_book_value'
    auto_readdata   = False 
    auto_do_graphs  = False
    auto_comment    = split_type + " configuration"
    auto_target_outlier_sd = None
    auto_save_predictions  = True
    auto_filename = "PlaceholderFilename"
    if split_type == "Base":
        auto_save_feature_gain = True
    else:
        auto_save_feature_gain = False
    auto_hash_split = False
    # default settings - base - do not change

set_defaults()

print("done setting defaults")

#---------------------------------------------------------------------------------------------------------
# Tree - prediction
#---------------------------------------------------------------------------------------------------------

# used for "peer group" weights

def tree_prediction(model, data, train_sample_average, tree_iteration, learning_rate):
    if tree_iteration == 0:
        tree_prediction = train_sample_average
    elif tree_iteration == 1:
        # prediction includes effect of sample average, need to reverse this
        gbm1_prediction = model.predict(data, start_iteration = 0, num_iteration = 1)    
        tree_prediction = (gbm1_prediction - train_sample_average)/learning_rate
    else:
        tree_prediction = model.predict(data, start_iteration = tree_iteration-1, num_iteration = 1) / learning_rate

    return tree_prediction


#---------------------------------------------------------------------------------------------------------
#  Main Loop
#---------------------------------------------------------------------------------------------------------

def main_loop(df, comment, target, featureset, categoricals, scalevar, debtvar, booster_param, training_param, 
                target_outlier_sd, save_predictions, predictions_filename, save_feature_gain, this_month, this_block):
    print('')
    print('Main loop')
    print('target : ', target)
    print('comment=', comment, 'scalevar=', scalevar, 'debtvar=', debtvar, 'this_month=', this_month, 'this_block=', this_block)
    # print('featureset:', featureset)

    print("orig df : (cols, rows) = ", len(df.columns), len(df))

    # --- data splitting
    assert(this_block >=1 and this_block <=5)

    if (split_type == "Base") | (split_type == "BLVars"):
        blocks = {1,2,3,4,5}
        test   = {this_block}
        dev    = set(random.sample(list(blocks - test), 1))
        train  = blocks - test - dev

    elif split_type == "AltSplit":
        # does not use a dev split
        # block 6 is provided as a dummy (it is (almost) empty)
        # containing only dummy data
        blocks = {1,2,3,4,5,6}
        test   = {this_block}
        dev    = {6}
        train  = blocks - test - dev
       
    else:
        # should not happen
        print(f"Unknown split type {split_type}")        
        input("Press Enter to continue...")
        quit()

    print("train = ", train)
    print("dev = ", dev)
    print("test = ", test)
    print("blocks = ", blocks)
    print("split_type = ", split_type)

    assert(blocks == train | dev | test)

    datasets = split_data(df=df, target=target, features=featureset, 
                       train_start  = this_month-0,           train_end = this_month-0,
                       dev_start    = this_month-0,           dev_end   = this_month-0,
                       test_start   = this_month+0,           test_end  = this_month+0, 
                       train_blocks = train,  
                       dev_blocks   = dev, 
                       test_blocks  = test)

    if target_outlier_sd is not None:
        datasets['y_train'], datasets['X_train'] = remove_outlier_targets(datasets['y_train'], datasets['X_train'],
                                                                          sd=target_outlier_sd)

    ## GBM
    D_train, D_dev = lgb_data(d=datasets, categoricals=categoricals)

    if (split_type == "Base") | (split_type == "BLVars"):
        training_param['train_set'] = D_train
        training_param['valid_sets'] = [D_dev, D_train]
        training_param['valid_names'] = ['D_dev', 'D_train']

        model = lgb.train(booster_param, **training_param)
        print("Model best iteration", model.best_iteration)

    elif split_type == "AltSplit":
        training_param['train_set'] = D_train
        training_param['valid_sets'] = None
        training_param['valid_names'] = None

        model = lgb.train(booster_param, **training_param)

    else: 
        # should not happen
        print(f"Unknown split type {split_type}")        
        input("Press Enter to continue...")
        quit()

    # should work with any model...
    predictions = calc_predictions(model=model, d=datasets, scalevar=scalevar, debtvar=debtvar, target=target)

    target_results = performance_evaluation(predictions, value=False)
    value_results = performance_evaluation(predictions, value=True)
    
    if save_predictions: 
        print("saving predictions to :", DATA + predictions_filename)
        output_predictions(filename=DATA + predictions_filename, datasets=datasets, pred=predictions)
    else:
        print("not saving predictions")
        
    # save model so we can reload it    
    # model.save_model(DATA + predictions_filename + '.txt')
    
    mdape_dev  = value_results['mdape_dev']
    mdape_test = value_results['mdape_test']  # only use when using sacrificial validation data
    
    combined_results = create_results_context(model=model, X_train=datasets['X_train'], comment=comment, target=target,
                                              target_results=target_results, value_results=value_results, 
                                              booster_param=booster_param, training_param=training_param, 
                                              target_outlier_sd=target_outlier_sd)

    output_results(combined_results, DATA + "results_combined.csv")

    print("----------------------------------")
    print("Mdalpe (dev, test) : ", mdape_dev, mdape_test)
    print("----------------------------------")

    # if the last month and not BL data, then save results to enable "peer-group" weights analysis

    print(f">>>>>>> {this_month} --- {filename[:6]}")

    if (split_type == "Base") & (this_month == 719) & (filename[:6] != "BLdata"):
        MAX_TREES = model.best_iteration        

        # extract datasets
        X_test   = pd.DataFrame(datasets['X_test'])
        y_test   = pd.DataFrame(datasets['y_test'])
        X_train  = pd.DataFrame(datasets['X_train'])
        y_train  = pd.DataFrame(datasets['y_train'])
        id_test  = pd.DataFrame(datasets['id_test'])
        id_train = pd.DataFrame(datasets['id_train'])
        y_train_hat = pd.DataFrame(predictions['y_train_hat'])
        y_test_hat  = pd.DataFrame(predictions['y_test_hat'])

        # -------------------------------------------------------------------------------------------------
        # assign observations to leaves
        # -------------------------------------------------------------------------------------------------

        #  TEST data
        # -------------------------------------------------------------------------------------------------

        this_data = X_test
        train_sample_average = np.asarray(np.mean(y_train)) * np.ones(len(this_data))
        tree_preds = []
        for iter in range(0,MAX_TREES):
            tp = tree_prediction(model = model, 
                                    data = this_data, 
                                    train_sample_average = train_sample_average, 
                                    tree_iteration = iter, 
                                    learning_rate = auto_booster_param['learning_rate'])
            tree_preds.append(tp)

        # add month and firm data to each tree prediction, and save

        tp = pd.DataFrame(tree_preds)

        tp = tp.transpose()

        # merge firm id 
        tp.reset_index(drop=True, inplace=True)
        id_test.reset_index(drop=True, inplace=True)

        tp = pd.merge(tp, id_test, how='inner', left_index=True, right_index=True)

        # get predictions
        # merge firm predictions 
        y_test_hat.reset_index(drop=True, inplace=True)
        tp = pd.merge(tp, y_test_hat, how='inner', left_index=True, right_index=True)

        # save as Stata file
        tp.to_stata(DATA+f"leaves_{this_block}_test.dta")

        #  TRAIN data
        # -------------------------------------------------------------------------------------------------
        this_data = X_train
        train_sample_average = np.asarray(np.mean(y_train)) * np.ones(len(this_data))
        tree_preds = []
        for iter in range(0,MAX_TREES):
            tp = tree_prediction(model = model, 
                                    data = this_data, 
                                    train_sample_average = train_sample_average, 
                                    tree_iteration = iter, 
                                    learning_rate = auto_booster_param['learning_rate'])
            tree_preds.append(tp)


        # add month and firm data to each tree prediction, and savew

        tp = pd.DataFrame(tree_preds)
        tp = tp.transpose()

        # merge firm id 
        tp.reset_index(drop=True, inplace=True)
        id_train.reset_index(drop=True, inplace=True)

        tp = pd.merge(tp, id_train, how='inner', left_index=True, right_index=True)

        # get predictions
        # merge firm predictions 
        y_train_hat.reset_index(drop=True, inplace=True)
        tp = pd.merge(tp, y_train_hat, how='inner', left_index=True, right_index=True)

        # save as Stata file
        tp.to_stata(DATA+f"leaves_{this_block}_train.dta")


    # if requested, calculate and save feature gains (uses Shapley values) - only if GBM
    if save_feature_gain:

        explainer = shap.TreeExplainer(model)

        split = 'test'
        X = datasets['X_'+split]
        ids = datasets['id_'+split]['gvkeynum'].to_numpy().reshape(-1,1).astype(np.int64)
        right_shape = np.shape(ids)
        blocks = np.full(right_shape, this_block)
        months = np.full(right_shape, this_month)

        # get SHAP values from the tree explainer
        shap_values_raw = explainer.shap_values(X)

        # absolute SHAP values -> indicates magnitude of importance, irrespective of direction
        abs_shap_values = np.abs(shap_values_raw)

        # normalise so shap values add to 100% accross features for each observation
        raw_shap_percentages = shap_values_raw/shap_values_raw.sum(axis=1,keepdims=1)
        abs_shap_percentages = normalize(abs_shap_values, norm='l1')

        # add months, ids and blocks
        abs_shap_values_combined = np.hstack((abs_shap_percentages, months, ids, blocks))
        raw_shap_values_combined = np.hstack((raw_shap_percentages, months, ids, blocks))
        raw_shap_values_combined_temp = np.hstack((shap_values_raw, months, ids, blocks))
        
        # save shap values of individual variables for each observation (as percentages adding to 100% for each observation)
        np.savetxt(fname = DATA + 'ABS_SHAP_' + predictions_filename + '_' + split + '.csv', X = abs_shap_values_combined, delimiter = ',')
        np.savetxt(fname = DATA + 'RAW_SHAP_' + predictions_filename + '_' + split + '.csv', X = raw_shap_values_combined, delimiter = ',')
        np.savetxt(fname = DATA + 'RAW_SHAP_TEMP_' + predictions_filename + '_' + split + '.csv', X = raw_shap_values_combined_temp, delimiter = ',')
        np.savetxt(fname = DATA + 'XNAMES_' + predictions_filename + '_' + split + '.csv', X = X.columns, delimiter = ',', fmt ='%s')

    # returns a list with features and their gain
    return mdape_dev, mdape_test


# ===========================================================================
# MAIN ML Models
# ===========================================================================

# read data

df = get_data(source=DATA + filename)
print("Length of df = ",len(df))
print(f"doing {target} scale by {scale} in data {filter} ")

# set up categoricals (only if not BL data, which does not use industry)
if filename[:6] != "BLdata":
    categoricals = set(['industry'])
    df = fix_categoricals(df=df, categoricals=categoricals)

    # selected features        
    scaling          = set(['assets', 'book', 'sale_ac', 'debt_book_value', 'unit'])
    ratios           = set([v for v in df.columns if v[-3:] == '_wr'])
    anomalies        = set([v for v in df.columns if v[-3:] == '_an'])
    auto_featureset  = (categoricals | scaling | ratios | anomalies  | set(['CAPMbeta']) )
    save_feature_gain = auto_save_feature_gain

# run name (split_type = either "Base" or "BLVars")
runname = split_type + filter + target

# if using only BLdata, then things are a bit different
if filename[:6] == "BLdata":
    
    print("Using BLdata")
    
    # only keep needed variables (for row-wise NA deletion to follow)
    df = df[[scale, target, 'debt_book_value', 'hash100', 'gvkeynum', 
        'mth', 'month', 'year'] + ['indv2s', 'indv2a',  'indm2b', 'adjopmad', 
        'negadjopmad', 'adjsalesgrowth', 'd2e', 'pretret_noa_wr', 'roe_wr', 'rd_sale_wr']]
    
    # in this analysis we need all vars to be non-missing (same as BL)
    df.dropna(inplace=True)
    auto_featureset  = [scale, 'debt_book_value'] + ['indv2s', 'indv2a',
                'indm2b', 'adjopmad', 'negadjopmad', 'adjsalesgrowth', 'd2e', 'pretret_noa_wr', 'roe_wr', 'rd_sale_wr']
    categoricals = set([])
    # don't need to save feature gains for BLdata                
    save_feature_gain = False

# drop n/a's
df = drop_target_na(df=df, target=target)

#---------------------------------------------------------------------------------------------------------
# Rolling Windows
#---------------------------------------------------------------------------------------------------------

random.seed(42)   # needed for random validation blocks in main_loop

model_count = 0
mdape_dev_total = 0
mdape_test_total = 0

# input("Press Enter to continue 2...")

for month_t in range(240, 719+1):
#for month_t in range(717, 719+1):
    for block in range(1, 5+1):

        auto_target = target
        auto_scalevar = scale
        
        # modified settings
        # filename format is <runname>_<month>_<block>
        auto_comment    = runname+"_"+str(month_t)+"_"+str(block)
        auto_filename   = runname+"_"+str(month_t)+"_"+str(block)
    
        print('auto_comment : ', auto_comment, '; auto_target : ', auto_target, "count of features = ", len(auto_featureset))

        mdape_dev, mdape_test = main_loop(df=df, comment=auto_comment, 
                                    target=auto_target, 
                                    featureset=auto_featureset, 
                                    categoricals=categoricals, 
                                    scalevar=auto_scalevar, 
                                    debtvar=auto_debtvar,
                                    booster_param=auto_booster_param, 
                                    training_param=auto_training_param , 
                                    target_outlier_sd=auto_target_outlier_sd, 
                                    save_predictions=auto_save_predictions,
                                    predictions_filename=auto_filename, 
                                    save_feature_gain=save_feature_gain,
                                    this_month=month_t, 
                                    this_block=block)
        mdape_dev_total += mdape_dev
        mdape_test_total += mdape_test
        model_count += 1
        
        # run garbage collection to free up memory
        #gc.collect()

print("=========================================")
print("Done!")
print(f"Trained {model_count} models, average mdape dev = {mdape_dev_total/model_count} and average mdape test = {mdape_test_total/model_count}")

# no need to process SHAP datafiles if using BL data
if filename[:6] != "BLdata":
    # concatenate shap files into single file
    win_DATA = DATA.replace("/","\\")
    command1 = f"copy {win_DATA}ABS_SHAP_{runname}_*_test.csv /A {win_DATA}ABS_SHAP_{runname}_combined.csv /B /Y > nul"
    command2 = f"copy {win_DATA}RAW_SHAP_{runname}_*_test.csv /A {win_DATA}RAW_SHAP_{runname}_combined.csv /B /Y > nul"
    command3 = f"copy {win_DATA}RAW_SHAP_TEMP_{runname}_*_test.csv /A {win_DATA}RAW_SHAP_TEMP_{runname}_combined.csv /B /Y > nul"

    print(command1)
    print(command2)
    print(command3)
    # auto_filename   = runname+"_"+str(month_t)+"_"+str(block)
    _ = os.system(command1)
    _ = os.system(command2)
    _ = os.system(command3)

    # release memory
    del df
    gc.collect()

    # shap_results = [<X predictor 1>, ..., <X predictor n>, mth, gvkeynum, block]
    # convert csv into stata file with correct headings.
    print(f"Writing SHAP data to {win_DATA}ABS_SHAP_{runname}_combined.dta")
    shap_data = np.loadtxt(f"{win_DATA}ABS_SHAP_{runname}_combined.csv", delimiter=',')
    last_XNAME_file = f"{win_DATA}XNAMES_{runname}"+"_"+str(month_t)+"_"+str(block)+"_test.csv"
    colnames = [x.rstrip('\n') for x in open(last_XNAME_file,'r')] + ['mth', 'gvkeynum', 'block']
    shap_data_df = pd.DataFrame(shap_data, columns = colnames)
    shap_data_df = shap_data_df.astype({'gvkeynum' : int, 'mth' : int, 'block': int})
    shap_data_df.to_stata(f"{win_DATA}ABS_SHAP_{runname}_combined.dta",write_index=False)

    print(f"Completed target {target} for data {filter}")

    print(f"Writing SHAP data to {win_DATA}RAW_SHAP_{runname}_combined.dta")
    shap_data = np.loadtxt(f"{win_DATA}RAW_SHAP_{runname}_combined.csv", delimiter=',')
    last_XNAME_file = f"{win_DATA}XNAMES_{runname}"+"_"+str(month_t)+"_"+str(block)+"_test.csv"
    colnames = [x.rstrip('\n') for x in open(last_XNAME_file,'r')] + ['mth', 'gvkeynum', 'block']
    shap_data_df = pd.DataFrame(shap_data, columns = colnames)
    shap_data_df = shap_data_df.astype({'gvkeynum' : int, 'mth' : int, 'block': int})
    shap_data_df.to_stata(f"{win_DATA}RAW_SHAP_{runname}_combined.dta",write_index=False)

    print(f"Completed target {target} for data {filter}")

    print(f"Writing SHAP data to {win_DATA}RAW_SHAP_TEMP_{runname}_combined.dta")
    shap_data = np.loadtxt(f"{win_DATA}RAW_SHAP_TEMP_{runname}_combined.csv", delimiter=',')
    last_XNAME_file = f"{win_DATA}XNAMES_{runname}"+"_"+str(month_t)+"_"+str(block)+"_test.csv"
    colnames = [x.rstrip('\n') for x in open(last_XNAME_file,'r')] + ['mth', 'gvkeynum', 'block']
    shap_data_df = pd.DataFrame(shap_data, columns = colnames)
    shap_data_df = shap_data_df.astype({'gvkeynum' : int, 'mth' : int, 'block': int})
    shap_data_df.to_stata(f"{win_DATA}RAW_SHAP_TEMP_{runname}_combined.dta",write_index=False)

    print(f"Completed target {target} for data {filter}")

    #erase csv files of SHAP values after combined and saved as a dta to save space
    command1 = f"erase {win_DATA}ABS_SHAP_{runname}_*_test.csv /Q > nul"
    command2 = f"erase {win_DATA}ABS_SHAP_{runname}_combined.csv /Q > nul"
    command3 = f"erase {win_DATA}RAW_SHAP_{runname}_*_test.csv /Q > nul"
    command4 = f"erase {win_DATA}RAW_SHAP_{runname}_combined.csv /Q > nul"
    command5 = f"erase {win_DATA}RAW_SHAP_TEMP_{runname}_*_test.csv /Q > nul"
    command6 = f"erase {win_DATA}RAW_SHAP_TEMP_{runname}_combined.csv /Q > nul"
    command7 = f"erase {win_DATA}XNAMES_{runname}_*_test.csv /Q > nul"

    print(command1)
    print(command2)
    print(command3)
    print(command4)
    print(command5)
    print(command6)
    print(command7)
    # auto_filename   = runname+"_"+str(month_t)+"_"+str(block)
    _ = os.system(command1)
    _ = os.system(command2)
    _ = os.system(command3)
    _ = os.system(command4)
    _ = os.system(command5)
    _ = os.system(command6)
    _ = os.system(command7)
                    
