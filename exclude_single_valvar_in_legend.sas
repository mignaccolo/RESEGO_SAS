%macro exclude_single_valvar_in_legend (_infile_data_,_infile_var_list_,_outfile_var_list_) / store source des="";

%put Executing: exclude_single_valvar_in_legend;
%local _variables_;

/* define list of all predictors to be used */
proc sql NOPRINT;select strip(VARNAME) into: _variables_ separated by ' '  from &_infile_var_list_ where LEGEND in ('VN','VI','VC');quit;

/* calculate number of levels of each predictor as per infile var legend */
ods listing close;
ods select none;
proc freq data=&_infile_data_ nlevels;
	tables &_variables_;
	ods output nlevels=_lev_;
run;
ods listing;
ods select all;

/* create new var legend file */
proc sql;
	create table &_outfile_var_list_ as 
	select VARNAME,TYPE,
		case when VARNAME in (select strip(TableVar) from _lev_ where NLevels=1) and LEGEND in ('VI','VN','VC') then 'XX' 
			else LEGEND end as LEGEND
	from &_infile_var_list_;
quit;

/* remove temp files*/
proc sql; drop table _lev_;quit;

%mend exclude_single_valvar_in_legend;
