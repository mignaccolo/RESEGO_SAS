%macro accuracy_roc(_input_file_,_output_file_,_target_var_,probvar=p,_targety_=Y,_targetn_=N)
/ store source des="Calculate receiver operating characteristic (ROC) statistics when target is binary";

/* DESCRIPTION
Given a file of scored records for a binary variable, it calculates the receiver operating characteristic (ROC) statistics:
1) TP, FN, TN, FP, Detection Efficiency (DE) or sensitivity, False Positive Rate (FPR), False Alarm rate (FA), and 
c-score (area under the ROC curve).
*/

/* PARAMETERS
1) _infile_data_: name (SASLIBRARY.SASFILENAME) of the SAS table contained scored records.
2) _output_file_: name (SASLIBRARY.SASFILENAME) of the SAS table where to store the accuracy output.
3) _target_var_: the name of the target variable.
4) probvar: the name of the variable indicating the predicted value in the scored records file.
5) _targety_: value of the target variable which indicate an "event". By default _targety_=Y.
6) _targetn_: value of the target variable which indicate the lack of an  "event". By default _targetn_=N.
*/

%put Executing: accuracy_roc;
%local i;
/* Calculates ROC statistics for each probability in [0,1] at 0.01 step interval (=1%) */
%let p_step=100;

/* define pre ROC table */
proc sql;
	create table pre_roc_  
		( 
			p_threshold num label="Probability Threshold",
			TP num label="True Positive",
			FN num label="False Negative",
			TN num label="True Negative",
			FP num label="False Positive"
		);
quit;

/* calculate TP,FN,FP,TN for each value of the probability */
%do i=0 %to &p_step %by 1;

	proc sql;
		create table _roc1_&i. as 
		select &i/&p_step as p_threshold,
		sum(case when &probvar ge &i/&p_step and &_target_var_ eq "&_targety_" then 1 else 0 end) as TP,
		sum(case when &probvar < &i/&p_step and &_target_var_ eq "&_targety_" then 1 else 0 end) as FN,
		sum(case when &probvar ge &i/&p_step and &_target_var_ eq "&_targetn_" then 1 else 0 end) as FP,
		sum(case when &probvar < &i/&p_step and &_target_var_ eq "&_targetn_" then 1 else 0 end) as TN
		from &_input_file_;
	quit;
	proc append base=pre_roc_ data=_roc1_&i.; run; quit;
	proc sql; drop table _roc1_&i.; quit;
%end;

/* calculate DE,FRP,FA */
proc sql; 
	create table _roc_ as 
		select *,TP/(TP+FN) as DE label="Detection Efficiency", FP/(FP+TN) as FPR label="False Positive Rate", FP/(TP+FP) as FA label="False Alarm"
	from pre_roc_;

	drop table pre_roc_;
quit;
	

/* add previous values of DE and FPR to the roc data set: this is to calculate the area under the curve */
data _pre_out_ (drop=curr_fpr prev_fpr);
	set _roc_;
	curr_fpr=fpr;prev_fpr=lag(fpr);prev_de=lag(de);
	if p_threshold=0 then do; 
		delta_fpr=0;prev_de=1;
	end;
	else do;
		delta_fpr=prev_fpr-curr_fpr;
	end;
run;

/* calculate area under the curve */
proc sql;
	create table _pre_c_score as 
	select (sum(delta_fpr*prev_de)+sum(delta_fpr*de))/ 2 as c_score
	from _pre_out_;
quit; 

/* prepare output table */
proc sql;
	create table &_output_file_ as 
	select distinct  a1.p_threshold,a1.TP,a1.FN,a1.TN,a1.FP,
		a1.de,a1.fpr,a1.fa,a2.c_score
	from _pre_out_ a1, _pre_c_score a2;
quit;

/* remove temp files */
proc sql; drop table _roc_,_pre_out_,_pre_c_score;quit;

%mend accuracy_roc;
