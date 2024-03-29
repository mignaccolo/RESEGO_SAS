%macro model_count_iteration(_repetition_,_infile_data_,list_var_file,path_for_binary_mdl_impl,model_identifier,_distribution_,
_seed_,trainvalidation=random,_trainfr_=0.7,train_with_equistrata=N,equistrata_option=tomin,strata=target,whichlib=same)/
store source des="Run a series of Random Forest Models: train/validation splitting + run random forest algorithm";

/* PARAMETERS
1) _repetition_: the number of models to run. 
2) _infile_data_: name (SASLIBRARY.SASFILENAME) of the SAS table  with the data to model.
3) list_var_file: name (SASLIBRARY.SASFILENAME) of the SAS table with the type and scope of each variable in the _infile_data_ data set.
4) path_for_binary_mdl_impl: a valid system path were binary implementation of the model can be stored to score additional data sets.
5) model_identifier: a string identifiying the model specification e.g. RANFOR_example_1.
6) _distribution_: type of possible distribution for the target variable.
7) _seed_: seed of the random number generator
8) trainvalidation: how to split the original data set in a train and validation pair. Valid methods are 
	"random" (train & validation = random sample without replacement), 
	"stratified" (train & validation = random sample without replacement + train & validation data set have same frequency than original file for a given strata), 
	"bootstrap" (train = random sample with replacement, validation = records not selected for train).
	By default tha choice is "random"
9) _trainfr_: fraction of the original data set which is chosen for train. If trainvalidation=bootstrap, the 
	train data set has the same number of records as the original dataset however some record are repeated more than one time (sampling with replacement)
10) train_with_equistrata: modify or not the train data set to have equal proportion of each strata (the strata variable might be different from target variable. Default is N (no).
11) equistrata_option: criteria used to modify train data set to reach equal sampling for each strata. Valid options are 
	"tomin" (sampling without replacement to produce a data set where all strata have the same number of records as the less frequent strata), 
	"tomax" (sampling with replacement to produce a data set where all strata have the same number of records as the most frequent strata),
	"logmean" (sampling with replacement to produce a data set where all strata have a number records which logarithm is the the average between the log of the 
		number of records of the more frequent strata and the less frequent strata).
	Default is "tomean".
12) strata: the strata variable. By default start=target indicating that the target variable is the strata variable
13) whichlib: name of the SAS library where to store the output data sets generated by "model_ranfor_base" (by default=same inidcating that the same library as the model data should be used).
*/

%put Executing: model_count_iteration;

/* declare variables */
%local _filename_; /* full (path + file name) system  name for the binary file where to store details of the model (useful to score new data set) */
%local target_variable; /* the name of the target variable  */
%local _length_; /* the legnth in bytes of the target variable */
%local id_variables; /* the variable/s identifying a record (e.g. person id ,transaction id) which we want to display when scoring a data set */ 
%local library; /* SAS library where to store the output data sets ogenerated by the macro. Value of library is decide by value of samelib parameter */
%local _seed_i; /* seed for the i-th random forest model (_seed_i is derived from _seed_)*/
%local extra_var; /* name of the variable indicaing the probability of null count in the zero inflated models */
%local i; /* loop parameter */

/* initialize extra_var */
%let extra_var=;

/* initialize the value of library */
%if %sysfunc(compare("same","&whichlib")) eq 0 %then %do;
	%let library=%scan(&_infile_data_,1,'.');
%end; %else %do;
	%let library=&whichlib;
%end;

/* check if the distribution is available */
%if (%sysfunc(compare("POISSON","&_distribution_")) ne 0) and 
	(%sysfunc(compare("NEGBINOMIAL","&_distribution_")) ne 0) and 
	(%sysfunc(compare("ZIP","&_distribution_")) ne 0) and 
	(%sysfunc(compare("ZINB","&_distribution_")) ne 0) %then %do;
	%put ERROR: Valid values for distribution parameter are POISSON, NEGBINOMIAL, ZIP, ZINBINOMIAL;  %goto exit;
%end;

/* define target variable */
proc sql NOPRINT;
	select length(strip(VARNAME)) into: _length_ from  &list_var_file where LEGEND eq 'TG';
	select strip(VARNAME) length=&_length_ into: target_variable from &list_var_file where LEGEND eq 'TG';
quit;

/* define id variables  */
proc sql NOPRINT;select strip(VARNAME) into: id_variables  separated by ' '  from &list_var_file where LEGEND eq 'ID';quit;


/* execute model one time (necessary to easily initialize tables) -- START */
%let i=1;
%let _seed_i_=%sysevalf(&_seed_+&i-1);
%put RUNNING MODEL NO. &i;

	/* create model */
