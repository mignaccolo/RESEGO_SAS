%macro model_ranfor_iteration(_repetition_,_infile_data_,list_var_file,path_for_binary_mdl_impl,model_identifier,_target_type_,
ntrees,maxnvar,_seed_,trainvalidation=random,_trainfr_=0.7,train_with_equistrata=N,equistrata_option=tomin,strata=target,
_trainfrRF_=0.6,_maxdepth_=50,_leaffrac_=0.0001,_alpha_=0.05,_targety_=Y,_targetn_=N,whichlib=same)/
store source des="Run a series of Random Forest Models: train/validation splitting + run random forest algorithm";

/* PARAMETERS
1) _repetition_: the number of models to run. 
2) _infile_data_: name (SASLIBRARY.SASFILENAME) of the SAS table  with the data to model.
3) list_var_file: name (SASLIBRARY.SASFILENAME) of the SAS table with the type and scope of each variable in the data set to split
	i.e. if only a set of variable is of interest for modelling the value 'XX' in the colum LEGEND of &list_var_file identifyt the variable 
	to not include in the TRAIN and VALIDATION outputs.
4) path_for_binary_mdl_impl: a valid system path were binary implementation of the model can be stored to score additional data set
5) model_identifier: a string identifiying the model specification e.g. RANFOR_example_1.
6) _target_type_: ("binary","nominal","interval") The type of the target variable.
7) ntrees: number of trees in the (random) forest.
8) maxnvar: number of variables to be selected randomly at node splitting.
9) _seed_: seed of the random number generator
10) trainvalidation: how to split the original data set in a train and validation pair. Valid methods are 
	"random" (train & validation = random sample without replacement), 
	"stratified" (train & validation = random sample without replacement + train & validation data set have same frequency than original file for a given strata), 
	"bootstrap" (train = random sample with replacement, validation = records not selected for train).
	By default tha choice is "random"
11) _trainfr_: fraction of the original data set which is chosen for train. If trainvalidation=bootstrap, the 
	train data set has the same number of records as the original dataset however some record are repeated more than one time (sampling with replacement)
12) train_with_equistrata: modify or not the train data set to have equal proportion of each strata (the strata variable might be different from target variable. Default is N (no).
13) equistrata_option: criteria used to modify train data set to reach equal sampling for each strata. Valid options are 
	"tomin" (sampling without replacement to produce a data set where all strata have the same number of records as the less frequent strata), 
	"tomax" (sampling with replacement to produce a data set where all strata have the same number of records as the most frequent strata),
	"logmean" (sampling with replacement to produce a data set where all strata have a number records which logarithm is the the average between the log of the 
		number of records of the more frequent strata and the less frequent strata).
	Default is "tomean".
14) strata: the strata variable. By default start=target indicating that the target variable is the strata variable
15) _trainfrRF_: in the random forest algorithm the fraction of the  input data set that is used to grow a tree (default=0.6)
	input data set = train data set created via "trainvalidation" and "train_with_equistrata" choices. 
16) _maxdepth_: the maximum number of nodes in each tree of the forest is 2^_maxdepth_ (provided that there are enough observation to populate all teh leaves)
17) _leaffrac_: determines the minimum number of records a leaf must have for a splitting to occurr as the fraction of the number of records available for the growth of each tree 
	example input data set for the random forest algorithm has 100,000 records and we select _trainfr_=0.6 => each tree is grown with 60,000 records => a leaf must have at least 
	_leaffrac_*60,000 records. If _leaffrac=0.0001 (default), each leaf must have at least 6 records
18) _alpha_: specifies a threshold p-value for the significance level of a test of association of a candidate variable with the target. 
	If no association meets this threshold, the node is not split.
19) _targety_: one of the two values of the target variable. When scoring p=probability of _targety_ By deafult _target_ = 'Y'.
20) _targetn_: one of the two values of the target variable. By deafult _target_ = 'N'.
21) whichlib: name of the SAS library where to store the output data sets generated by "model_ranfor_base" (by default=same inidcating that the same library as the model data should be used).
*/

%put Executing: model_ranfor_iteration &list_var_file;
%local _filename_; /* full (path + file name) system  name for the binary file where to store details of the model (useful to score new data set) */
%local target_variable; /* the name of the target variable  */
%local _length_; /* the legnth in bytes of the target variable */
%local id_variables; /* the variable/ identifying a records (e.g. person id ,transaction id) which we want to display when scoring a data set */ 
%local library; /* SAS library where to store the output data sets ogenerated by the macro. Value of library is decide by value of whichlib parameter */
%local vimpo_variable; /* keep/rename adjustement for the varaible importance output generated by HPFOREST */
%local fit_variable; /* keep/rename adjustement for the fit goodness output generated by HPFOREST */
%local _seed_i; /* seed for the i-th random forest model (_seed_i is derived from _seed_)*/


