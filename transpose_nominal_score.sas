%macro transpose_nominal_score(_scored_file_,_id_statement_,_target_var_=)
/ store source des="";

/* DESCRIPTION
Transpose the core output in case of a nominal target so that we have a "long" (1 column for probability, multiple rows for the levels of the nominal variable) data set 
	instead of a wide one (one column for the probability of each level, unique row for the record scored).
*/
 
/* PARAMETERS
1) _scored_file_: name (SASLIBRARY.SASFILENAME) of the SAS table with the scored records for which probabilities 
	need to be rescaled.
2) _id_statement_: the list of ID variables (e.g. transaction id, customer id) separated by space that are in the scored records 
	input file.
3) _target_var_: the name of the target variable (missing by default -> for scoring data  sets where the target value is unknown).
*/

%put Executing: transpose_nominal_score;
%local _id_statement_comma_; /* as id_statement but elements are separeted by comma */
%local _keep_statement_; /* for keep statements */
%local _keep_statement_comma_; /* as keep_statement but elements are separeted by comma */

%let _id_statement_comma_=%sysfunc(tranwrd(&_id_statement_,%str( ),%str(,))); 
%let _keep_statement_=&_id_statement_.%str( )&_target_var_;
%let _keep_statement_comma_=%sysfunc(tranwrd(%sysfunc(strip(&_keep_statement_)),%str( ),%str(,))); /* strip is necessary when &_target_var_ 
	is missing. Otherwise, we have an extra comma */


/* sort scored file by ID variables. This is necessary for transposing */
proc sort data=&_scored_file_ out=_sorted_scored_file_;
	by &_id_statement_;
run;quit;

/* transpose the scored file so that we have one single column (p) with probabilities, and a column (_NAME_) which contains the values of the arget variable */
proc transpose data=_sorted_scored_file_ out=_xposed_sorted_scored_file_ (drop=_LABEL_ rename=(Col1=p));
	by &_id_statement_;
	var P_&_target_var_.:;
run;quit;

/* rename variables on transposed probability file */
proc sql;
	create table _tomerge_ (drop=_NAME_) as 
	select *,TRANWRD(_NAME_,"P_&_target_var_.","") as target_value
		from _xposed_sorted_scored_file_;
quit; 

/* create temp file with combination of ID variables and target variable values */
proc sql;
	create table _target_info_ (keep=&_keep_statement_) as 
		select * from _sorted_scored_file_;
quit;

/* merge id varibles + target variable values + probabilities */
data _merged_;
	merge
	work._tomerge_ (in=a)
	work._target_info_ (in=b);
	by &_id_statement_; if a;
run;

/* create new scored file */
proc sql;
	create table &_scored_file_ as 
		select &_keep_statement_comma_.,target_value,p 
	from _merged_;
quit;

/* remove temp files */
proc sql;
	drop table _merged_,_target_info_,_tomerge_,_sorted_scored_file_,_xposed_sorted_scored_file_;
quit;

%mend transpose_nominal_score;
