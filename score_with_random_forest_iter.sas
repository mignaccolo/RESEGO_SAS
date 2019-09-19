%macro score_with_random_forest_iter(_repetition_,_infile_data_score_,_outfile_data_score_,list_var_file,
path_for_binary_mdl_impl,model_identifier,_target_type_,_targety_=Y,_targetn_=N,_length_target_=32)/ store source des="";

/* DESCRIPTION
Score a data set with a "battery" of Random Forest models.
*/

/* PARAMETERS
1) _repetition_: the number of models in the "battery". 
2) infile_data_score_: name (SASLIBRARY.SASFILENAME) of the SAS table from which the TRAIN data set was generated.
3) _outfile_data_score_: name (SASLIBRARY.SASFILENAME) of the SAS table with the TRAIN data set.
4) list_var_file: name (SASLIBRARY.SASFILENAME) of the SAS table with the type and scope of each variable in the _infile_data_ data set.
5) path_for_binary_mdl_impl: a valid system path were binary implementation of the model can be stored to score additional data sets.
6) model_identifier: a string identifiying the model specification e.g. RANFOR_example_1. 
	(Note that if we have ,e.g., 10 models in the battery they are identified as model_identifier1,model_identifier2,.....,model_identifier10  
7) _target_type_: ("binary","nominal","interval") The type of the target variable.
8) _targety_: value of the target variable which indicate an "event". By default _targety_=Y. (Used only when target is binary).
9) _targetn_: value of the target variable which indicate the lack of an  "event". By default _targetn_=N. (Used only when target is binary).
10) _length_target_: the "string" length of the binary/nominal variable. The default value _length_target_=32 should ensure that the 
	levels of the target variable are not trucate: ifa possible value of the target variable is a string of 40 chars, 
	only the first 32 will be reported.
*/

%put Executing: score_with_random_forest_iter;

/* declare variables */
%local target_variable; /* the name of the target variable  */
%local id_variables; /* the variable/ identifying a records (e.g. person id ,transaction id) which we want to display when scoring a data set */ 
%local i; /* loop parameter */
%local id_statement; /* ID statement for PROC UNIVARIATE */

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

/* define ID statement for PROC UNIVARIATE */
%let id_statement=&id_variables;

/* check if data set to score contains the target variable. if so add target variable to the list of varible to keep in the scored file -- START */
proc datasets nodetails nolist; 
   contents data=&_infile_data_score_ out=_contents_ (keep=NAME LENGTH where=(strip(NAME)="&target_variable"));
run;

%let dsempty=0;
data _null_;
	if eof then do;call symput('dsempty',1);end;
	stop;
	set  _contents_ end=eof;
run;

/* update id statement if target variable is not in the data set */
%if %sysfunc(compare("0","&dsempty")) eq 0 %then %do;
	%let id_statement=&id_statement.%str( )&target_variable;
%end;

/* Score first model of the battery  -- START */
%let i=1;
%score_with_random_forest_base(&_infile_data_score_,_temp_score_&i,&list_var_file,&path_for_binary_mdl_impl,&model_identifier.&i,
&_target_type_,_targety_=&_targety_,_targetn_=&_targetn_,_length_target_=&_length_target_);

/* create table collecting the scores for each model in the battery */
proc sql; create table _temp_score_ like _temp_score_&i; quit;

/* append score first model + remove first model score */
proc append base=_temp_score_ data=_temp_score_&i; run; quit;
proc sql; drop table _temp_score_&i; quit;
/* Score first model of the battery  -- END */

/* Score remaining models in the battery  -- START */
%do i=2 %to &_repetition_ %by 1;
	%score_with_random_forest_base(&_infile_data_score_,_temp_score_&i,&list_var_file,&path_for_binary_mdl_impl,&model_identifier.&i,
&_target_type_,_targety_=&_targety_,_targetn_=&_targetn_,_length_target_=&_length_target_);

	/* append score i-th model + remove i-th model score */
	proc append base=_temp_score_ data=_temp_score_&i; run; quit;
	proc sql; drop table _temp_score_&i; quit;	
%end;
/* Score remaining models in the battery  -- END */

/* generate battery score  when target is binary */
%if %sysfunc(compare("binary","&_target_type_")) eq 0 %then %do;
	/* sort model battery score by id_variables */
	proc sort data=_temp_score_ out=_temp_score_;
		by &id_statement;
	run; quit;

	/* calculate score statistics for the battery of models */
	proc univariate data=_temp_score_ noprint;
		var p;
		output out=&_outfile_data_score_ PCTLPRE=p pctlpts=5 50 95 pctlname=_q5 _median _q95;
	by &id_statement;
	run; 
%end;

/* generate battery score  when target is interval */
%if %sysfunc(compare("interval","&_target_type_")) eq 0 %then %do;
	/* sort model battery score by id_variables */
	proc sort data=_temp_score_ out=_temp_score_;
		by &id_statement;
	run; quit;

	/* calculate score statistics for the battery of models */
	proc univariate data=_temp_score_ noprint;
		var predicted;
		output out=&_outfile_data_score_ PCTLPRE=predicted pctlpts=5 50 95 pctlname=_q5 _median _q95;
	by &id_statement;
	run; 
%end;

/* generate battery score  when target is nominal */
%if %sysfunc(compare("nominal","&_target_type_")) eq 0 %then %do;
	/* sort model battery score by id_variables */
	proc sort data=_temp_score_ out=_temp_score_;
		by &id_statement target_value;
	run; quit;

	/* calculate score statistics for the battery of models */
	proc univariate data=_temp_score_ noprint;
		var p;
		output out=&_outfile_data_score_ PCTLPRE=p pctlpts=5 50 95 pctlname=_q5 _median _q95;
	by &id_statement target_value;
	run; 
%end;

/* remove temporary files */
proc sql;drop table _temp_score_;quit;

%exit: %mend score_with_random_forest_iter;