/* initialize the value of library */
%if %sysfunc(compare("same","&whichlib")) eq 0 %then %do;
	%let library=%scan(&_infile_data_,1,'.');
%end; %else %do;
	%let library=&whichlib;
%end;

/* check if the target variable type is one the admitted ones */
%if (%sysfunc(compare("binary","&_target_type_")) ne 0) and 
	(%sysfunc(compare("nominal","&_target_type_")) ne 0) and 
	(%sysfunc(compare("interval","&_target_type_")) ne 0) %then %do;
	%put ERROR: Valid values for _target_type_ parameters are "binary", "nominal", "interval";%goto exit;
%end;

/* define target variable */
proc sql NOPRINT;
	select length(strip(VARNAME)) into: _length_ from  &list_var_file where LEGEND eq 'TG';
	select strip(VARNAME) length=&_length_ into: target_variable from &list_var_file where LEGEND eq 'TG';
quit;

/* define id variables  */
proc sql NOPRINT;select strip(VARNAME) into: id_variables  separated by ' '  from &list_var_file where LEGEND eq 'ID';quit;

/* check if the strata to be used is the target variable -- START */
%if %sysfunc(compare("&strata","target")) eq 0 %then %do;
	proc sql NOPRINT;select VARNAME into: strata from &list_var_file where LEGEND eq 'TG';quit;
%end;
/* check if the strata to be used is the target variable -- END */

/* execute model one time (necessary to easily initialize tables) -- START */
%let i=1;
%let _seed_i_=%sysevalf(&_seed_+&i-1);
%put RUNNING MODEL NO. &i;

	/* create model */
%model_ranfor_base(&_infile_data_,&list_var_file,&path_for_binary_mdl_impl,&model_identifier.&i,&_target_type_,
&ntrees,&maxnvar,&_seed_i_,trainvalidation=&trainvalidation,_trainfr_=&_trainfr_,train_with_equistrata=&train_with_equistrata,
equistrata_option=&equistrata_option,strata=&strata,_trainfrRF_=&_trainfrRF_,_maxdepth_=&_maxdepth_,_leaffrac_=&_leaffrac_,
_alpha_=&_alpha_,_targety_=&_targety_,_targetn_=&_targetn_,whichlib=work);

	/* create table to collect results of each iteration -- START */
		/* tables generated when target is binary */
%if %sysfunc(compare("binary","&_target_type_")) eq 0 %then %do;
	proc sql; create table _cdefa_val like &model_identifier.&i._cdefa_val; quit;
	proc append base=_cdefa_val data=&model_identifier.&i._cdefa_val; run; quit;
	proc sql; drop table &model_identifier.&i._cdefa_val;quit;
	proc sql; create table _calib_val like &model_identifier.&i._calib_val; quit;
	proc append base=_calib_val data=&model_identifier.&i._calib_val; run; quit;
	proc sql; drop table &model_identifier.&i._calib_val;quit;
%end;
		/* tables generated when target is interval */
%if %sysfunc(compare("interval","&_target_type_")) eq 0 %then %do;
	proc sql; create table _acc_val like &model_identifier.&i._acc_val; quit;
	proc append base=_acc_val data=&model_identifier.&i._acc_val; run; quit;
	proc sql; drop table &model_identifier.&i._acc_val; quit;
%end;
		/* tables generated when target is nominal */
%if %sysfunc(compare("nominal","&_target_type_")) eq 0 %then %do;
	proc sql; create table _nom_val like &model_identifier.&i._nom_val; quit;
	proc append base=_nom_val data=&model_identifier.&i._nom_val; run; quit;
	proc sql; drop table &model_identifier.&i._nom_val; quit;
%end;

		/* tables generated not depending on type of tartget variable */
proc sql; create table fit_stat like &model_identifier.&i._fit; quit;
proc append base=fit_stat data=&model_identifier.&i._fit; run; quit;
proc sql; drop table &model_identifier.&i._fit; quit;

proc sql; create table variables_importance like &model_identifier.&i._vimpo; quit;
proc append base=variables_importance data=&model_identifier.&i._vimpo; run; quit;
proc sql; drop table &model_identifier.&i._vimpo; quit;

proc sql; create table _valscr like &model_identifier.&i._valscr; quit;
proc append base=_valscr data=&model_identifier.&i._valscr; run; quit;
proc sql; drop table &model_identifier.&i._valscr; quit;
	/* create table to collect results of each iteration -- END */

/* execute model one time (necessary to easily initialize tables) -- END */

