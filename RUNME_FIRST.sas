%sysmstoreclear;
%let resego_catalog_path=%str(C:\Users\mignaccolo\work\SAS_MACROS\resego);
%let resego_originalsource_path=%str(C:\Users\mignaccolo\work\SAS_MACROS\resego);

/* Define Catalog with all stored macros */
options mstored sasmstore=resego; 
libname resego "&resego_catalog_path"; 

/* compile all macros */
%include "&resego_originalsource_path./accuracy_roc.sas";
%include "&resego_originalsource_path./accuracy_interval.sas";
%include "&resego_originalsource_path./accuracy_nominal.sas";
%include "&resego_originalsource_path./accuracy_calibration.sas";
%include "&resego_originalsource_path./bootstrap_sampling.sas";
%include "&resego_originalsource_path./stratified_random_sampling.sas";
%include "&resego_originalsource_path./random_sampling.sas";
%include "&resego_originalsource_path./equistrata_sampling.sas";
%include "&resego_originalsource_path./model_ranfor_base.sas";
%include "&resego_originalsource_path./model_ranfor_iteration.sas";
%include "&resego_originalsource_path./ranfor_base.sas";
%include "&resego_originalsource_path./rescale_probabilities_binary.sas";
%include "&resego_originalsource_path./transpose_nominal_score.sas";
%include "&resego_originalsource_path./rescale_probabilities_nominal.sas";
%include "&resego_originalsource_path./score_with_random_forest_base.sas";
%include "&resego_originalsource_path./score_with_random_forest_iter.sas";
%include "&resego_originalsource_path./model_count_base.sas";
%include "&resego_originalsource_path./count_base.sas";
%include "&resego_originalsource_path./model_count_iteration.sas";
%include "&resego_originalsource_path./pca_num_variables.sas";
%include "&resego_originalsource_path./make_pca_variables.sas";
%include "&resego_originalsource_path./by_group_accuracy.sas";
%include "&resego_originalsource_path./exclude_single_valvar_in_legend.sas";
%include "&resego_originalsource_path./score_with_model_count_base.sas";

/* show content of the macor catalog */
proc catalog catalog=resego.sasmacr;
	contents;
run;

/* */
%sysmstoreclear;
%SYMDEL;