%model_count_base(&_infile_data_,&list_var_file,&path_for_binary_mdl_impl,&model_identifier.&i,&_distribution_,
&_seed_i_,trainvalidation=&trainvalidation,_trainfr_=&_trainfr_,train_with_equistrata=&train_with_equistrata,
equistrata_option=&equistrata_option,strata=&strata,samelib=no);

	/* create table to collect results of each iteration -- START */
proc sql; create table _acc_val like &model_identifier.&i._acc_val; quit;
proc append base=_acc_val data=&model_identifier.&i._acc_val; run; quit;
proc sql; drop table &model_identifier.&i._acc_val; quit;

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
	%model_count_base(&_infile_data_,&list_var_file,&path_for_binary_mdl_impl,&model_identifier.&i,&_distribution_,
&_seed_i_,trainvalidation=&trainvalidation,_trainfr_=&_trainfr_,train_with_equistrata=&train_with_equistrata,
equistrata_option=&equistrata_option,strata=&strata,samelib=no);

		/* append current iteration result to collecting tables -- START */
	proc append base=_acc_val data=&model_identifier.&i._acc_val; run; quit;
	proc sql; drop table &model_identifier.&i._acc_val; quit;

	proc append base=variables_importance data=&model_identifier.&i._vimpo;run;quit;
	proc sql; drop table &model_identifier.&i._vimpo; quit;

	proc append base=_valscr data=&model_identifier.&i._valscr;run;quit;
	proc sql; drop table &model_identifier.&i._valscr; quit;
		/* append current iteration result to collecting tables -- END */
%end;
/* execute model _repetition_ -1 times (necessary to easily initialize tables) -- END */

/* POST PROCESS RESULTS -- START */
/* sort data for PROC UNIVARIATE BY statement */
proc sort data=_valscr out=_valscr; by &id_variables; run; quit;
proc sort data=_acc_val out=_acc_val; by error_type stat_type; run; quit;

/* calculate average for variable importance -- START */
	/* POISSION or NEGBINOMIAL */
%if (%sysfunc(compare("POISSON","&_distribution_")) eq 0) or 
	(%sysfunc(compare("NEGBINOMIAL","&_distribution_")) eq 0)  %then %do;
	/* sort data for PROC UNIVARIATE BY statement */
	proc sort data=variables_importance out=variables_importance (where=(Probt<=0.05)); by Effect; run; quit;

	proc univariate data=variables_importance noprint;
		var Estimate;
		output out=&library..&model_identifier._vimpo N=ntimes_relevant mean=avg_Estimate;
		by Effect;
	run;
	proc sort data=&library..&model_identifier._vimpo out=&library..&model_identifier._vimpo; 
		by descending avg_Estimate;
	run;quit;
%end;
	/* ZERO INFLATED POISSON or ZERO INFLATED NEGBINOMIAL */
%if (%sysfunc(compare("ZIP","&_distribution_")) eq 0) or 
	(%sysfunc(compare("ZINB","&_distribution_")) eq 0)  %then %do;
	/* sort data for PROC UNIVARIATE BY statement */
	proc sort data=variables_importance out=variables_importance (where=(Probt<=0.05)); by Type Effect; run; quit;

	proc univariate data=variables_importance noprint;
		var Estimate;
		output out=&library..&model_identifier._vimpo N=ntimes_relevant mean=avg_Estimate;
		by Type Effect;
	run;
	proc sort data=&library..&model_identifier._vimpo out=&library..&model_identifier._vimpo; 
		by Type descending avg_Estimate;
	run;quit;
%end;
/* calculate average for variable importance -- END */

/* add extra variable to scored data set if we use zero inflated models */
%if (%sysfunc(compare("ZIP","&_distribution_")) eq 0) or 
	(%sysfunc(compare("ZINB","&_distribution_")) eq 0)  %then %do;
	%let extra_var=P_0;
%end;

/* calculate median GOOT (out of train) prediction and the accuracy of theis prediction on the OOT database */
proc univariate data=_valscr noprint;
	var predicted &extra_var;
	output out=&library..&model_identifier._valscr PCTLPRE=predicted &extra_var N=ntimes_oot pctlpts=5 50 95 pctlname=_q5 _median _q95;
	by &id_variables &target_variable;
run; 
%accuracy_interval(&library..&model_identifier._valscr,&library..&model_identifier._accGOOT,&target_variable,probvar=predicted_median);

/* calculate average of each battery model accuracy */
proc univariate data=_acc_val noprint;
	var stat_value;
	output out=&library..&model_identifier._accval PCTLPRE=stat_value pctlpts=5 50 95 pctlname=_q5 _median _q95;
	by error_type stat_type;
run;
proc sort data=&library..&model_identifier._accval out=&library..&model_identifier._accval; by error_type stat_value_median; run;quit;

/* remove temporary files */
proc sql; drop table variables_importance,_valscr,_acc_val; quit;

/* POST PROCESS RESULTS -- END */
%exit: %mend model_count_iteration;