/* execute model _repetition_ -1 times (necessary to easily initialize tables) -- START */
%do i=2 %to &_repetition_ %by 1;
	%let _seed_i_=%sysevalf(&_seed_+&i-1);
	%put RUNNING MODEL NO. &i;
	/* create model */
	%model_ranfor_base(&_infile_data_,&list_var_file,&path_for_binary_mdl_impl,&model_identifier.&i,&_target_type_,
&ntrees,&maxnvar,&_seed_i_,trainvalidation=&trainvalidation,_trainfr_=&_trainfr_,train_with_equistrata=&train_with_equistrata,
equistrata_option=&equistrata_option,strata=&strata,_trainfrRF_=&_trainfrRF_,_maxdepth_=&_maxdepth_,_leaffrac_=&_leaffrac_,
_alpha_=&_alpha_,_targety_=&_targety_,_targetn_=&_targetn_,whichlib=work);

	/* append current iteration result to collecting tables -- START */
		/* tables used when target is binary */
	%if %sysfunc(compare("binary","&_target_type_")) eq 0 %then %do;
		proc append base=_cdefa_val data=&model_identifier.&i._cdefa_val; run; quit;
		proc sql; drop table &model_identifier.&i._cdefa_val; quit;
		proc append base=_calib_val data=&model_identifier.&i._calib_val; run; quit;
		proc sql; drop table &model_identifier.&i._calib_val; quit;
	%end;
		/* tables used when target is interval */
	%if %sysfunc(compare("interval","&_target_type_")) eq 0 %then %do;
		proc append base=_acc_val data=&model_identifier.&i._acc_val; run; quit;
		proc sql; drop table &model_identifier.&i._acc_val; quit;
	%end;
		/* tables used when target is nominal */
	%if %sysfunc(compare("nominal","&_target_type_")) eq 0 %then %do;
		proc append base=_nom_val data=&model_identifier.&i._nom_val;run;quit;
		proc sql; drop table &model_identifier.&i._nom_val;quit;
	%end

	proc append base=fit_stat data=&model_identifier.&i._fit;run;quit;
	proc sql; drop table &model_identifier.&i._fit; quit;	

	proc append base=variables_importance data=&model_identifier.&i._vimpo;run;quit;
	proc sql; drop table &model_identifier.&i._vimpo; quit;

	proc append base=_valscr data=&model_identifier.&i._valscr;run;quit;
	proc sql; drop table &model_identifier.&i._valscr; quit;
	/* append current iteration result to collecting tables -- END */
%end;
/* execute model _repetition_ -1 times (necessary to easily initialize tables) -- END */

/* POST PROCESS RESULTS -- START */
	/* --- INTERVAL TARGET --- */
%if %sysfunc(compare("interval","&_target_type_")) eq 0 %then %do; 
	%let vimpo_variable=OOB_MeanSquareError; 
	%let fit_variable=OOB_AverageSquareError;
	proc sort data=variables_importance out=variables_importance; by Variable; run; quit;
	proc sort data=fit_stat out=fit_stat; by NTrees; run; quit;
	proc sort data=_valscr out=_valscr; by &id_variables; run; quit;
	proc sort data=_acc_val out=_acc_val; by error_type stat_type; run; quit;

	/* calculate average for variable importance */
	proc univariate data=variables_importance noprint;
		var NRules &vimpo_variable;
		output out=&library..&model_identifier._vimpo mean=avg_NRules avg_&vimpo_variable;
		by Variable;
	run;
	proc sort data=&library..&model_identifier._vimpo out=&library..&model_identifier._vimpo; 
		by descending avg_&vimpo_variable;
	run;quit;

	/* calculate average for fit statistics */
	proc univariate data=fit_stat noprint;
		var NLeaves &fit_variable;
			output out=&library..&model_identifier._fit mean=avg_NLeaves avg_&fit_variable;
		by NTrees;
	run;quit;

	/* calculate average GOOT (out of train) prediction */
	proc univariate data=_valscr noprint;
	var predicted;
		output out=&library..&model_identifier._valscr PCTLPRE=predicted N=ntimes_oot pctlpts=5 50 95 pctlname=_q5 _median _q95;
	by &id_variables &target_variable;
	run; 
	%accuracy_interval(&library..&model_identifier._valscr,&library..&model_identifier._accGOOT,&target_variable,probvar=predicted_median);
	/* if target variable is a count we measure the accuracy by each count value */

	/* */
	proc univariate data=_acc_val noprint;
	var stat_value;
		output out=&library..&model_identifier._accval PCTLPRE=stat_value pctlpts=5 50 95 pctlname=_q5 _median _q95;
	by error_type stat_type;
	run;
	proc sort data=&library..&model_identifier._accval out=&library..&model_identifier._accval; by error_type stat_value_median; run;quit;

	/* remove temporary files */
	proc sql; drop table fit_stat,variables_importance,_valscr,_acc_val; quit;
