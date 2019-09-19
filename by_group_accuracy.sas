%macro by_group_accuracy (_infile_scored_data_,list_var_file,_outfile_data_stats_,_outfile_data_points_,_predicted_var_,by_vars)
 / store source des=""; 

%put Executing: by_group_accuracy;
%local i;
%local filename;
%local target_variable; /* the name of the target variable  */
%local _length_; /* the legnth in bytes of the target variable */
%local id_variables; /* the variable/s identifying a records (e.g. person id ,transaction id) which we want to display when scoring a data set */ 
%local variables_pca_statement; /* variables to use in the PCA algorihtm */
%local variables_to_drop; /* varaibles to drop for the original data set (XX in LEGEND) */

%let by_vars_comma=%sysfunc(TRANWRD("&by_vars",%str( ),%str(,)));
/* define target variable */
proc sql NOPRINT;
	select length(strip(VARNAME)) into: _length_ from  &list_var_file where LEGEND eq 'TG';
	select strip(VARNAME) length=&_length_ into: target_variable from &list_var_file where LEGEND eq 'TG';
quit;

/* define id variables  */
proc sql NOPRINT;select strip(VARNAME) into: id_variables  separated by ' '  from &list_var_file where LEGEND eq 'ID';quit;

%put AA &by_vars BB &by_vars_comma;

/* */
proc sql;
	create table _bygroup1_ as 
		select &by_vars_comma,sum(&target_variable) as sum_target,sum(&_predicted_var_) as sum_predicted
	from &_infile_scored_data_
	group by &by_vars;
quit;

%accuracy_interval(_bygroup1_,&_outfile_data_stats_,sum_target,probvar=sum_predicted);

/* */
proc sql;
	create table &_outfile_data_points_ as 
	select *,abs(sum_predicted-sum_target) as abs_error, 
		case when sum_target ne 0 then (sum_predicted-sum_target)/sum_target*100 else . end as relative_error
	from _bygroup1_;
quit;
/**/

/* remove temporary files */
proc sql; drop table _bygroup1_;quit;

%mend by_group_accuracy;
