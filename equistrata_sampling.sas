%macro equistrata_sampling(_indata_train_,list_var_file,_outdata_train_,_seed_,_mylib_=work,_strata_=target,_equalizewith_=tomin)/
store source des="Generate train data set with equal proportion binary/nominal target";

/* DESCRIPTION
Generate train data set with equal proportion levels (same occurrence frequency of each value) for binary/nominal target.
*/

/* PARAMETERS 
1) _indata_train_: name (SASLIBRARY.SASFILENAME) of the SAS table with the TRAIN data to undersample 
2) list_var_file: ame (SASLIBRARY.SASFILENAME) of the SAS table with the type and scope of each variable in the data set to split
	i.e. if only a set of variable is of interest for modelling the value 'XX' in the colum LEGEND of &list_var_file identifyt the variable 
	to not include in the TRAIN and VALIDATION outputs.
3) _outdata_train_: name (SASLIBRARY.SASFILENAME) of the SAS table wtih the undersampled TRAIN data set.
4) _seed_: seed of the random number generator
5) _mylib_: the SAS library where TRAIN and VALIDATION data set are created
6) _strata_: the name of the variable to use as strata. By default the target variable (as specified by the SAS table &list_var_file is used as strata)
7) _equalizewith_: the type of sampling to adopt to reach an equistrata dataset. 
	Options are: 
	1)tomin = sampling without replacement to produce a data set where all strata have the same number of records as the less frequent strata 
	2)tomax = sampling with replacement to produce a data set where all strata have the same number of records as the most frequent strata 
	3)logmean = sampling with replacement to produce a data set where all strata have a number records which logarithm is the the average between the log of the 
		number of records of the more frequent strata and the less frequent strata
*/

%put Executing: equistrata_sampling;
%local perc_more; /* percentage of dominat target = &tmore  */
%local perc_less; /* percentage of not dominant target = &tless */
%local _issorted_; /* flag (=1) determining if input data set is sorted by the desired strata */
%local _filename_; /* name of the SAS data set which is the input of PROC SURVEYSELECT: 
if input data set is already sorted according to the desired strata then _filename_=_infile_data_ else _filename_="work._sorted_"*/

/* check if the strata to be used is the target variable -- START */
%if %sysfunc(compare("&_strata_","target")) eq 0 %then %do;
	proc sql NOPRINT;select VARNAME into: _strata_ from &list_var_file where LEGEND eq 'TG';quit;
%end;
/* check if the strata to be used is the target variable -- END */

/* check if data are sorted according to the wanted strata if not sort them -- START */
proc contents nodetails noprint
	data=&_indata_train_ out=work._contents_ (keep=NAME SORTEDBY);
run; quit;

proc sql NOPRINT; select SORTEDBY into: _issorted_ from work._contents_ where NAME eq "&_strata_"; quit;

	/* if data are not sorted the sort them and set _filename_ to _sorted_ as this is the new input data set for proc surveyselect */
%if %sysevalf(&_issorted_ ne 1) %then %do;
	proc sort data=&_indata_train_ out=work._sorted_; by &_strata_;run;quit;
	%let _filename_=work._sorted_;
%end;
/* check if data are sorted according to the wanted strata if not sort them -- END */

/* find the percentage of the two outcomes of a binary target and prepare data set for "equal" sampling in PROC SURVEYSELECTS -- START */

	/* find frequenct percentage of binary target in the input train data set */
proc freq data=&_filename_ noprint;
	tables &_strata_ / out=_freq_1;
run;

	/* find the target valuewith the max frequency count */
proc sql;
	create table _freq_2 as 
	select *,max(COUNT) as maxc,min(COUNT) as minc
	from _freq_1;
quit;

/* PRODUCE EQUI STRATA DATA SET -- START */

	/* TOMIN PROCEDURE */
%if %sysfunc(compare("&_equalizewith_","tomin")) eq 0 %then %do;
	/* prepare the sampling rate file */
	proc sql;
		create table _freq_3 (drop=maxc minc) as 
		select *,case when COUNT ne minc then (minc/COUNT) else 1 end as _RATE_
		from _freq_2;
	quit;

	/* create the balanced TRAIN data set */
	proc surveyselect data =&_filename_ out=&_outdata_train_(drop=SamplingWeight SelectionProb)
		method=srs samprate=work._freq_3 seed=&_seed_ noprint;
		strata &_strata_;
	run;
%end;

	/* TOMAX PROCEDURE */
%if %sysfunc(compare("&_equalizewith_","tomax")) eq 0 %then %do;
	/* prepare the sampling size file */
	proc sql;
		create table _freq_3 (drop=maxc minc) as 
		select *,maxc as _NSIZE_
		from _freq_2;
	quit;

	/* create the balanced TRAIN data set */
	proc surveyselect data =&_filename_ out=_train_ (drop=SamplingWeight)
		method=urs sampsize=work._freq_3 seed=&_seed_ noprint;
		strata &_strata_;
	run;

	/* we use this data step so that a record selected n time is actually copied n times in the final TRAIN data set */
	/* A rationale for this choice is that PROC HPFOREST does not use a "Frequency" variable when counting the records in a leaf 
		(e.g a record with frequency 5 will still count as one for the purpose of counting records in a leaf) */ 
	data &_outdata_train_ (drop=NumberHits i);
		set _train_;
		do i=1 to NumberHits by 1;
			output;
		end;
	run;

	/* remove temp train file */
	proc sql; drop table _train_;quit;
%end;

	/* LOGMEAN PROCEDURE */
%if %sysfunc(compare("&_equalizewith_","logmean")) eq 0 %then %do;
	/* prepare the sampling size file */
	proc sql;
		create table _freq_3 (drop=maxc minc) as 
		select *,round(10**((log10(maxc)+log10(minc))/2),1) as _NSIZE_
		from _freq_2;
	quit;

	/* create the balanced TRAIN data set */
	proc surveyselect data =&_filename_ out=_train_ (drop=SamplingWeight)
		method=urs sampsize=work._freq_3 seed=&_seed_ noprint;
		strata &_strata_;
	run;

	/* we use this data step so that a record selected n time is actually copied n times in the final TRAIN data set */
	/* A rationale for this choice is that PROC HPFOREST does not use a "Frequency" variable when counting the records in a leaf 
		(e.g a record with frequency 5 will still count as one for the purpose of counting records in a leaf) */ 
	data &_outdata_train_ (drop=NumberHits i);
		set _train_;
		do i=1 to NumberHits by 1;
			output;
		end;
	run;

	/* remove temp train file */
	proc sql; drop table _train_;quit;
%end;

/* PRODUCE EQUI STRATA DATA SET -- END */

/* remove temp files */
proc sql; drop table _contents_,_freq_1,_freq_2,_freq_3;quit;

/* if data are sorted drop the sorted file */
%if %sysevalf(&_issorted_ ne 1) %then %do;
	proc sql;drop table _sorted_; quit;
%end;

%mend equistrata_sampling;