%end;
	/* --- BINARY TARGET --- */
%if %sysfunc(compare("binary","&_target_type_")) eq 0 %then %do;
	%let vimpo_variable=OOB_Gini;
	%let fit_variable=OOB_Misclassification;
	proc sort data=variables_importance out=variables_importance; by Variable; run; quit;
	proc sort data=fit_stat out=fit_stat; by NTrees; run; quit;
	proc sort data=_valscr out=_valscr; by &id_variables; run; quit;
	proc sort data=_cdefa_val out=_cdefa_val; by p_threshold; run; quit;

	/* calculate 5 percentile, median , 95 percentile for C-SCORE TP,TN,FP,FN for validation data set */
	proc univariate data=_cdefa_val noprint;
	var TP FN TN FP de fpr fa c_score;
		output out=&library..&model_identifier._cval pctlpts=5 50 95 pctlpre=TP_ FN_ TN_ FP_ de_ fpr_ fa_ c_score_;
	by p_threshold;
	run;

	/* calculate average for variable importance */
	proc univariate data=variables_importance noprint;
		var NRules &vimpo_variable;
		output out=&library..&model_identifier._vimpo mean=avg_NRules avg_OOB_Gini;
		by Variable;
	run;
	proc sort data=&library..&model_identifier._vimpo out=&library..&model_identifier._vimpo; 
		by descending avg_&vimpo_variable;
	run;quit;

	/* calculate average for fit statistics */
	proc univariate data=fit_stat noprint;
		var NLeaves &fit_variable;
			output out=&library..&model_identifier._fit mean=avg_NLeaves avg_&fit_variable;
		by NTrees;
	run;quit;

	/* calculate average GOOT (out of train) probability */
	proc univariate data=_valscr noprint;
	var p;
		output out=&library..&model_identifier._valscr PCTLPRE=p N=ntimes_oot pctlpts=5 50 95 pctlname=_q5 _median _q95;
	by &id_variables &target_variable;
	run; 
	%accuracy_roc(&library..&model_identifier._valscr,&library..&model_identifier._cGOOT,&target_variable,probvar=p_median,_targety_=&_targety_,_targetn_=&_targetn_);

	/* remove temporary files */
	proc sql; drop table _cdefa_val,fit_stat,variables_importance,_valscr; quit;
%end;
	/* --- NOMINAL TARGET --- */
%if %sysfunc(compare("nominal","&_target_type_")) eq 0 %then %do;
	%let vimpo_variable=OOB_Gini;
	%let fit_variable=OOB_Misclassification;
	proc sort data=variables_importance out=variables_importance; by Variable; run; quit;
	proc sort data=fit_stat out=fit_stat; by NTrees; run; quit;
	proc sort data=_valscr out=_valscr; by &id_variables &target_variable target_value; run; quit;
	proc sort data=_nom_val out=_nom_val; by &target_variable predicted_value; run; quit;

	/* calculate 5 percentile, median , 95 percentile for COUNT and PERCENT for validation data set */
	proc univariate data=_nom_val noprint;
	var COUNT PERCENT;
		output out=&library..&model_identifier._nomval pctlpts=5 50 95 pctlpre=count_ percent_;
	by &target_variable predicted_value;
	run;

	/* calculate average for variable importance */
	proc univariate data=variables_importance noprint;
		var NRules &vimpo_variable;
		output out=&library..&model_identifier._vimpo mean=avg_NRules avg_OOB_Gini;
		by Variable;
	run;
	proc sort data=&library..&model_identifier._vimpo out=&library..&model_identifier._vimpo; 
		by descending avg_&vimpo_variable;
	run;quit;

	/* calculate average for fit statistics */
	proc univariate data=fit_stat noprint;
		var NLeaves &fit_variable;
			output out=&library..&model_identifier._fit mean=avg_NLeaves avg_&fit_variable;
		by NTrees;
	run;quit;

	/* calculate average GOOT (out of train) probability */
	proc univariate data=_valscr noprint;
	var p;
		output out=&library..&model_identifier._valscr PCTLPRE=p N=ntimes_oot pctlpts=5 50 95 pctlname=_q5 _median _q95;
	by &id_variables &target_variable target_value;
	run; 
	%accuracy_nominal(&library..&model_identifier._valscr,&library..&model_identifier._nomGOOT,&target_variable,&id_variables,probvar=p_median);
	/* remove temporary files */
	proc sql; drop table _nom_val,fit_stat,variables_importance,_valscr; quit;
%end;

/* POST PROCESS RESULTS -- END */

%exit: %mend model_ranfor_iteration;