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
#  Utility Functions
#---------------------------------------------------------------------------------------------------------
import numpy as np
import pandas as pd
from zlib import crc32

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

def mv_hash(x):
    '''converts input integer x into a crc32 hash modulo 100'''
    return crc32(bytes(str(x),'utf-8')) % 100


# make_colvec, make_value, mean_absolute_percentage_error, mean_absolute_log_percentage_error, median_absolute_percentage_error

def make_colvec(df):
    ''' converts a pandas dataframe or series, or numpy ndarray into a numpy column vector '''
    if isinstance(df, np.ndarray):
        return df.reshape(len(df), 1)
    if isinstance(df, pd.DataFrame):
        return df.iloc[:,0].to_numpy().reshape(len(df), 1)
    elif isinstance(df, pd.Series):
        return df.to_numpy().reshape(len(df), 1)
    else:
        return None        


def mean_absolute_percentage_error(y_true, y_pred): 
    ''' calculates mean absolute percentage error  '''
    epsilon = 1e-16
    yt = make_colvec(y_true)
    yp = make_colvec(y_pred)
    return np.mean(np.abs( (yt - yp) / (np.abs(yt)+epsilon) ))


def median_absolute_percentage_error(y_true, y_pred): 
    ''' calculates median absolute percentage error  '''
    epsilon = 1e-16
    yt = make_colvec(y_true)
    yp = make_colvec(y_pred)
    return np.median(np.abs( (yt - yp) / (np.abs(yt)+epsilon) ))


def mean_absolute_log_percentage_error(y_true, y_pred):
    ''' calculates mean absolute log percentage error  [see Tofallis (2015)]'''
    epsilon = 1e-16
    yt = make_colvec(y_true)
    yp = make_colvec(y_pred)
    
    # ensure strictly positive entries in yt, yp
    # will always be the case for firm values, other
    # results should be interpreted with caution
    yt = np.maximum(epsilon,yt)
    yp = np.maximum(epsilon,yp)
    
    return np.mean(np.abs(np.log(yt) - np.log(yp)))

def median_absolute_log_percentage_error(y_true, y_pred): 
    ''' calculates median absolute percentage error  '''
    epsilon = 1e-16
    yt = make_colvec(y_true)
    yp = make_colvec(y_pred)
    
    # ensure strictly positive entries in yt, yp
    # will always be the case for firm values, other
    # results should be interpreted with caution
    yt = np.maximum(epsilon,yt)
    yp = np.maximum(epsilon,yp)
    
    return np.median(np.abs(np.log(yt) - np.log(yp)))


#  make_value([2,5],[1,1],[0,0],"lnv2a")
def make_value(y, scalevar, debtvar, target):
    ''' turn predicted target into an equity value prediction '''
    # debtvar not currently used...
    # scalevar is either book (book equity) or assets (total assets)
    # depending on the target

    assert(any(scalevar)>0)
    
    if (target == "v2a"):
        # ML predicting y s.t. value =  y * scalevar
        y_value = (y * scalevar) - debtvar
        y_value = y_value.clip(0)

    elif (target == "lnv2a"):
        # ML predicting y s.t. value = exp(y) * scalevar.
        y_value = np.exp(y) * scalevar - debtvar
        y_value = y_value.clip(0)

    elif (target == "v2s"):
        # ML predicting y s.t. value = exp(y) * scalevar.
        y_value = (y * scalevar) - debtvar
        y_value = y_value.clip(0)

    elif (target == "lnv2s"):
        # ML predicting y s.t. value = exp(y) * scalevar.
        y_value = (np.exp(y) * scalevar) - debtvar   
        y_value = y_value.clip(0)
    
    elif (target == "m2b"):
        # ML predicting y s.t. value =  y * scalevar
        y_value = y * scalevar

    elif (target == "lnm2b"):
        # ML predicting y s.t. value = exp(y) * scalevar.
        y_value = np.exp(y) * scalevar
    
    elif (target == "m"):
        # ML predicting y s.t. value =  y 
        y_value = y 

    elif (target == "lnm"):
        # ML predicting y s.t. value = exp(y) 
        y_value = np.exp(y) 

    elif not target in ['v2a', 'lnv2a', 'm2b', 'lnm2b', 'v2s', 'lnv2s' , 'm', 'lnm']:
        print(f"BIG DISASTER (see function make_value in mvutils.py) - target = --{target}--")
        assert(False)
    
    # predicted equity value must be weakly positive
    assert(any(y_value)>=0)

    return y_value



