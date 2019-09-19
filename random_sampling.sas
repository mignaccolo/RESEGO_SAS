%macro random_sampling (_infile_data_,list_var_file,_output_base_filename_,_seed_,_frac_=0.7,_nrep_=1,
_mylib_=work)/ 
store source des="Split input data in TRAIN and VALIDATION data set according to a specific proportion: without replacement";

/* DESRIPTION
Split input data in TRAIN and VALIDATION data set according to a specific proportion 
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
*/

%put Executing: random_sampling;
%local variable_to_remove; /* list of variable to remove */
%local drop_statement;/* drop statement: empty if there are no variable/s to remove */
%local drop_replicate; /* drop variable Replicate if _nrep_=1: drop_replicate is empty if _nrep_>1 drop_replicate=Replicate if _nrep_=1 */ 

/* check if there are variables to remove -- START */

/* initialize macro variables for the list of variable to remove and the drop statement */
%let variable_to_remove=;%let drop_statement=;

/* procure list of variable/s to remove */
proc sql NOPRINT;
	select VARNAME into: variable_to_remove separated by ' '  from &list_var_file where LEGEND eq 'XX';
quit;

/* if there are any variable to remove then build proper drop statement */
%if %sysevalf(%superq(variable_to_remove)=,boolean) eq 0 %then %do;
	%let drop_statement=%str(%(drop= )&variable_to_remove.%str(%));
%end;
/* */

/* make bootstrap selections */
proc surveyselect data=&_infile_data_ &drop_statement
	NOPRINT
	outall
	out=outboot
	seed=&_seed_
	method=srs
	samprate=&_frac_
	rep=&_nrep_;
run;

/* split bootstrap samples in train and test data set */
%let drop_replicate=;
%if %sysevalf(&_nrep_ eq 1) %then %do; %let drop_replicate=Replicate;%end;

data &_mylib_..&_output_base_filename_._TR&_seed_. (drop=Selected &drop_replicate) &_mylib_..&_output_base_filename_._VL&_seed_. (drop=Selected &drop_replicate);
	set work.outboot;
	if Selected eq 1 then output &_mylib_..&_output_base_filename_._TR&_seed_.; else output &_mylib_..&_output_base_filename_._VL&_seed_.;
run;

/* remove temporary files */
proc sql; drop table outboot; quit;

%mend random_sampling;
