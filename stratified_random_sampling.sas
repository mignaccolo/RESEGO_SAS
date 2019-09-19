%macro stratified_random_sampling (_infile_data_,list_var_file,_output_base_filename_,_seed_,_frac_=0.7,_nrep_=1,_mylib_=work,_strata_=target)/ 
store source des="Split input data in TRAIN and VALIDATION data set according to a specific proportion: without replacement";

/* DESCRIPTION
Split input data in TRAIN and VALIDATION data set according to a specific proportion while keeping the same 
proportion (in TRAIN and VALIDATION data sets) of a given strata (i.e. strata= the target variable ito be used in the mode) 
TRAIN and VALIDATION data set are created in the work library unless a specific library is defined via _mylib_ parameter.
*/

/* PARAMETERS
1) _infile_data_: name (SASLIBRARY.SASFILENAME) of the SAS table to split 
2) list_var_file: ame (SASLIBRARY.SASFILENAME) of the SAS table with the type and scope of each variable in the data set to split
	i.e. if only a set of variable is of interest for modelling the value 'XX' in the colum LEGEND of &list_var_file identifyt the variable 
	to not include in the TRAIN and VALIDATION outputs.
3) _output_base_filename_: Final output will be SASLIBRARY.&_output_base_filename_._TR&seed., SASLIBRARY.&_output_base_filename_._VL&seed.
	i.e. _output_base_filename_=mysample, seed=1234 and _mylib_=work => output: work.mysample_TR1234 and work.mysample_VL1234
4) _seed_: seed of the random number generator
5) _frac_: fraction of the number of records in the input SAS data set which go in the 
6) _nrep_: number of repetition of the sampling procedure
	by default this is set to 1. If _nrep_>1 different sampling instances in the TRAIN and VALIDATION data set will be indicated by the variable Replicate
7) _mylib_: the SAS library where TRAIN and VALIDATION data set are created
8) _strata_: the name of the variable to use as strata. By default the target variable (as specified by the SAS table &list_var_file is used as strata)
*/

%put Executing: stratified_random_sampling;
%local variable_to_remove; /* list of variable to remove */
%local drop_statement;/* drop statement: empty if there are no variable/s to remove */
%local drop_replicate; /* drop_replicate is empty if _nrep_>1 drop_replicate=Replicate if _nrep_=1: drop variable Replicate if _nrep_=1 */ 
%local _issorted_; /* flag (=1) determining if input data set is sorted by the desired strata */
%local _filename_; /* name of the SAS data set which is the input of PROC SURVEYSELECT: 
if input data set is already sorted according to the desired strata then _filename_=_infile_data_ else _filename_="work._sorted_"*/

/* check if there are variables to remove -- START */
/* initialize macro variables for the list of variable to remove and the drop statement */
%let variable_to_remove=;%let drop_statement=;

/* procure list of variable/s to remove */
proc sql NOPRINT;
	select VARNAME into: variable_to_remove separated by ' '  from &list_var_file where LEGEND eq 'XX';
quit;

/* if there are any variable/s to remove then build proper drop statement */
%if %sysevalf(%superq(variable_to_remove)=,boolean) eq 0 %then %do;
	%let drop_statement=%str(%(drop= )&variable_to_remove.%str(%));
%end;
/* */
/* check if there are variables to remove -- END */

/* check if the strata to be used is the target variable -- START */
%if %sysfunc(compare("&_strata_","target")) eq 0 %then %do;
	proc sql NOPRINT;select VARNAME into: _strata_ from &list_var_file where LEGEND eq 'TG';quit;
%end;
/* check if the strata to be used is the target variable -- END */

/* check if data are sorted according to the wanted strata if not sort them -- START */
proc contents nodetails noprint
	data=&_infile_data_ out=work._contents_ (keep=NAME SORTEDBY);
run; quit;

proc sql NOPRINT; select SORTEDBY into: _issorted_ from work._contents_ where NAME eq "&_strata_"; quit;

	/* if data are not sorted the sort them and set _filename_ to _sorted_ as this is the new input data set for proc surveyselect */
%if %sysevalf(&_issorted_ ne 1) %then %do;
	proc sort data=&_infile_data_ out=work._sorted_; by &_strata_;run;quit;
	%let _filename_=work._sorted_;
%end;
/* check if data are sorted according to the wanted strata if not sort them -- END */

/* make stratified selection */
proc surveyselect data=&_filename_ &drop_statement 
	NOPRINT
	outall
	out=outboot (drop=AllocProportion Total SampleSize ActualProportion SelectionProb SamplingWeight)
	seed=&_seed_
	method=srs
	samprate=&_frac_
	rep=&_nrep_;
	strata &_strata_ / alloc=proportional;
run;


/* split  samples in train and test data set */
%let drop_replicate=;
%if %sysevalf(&_nrep_ eq 1) %then %do; %let drop_replicate=Replicate;%end;

data &_mylib_..&_output_base_filename_._TR&_seed_. (drop=Selected &drop_replicate) &_mylib_..&_output_base_filename_._VL&_seed_. (drop=Selected &drop_replicate);
	set work.outboot;
	if Selected eq 1 then output &_mylib_..&_output_base_filename_._TR&_seed_.; else output &_mylib_..&_output_base_filename_._VL&_seed_.;
run;

/* remove temporary files */
proc sql; drop table outboot,_contents_; quit;
%if %sysevalf(&_issorted_ ne 1) %then %do; proc sql; drop table _sorted_;quit;%end; /* drop sorted data set once sampling is done */

%mend stratified_random_sampling;
