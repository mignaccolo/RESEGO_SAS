%macro rescale_probabilities_binary(_original_file_,_train_file_,_scored_file_,_target_var_,_filefactors_,_targety_=Y,_targetn_=N)
/ store source des="Rescale probabilities for a binary target if proportion of levels was altered in the TRAIN data set";

/* DESCRIPTION
Rescale probabilities for a binary target if proportion of levels was altered in the TRAIN data set 
*/
 
/* PARAMETERS
1) _original_file_: name (SASLIBRARY.SASFILENAME) of the SAS table from which the TRAIN data set was generated.
2) _train_file_: name (SASLIBRARY.SASFILENAME) of the SAS table with the TRAIN data set.
3) _scored_file_: name (SASLIBRARY.SASFILENAME) of the SAS table with the scored records for which probabilities 
	need to be rescaled.
4) _target_var_: the name of the target variable.
5) _filefactors_:  a valid system path+filename so that &_filefactors_._probfac is the file containing the probability rescaling 
	factors used to score additional data sets.
6) _targety_: value of the target variable which indicate an "event". By default _targety_=Y.
7) _targetn_: value of the target variable which indicate the lack of an  "event". By default _targetn_=N.
*/

%put Executing: rescale_probabilities_binary;
%local _factory_; /* factor for the value of the target variable corresponding to an event */
%local _factorn_; /* factor for the value of the target variable corresponding to a lack of an event */

/* find target frequency in the "original" data set */
proc freq data=&_original_file_ noprint;
	table &_target_var_ / out=freq_count_original;
run; quit;

/* find target frequency in the "train" data set */
proc freq data=&_train_file_ noprint;
	table &_target_var_ / out=freq_count_train;
run;quit;

/* calculate conversion factors */
proc sql;
	create table _conversion_ as 
		select a1.&_target_var_ as target_value,a1.PERCENT/a2.PERCENT as factor from
		freq_count_original  a1 inner join freq_count_train a2
		on a1.&_target_var_=a2.&_target_var_;
quit;

/* save factor information for scoring additional data sets */
filename pfac "&_filefactors_._probfac";
data _null_;
	file pfac;
	set _conversion_;
	put target_value factor;
run;

/* save conversion factors on macro variables */
proc sql noprint;
	select factor into: _factory_ from _conversion_ where target_value eq "&_targety_";
	select factor into: _factorn_ from _conversion_ where target_value eq "&_targetn_";
quit;

/* rescale probabilities */
data &_scored_file_ (drop=p rename=(newp=p));
	set &_scored_file_;
	newp=p*&_factory_/(p*&_factory_+(1-p)*&_factorn_);
run;

/* remove temp files */
proc sql; drop table freq_count_original,freq_count_train,_conversion_;quit;

%mend rescale_probabilities_binary;
