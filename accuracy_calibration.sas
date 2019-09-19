%macro accuracy_calibration(_input_file_,_output_file_,_target_var_,probvar=p,_pstep_=0.01,_targety_=Y,_targetn_=N)
/ store source des="Calculate receiver operating characteristic (ROC) statistics when target is binary";

/* DESCRIPTION
Given a file of scored records for a binary variable, it calculates .
*/

/* PARAMETERS
1) _infile_data_: name (SASLIBRARY.SASFILENAME) of the SAS table contained scored records.
2) _output_file_: name (SASLIBRARY.SASFILENAME) of the SAS table where to store the accuracy output.
3) _target_var_: the name of the target variable.
4) probvar: the name of the variable indicating the predicted value in the scored records file.

5) _targety_: value of the target variable which indicate an "event". By default _targety_=Y.
6) _targetn_: value of the target variable which indicate the lack of an  "event". By default _targetn_=N.
*/

%put Executing: accuracy_calibration;

/* define output table table */
proc sql;
	create table &_output_file_  
		( 
			int_prob num label="Probability",
			perc_events num label="Percentage Events",
			target_prob num label="Target Percentage",
			N_cases_prob_bin num label="Number Cases in Probability bin",
			N_records_prob_bin num label="Number Records in Probability bin",
			N_tot_records num label="Number Records"
		);
quit;

/* */
proc sql;
	create table _temp1_ as 
		select &probvar,&_target_var_,int(&probvar/&_pstep_)*&_pstep_ as int_prob,count(*) as N_tot_records
	from &_input_file_;
quit;

/* */
proc sql; 
	create table _temp2_ as 
		select distinct int_prob,
		sum(case when &_target_var_ eq "&_targety_" then 1 else 0 end)/count(&_target_var_) as perc_events,
		int_prob as target_prob,
		sum(case when &_target_var_ eq "&_targety_" then 1 else 0 end) as N_cases_prob_bin,
		count(&_target_var_) as N_records_prob_bin,
		N_tot_records
	from _temp1_
	group by int_prob;	
quit;

/* */
proc append base=&_output_file_ data=_temp2_; run; quit;

/* remove temp files */
proc sql; drop table _temp1_,_temp2_;quit;

%mend accuracy_calibration;
