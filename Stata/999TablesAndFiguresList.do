* ----------------------------------------------------------------------------
* TablesAndFiguresList
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

* This file lists out the result files (.pdf for graphs and .tex for table)
* for each of the figures and tables in the paper.

/*

Figure 1: Comparison of model valuation errors over time
A: results/Graph_abserr_ts_comparison_m2b_filtered.pdf
B: results/Graph_abserr_ts_comparison_v2a_filtered.pdf
C: results/Graph_abserr_ts_comparison_v2s_filtered.pdf
D: results/Graph_abserr_ts_comparison_RRV_BG_filtered.pdf
E: results/Graph_abserr_ts_filtered.pdf

Figure 2: Valuation errors across firms
A.1: results/Graph_abserr_subsample_size_m2b_comp_filtered.pdf
A.2: results/Graph_abserr_subsample_m2b_m2b_comp_filtered.pdf
A.3: results/Graph_abserr_subsample_roe_m2b_comp_filtered.pdf
B.1: results/Graph_abserr_subsample_size_m2b_RRV_BG_filtered.pdf
B.2: results/Graph_abserr_subsample_m2b_m2b_RRV_BG_filtered.pdf
B.3: results/Graph_abserr_subsample_roe_m2b_RRV_BG_filtered.pdf

Figure 3: Valuation errors across firms for ML models
A.1 results/Graph_aberr_Size_Med_simple_filtered.pdf
A.2 results/Graph_aberr_M2B_Med_simple_filtered.pdf
A.3 results/Graph_aberr_ROE_Med_simple_filtered.pdf
A.4 results/Graph_aberr_Industry_Med_simple_filtered.pdf
B.1 results/Graph_err_Size_Med_simple_filtered.pdf
B.2 results/Graph_err_M2B_Med_simple_filtered.pdf
B.3 results/Graph_err_ROE_Med_simple_filtered.pdf
B.4 results/Graph_err_Industry_Med_simple_filtered.pdf

Figure 4: Peer weights
results/peerweights_34410.pdf

Figure 5: Individual SHAP values for Moderna (December 2019)
static_assets/Moderna_SHAP_example_graph.pdf

Table 1: Machine learning data selection
results/sample_selection.tex

Table 2: Model performance comparison
results/comparison_main_available_filtered.tex

Table 3: Value-weighted portfolio returns
results/retpred_combined_vw_filtered.tex

Table 4: Source of performance gains
A: reconciliation_performance_m2b_filtered.tex
B: reconciliation_performance_v2a_filtered.tex
C: reconciliation_performance_v2s_filtered.tex

Table 5: Most and least comparable peers of Moderna
lnm2b_peerweights_34410_combined.tex

Table 6: Theoretical determinants of valuation multiples
<Table included in main latex file>

Table 7: Variable importance
results/ABS_SHAP_filtered.tex

Table 8: Category importance
results/cat_ABS_SHAP_filtered.tex

Table 9: Importance of individual variables over time
results/ABS_SHAP_filtered_decade.tex


------------ Appendix ------------

Table A.1: Variables description
results/variables_used_main.tex

Figure A.1: Trees in GBMs: a simplified example
A: static_assets/Tree1.gv.pdf
B: static_assets/Tree2.gv.pdf

Table A.2: Using GBMs to generate predictions in test data: a simplified example
<Tables A-E included in main latex file>

------------ Internet Appendix ------------

Table IA.1: Rhodes-Kropf, Robinson and Viswanathan (2005)
results/variables_used_RRV_filtered.tex

Table IA.2: Bartram and Grinblatt (2018)
results/variables_used_BG_filtered.tex

Table IA.3: Bhojraj and Lee (2002)
results/variables_used_BL_filtered.tex

Table IA.4: Summary statistics of variables used in machine learning models
results/filteredsummarystats.tex

Figure IA.1: Training, validation and test data split and rotation 
/static/sample_split.pdf

Table IA.5: Model performance comparison
/results/comparison_main_similar_filtered.tex

Table IA.6: Performance of alternative machine learning models
/results/comparison_all_available_filtered.tex

Figure IA.2: Model valuation error comparison (alternative ML targets)
A: results/Graph_abserr_ts_alttarget_filtered.pdf
B: results/Graph_abserr_subsample_size_altMLtargets_comp_filtered.pdf
C: results/Graph_abserr_subsample_m2b_altMLtargets_comp_filtered.pdf
D: results/Graph_abserr_subsample_roe_altMLtargets_comp_filtered.pdf

Figure IA.3: Comparison of ML model valuation errors over time
A: results/Graph_abserr_ts_filtered.pdf
B: results/Graph_neweconomy_pct_ts_filtered.pdf
C: results/Graph_abserr_neweco_ts_filtered.pdf
D: results/Graph_abserr_oldeco_ts_filtered.pdf

Figure IA.4: Valuation error comparison across firms (v2a)
A.1: results/Graph_abserr_subsample_size_v2a_comp_filtered.pdf
A.2: results/Graph_abserr_subsample_m2b_v2a_comp_filtered.pdf
A.3: results/Graph_abserr_subsample_roe_v2a_comp_filtered.pdf
B.1: results/Graph_abserr_subsample_size_v2a_RRV_BG_filtered.pdf
B.2: results/Graph_abserr_subsample_m2b_v2a_RRV_BG_filtered.pdf
B.3: results/Graph_abserr_subsample_roe_v2a_RRV_BG_filtered.pdf

Figure IA.5: Valuation error comparison across firms (v2s)
A.1: results/Graph_abserr_subsample_size_v2s_comp_filtered.pdf
A.2: results/Graph_abserr_subsample_m2b_v2s_comp_filtered.pdf
A.3: results/Graph_abserr_subsample_roe_v2s_comp_filtered.pdf
B.1: results/Graph_abserr_subsample_size_v2s_RRV_BG_filtered.pdf
B.2: results/Graph_abserr_subsample_m2b_v2s_RRV_BG_filtered.pdf
B.3: results/Graph_abserr_subsample_roe_v2s_RRV_BG_filtered.pdf

Table IA.7: Equal-weighted portfolio returns
results/retpred_combined_ew_filtered.tex

Table IA.8: Variable importance in machine learning models
results/filteredfeature_importance_detail.tex

*/