%macro accuracy_nominal(_input_file_,_output_file_,_target_var_,_id_statement_,probvar=p)
/ store source des="Calculate model accuracy when the target is nominal";

/* DESCRIPTION
Given a table of scored records, it calculates for each observed level of the nominal target the frequency distributions of 
predicted levels, namely: f(Lj|Li) = the frequency with which level Lj is predicted when Li is the observed level. A perfect 
model would have f(Lj|Li)=0 if j is different from i and f(Lj|Li)=1 if j=i.
*/

/* PARAMETERS
1) _infile_data_: name (SASLIBRARY.SASFILENAME) of the SAS table contained scored records (must a predicted and scored value)
2) _output_file_: name (SASLIBRARY.SASFILENAME) of the SAS table where to store the accuracy output.
3) _target_var_: the name of the target variable
4) _id_statement_: the list of ID variables (e.g. transaction id, customer id) separated by space that are in the scored records 
	input file
5) probvar: the name of the variable indicating the probability of observing a given level in the scored records file
*/

%put Executing: accuracy_nominal;
%local _id_statement_comma_; /* equal to _id_statement_, but different ID variable are separated by "," */
/* */

/* create the list of ID variables with a sepaating comma in between (to use in proc sql) */
%let _id_statement_comma_=%sysfunc(tranwrd(&_id_statement_,%str( ),%str(,)));

/* for each scored record, find the level with the highest probability=predicted level */
proc sql;
	create table _temp1_ as 
		select *,max(&probvar) as _maxp_
		from &_input_file_
	group by &_id_statement_comma_
	order by &_target_var_;
quit;

/* select for each record the level with max probability as predicted_value and calcualte f(Lj|Li) */
proc freq data=_temp1_ (where=(&probvar=_maxp_) rename=(target_value=predicted_value)) noprint;
	tables predicted_value / out=_temp2_  scores=table;
	by &_target_var_;
run;

/* prepare final output table */
proc sql;
	create table &_output_file_ as 
	select &_target_var_ label="Observed Value",predicted_value label="Predicted Value",
		COUNT label="Count",PERCENT label="Percent Frequency" format=6.2
	from _temp2_;
quit;

/* remove temp files */
proc sql; drop table _temp1_,_temp2_;quit;

%mend accuracy_nominal;
