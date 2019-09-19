%macro accuracy_interval(_input_file_,_output_file_,_target_var_,probvar=predicted,do_unit=N)
/ store source des="Calculate model accuracy when the target is interval (continuous variable)";

/* DESCRIPTION
Given a table of scored records, it calculates the root mean square error (global measure). 
Moreover for each record the absolute error and the relative error is calculated: as an indication 
of model performance the quantiles of these two errors is reported. 
Finally there is an option to calculate the relative error after rounding to unity the predicted value.
*/

/* PARAMETERS
1) _infile_data_: name (SASLIBRARY.SASFILENAME) of the SAS table contained scored records.
2) _output_file_: name (SASLIBRARY.SASFILENAME) of the SAS table where to store the accuracy output.
3) _target_var_: the name of the target variable.
4) probvar: the name of the variable indicating the predicted value in the scored records file.
5) do_unit: flag indicating if to calcualte relative error after rounding up prediction.
*/

%put Executing: accuracy_interval;
%local do_unit_statement; /* statement to create the unit square error */

/* check if we are discretizing our prediction */ 
%if  %sysfunc(compare("Y","&do_unit")) eq 0 %then %do; 
	%let do_unit_statement = %str(,abs%(int%(&probvar.%)-)&_target_var_.%str(%) as abs_unit_error);
%end;

/* create square error (unit square error if requested) variables */
proc sql;
	create table _temp1_ as 
	select &_target_var_,&probvar.,(&probvar.-&_target_var_)**2 as square_error,
		abs(&probvar.-&_target_var_) as abs_error,
		case when &_target_var_ ne 0 then ((&probvar.-&_target_var_)/&_target_var_)*100 else . end as rel_error
	&do_unit_statement
	from &_input_file_;
quit;

/* Define Output Statistical file */
proc sql;
	create table &_output_file_
		(
			error_type char(22),stat_type char(12),stat_value num format=6.2
		);
quit;

/* Calculate overall Root mean square Error */
proc sql;
	create table _to_stats_1 as 
		select distinct "root mean square error" as error_type length=22,
		"---" as stat_type, sqrt(avg(square_error)) as stat_value
	from _temp1_;
quit;

/* calculate absolute error statistics -- START */
	/* proc univariate for main statistics */
proc univariate data=_temp1_ NOPRINT;
	var abs_error;
	output out=_abs_stats_ mean=avg p1=q1 p5=q5 p25=q25 p50=median p75=q75 p95=q95 p99=q99;
run;quit;
                
	/* transpose the data */
proc transpose data=_abs_stats_ out=_abs_stats_1;
	VAR avg q1 q5 q25 median q75 q95 q99;
run;quit;

	/* prepare file to append to final output */
proc sql;
	create table _to_stats_2 as 
		select "absolute error" as error_type length=22,
		_NAME_ as stat_type length=12,
		COL1 as stat_value
	from _abs_stats_1;
quit;
/* calculate absolute error statistics -- END */

/* calculate relative error statistics -- START */
	/* proc univariate for main statistics */
proc univariate data=_temp1_ NOPRINT;
	var rel_error;
	output out=_rel_stats_ mean=avg p1=q1 p5=q5 p25=q25 p50=median p75=q75 p95=q95 p99=q99;
run;quit;

	/* transpose the data */
proc transpose data=_rel_stats_ out=_rel_stats_1;
	VAR avg q1 q5 q25 median q75 q95 q99;
run;quit;

	/* prepare file to append to final output */
proc sql;
	create table _to_stats_3 as 
		select "relative error" as error_type length=22,
		_NAME_ as stat_type length=12,
		COL1 as stat_value
	from _rel_stats_1;
quit;
/* calculate absolute error statistics -- END */

/* append data for final output */
proc append base=&_output_file_ data=_to_stats_1;run;quit;
proc append base=&_output_file_ data=_to_stats_2;run;quit;
proc append base=&_output_file_ data=_to_stats_3;run;quit;


/* remove temp files */
proc sql; 
	drop table _to_stats_1,_to_stats_2,_abs_stats_,_abs_stats_1,
		_to_stats_3,_rel_stats_,_rel_stats_1; 
quit;

/* if we do force prediction to be integer: calculate error stats -- START */
%if  %sysfunc(compare("Y","&do_unit")) eq 0 %then %do;
	/* calculate absolute error statistics -- START */
		/* proc univariate for main statistics */
	proc univariate data=_temp1_ NOPRINT;
		var abs_unit_error;
		output out=unit_abs_stats_ mean=avg p1=q1 p5=q5 p25=q25 p50=median p75=q75 p95=q95 p99=q99;
	run;quit;
	
		/* transpose the data */
	proc transpose data=unit_abs_stats_ out=unit_abs_stats_1;
		VAR avg q1 q5 q25 median q75 q95 q99;
	run;quit;

		/* prepare file to append to final output */
	proc sql;
	create table _to_stats_3 as 
		select "unit absolute error" as error_type length=22,
		_NAME_ as stat_type length=12,
		COL1 as stat_value
	from unit_abs_stats_1;
	quit;
	/* calculate absolute error statistics -- END */

		/* append data for final output */
	proc append base=&_output_file_ data=_to_stats_3;run;quit;

		/* remove temp files */
	proc sql; drop table _to_stats_3,unit_abs_stats_,unit_abs_stats_1; quit;
%end;
/* if we do force prediction to be integer: calculate error stats -- END*/

/* remove temp files */
proc sql; drop table _temp1_;quit;
	
%mend accuracy_interval;
