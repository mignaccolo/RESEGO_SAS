%macro rescale_probabilities_nominal(_original_file_,_train_file_,_scored_file_,_target_var_,_id_statement_,_filefactors_)
/ store source des="";

/* DESCRIPTION
Rescale probabilities for a binary target if proportion of levels was altered in the TRAIN data set. 
*/
 
/* PARAMETERS
1) _original_file_: name (SASLIBRARY.SASFILENAME) of the SAS table from which the TRAIN data set was generated.
2) _train_file_: name (SASLIBRARY.SASFILENAME) of the SAS table with the TRAIN data set.
3) _scored_file_: name (SASLIBRARY.SASFILENAME) of the SAS table with the scored records for which probabilities 
	need to be rescaled.
4) _target_var_: the name of the target variable.
5) _id_statement_: the list of ID variables (e.g. transaction id, customer id) separated by space that are in the scored records 
	input file.
6) _filefactors_:  a valid system path+filename so that &_filefactors_._probfac is the file containing the probability rescaling 
	factors used to score additional data sets.
*/

%put Executing: rescale_probabilities_nominal;
%local _id_statement_comma_; /* as id_statement but elements are separeted by comma  */

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

/* add conversion factors */
proc sql;
	create table _pre_output_ as 
		select a1.*,a1.p*a2.factor as new_p 
	from &_scored_file_ a1 inner join _conversion_ a2 
	on strip(a1.target_value)=strip(a2.target_value);
quit;

/* */
%let _id_statement_comma_=%sysfunc(tranwrd(&_id_statement_,%str( ),%str(,))); /* equal to _id_statement_, but different ID variable are separated by "," */

/* rescale probabilities */
proc sql;
	create table &_scored_file_ (drop=p new_p rename=(p2=p)) as 
		select *,new_p/sum(new_p) as p2
	from _pre_output_
	group by &_id_statement_comma_
	order by &_id_statement_comma_;	
quit;

/* remove temp files */
proc sql;
	drop table _pre_output_,_conversion_,freq_count_original,freq_count_train;
quit;

%mend rescale_probabilities_nominal;
