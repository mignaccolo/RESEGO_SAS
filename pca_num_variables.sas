%macro pca_num_variables (_infile_data_,list_var_file,_outfile_data_,new_list_var_file,path_for_binary_pca_impl,namestore)
 / store source des=""; 

%put Executing: pca_num_variables;
%local i;
%local filename;
%local target_variable; /* the name of the target variable  */
%local _length_; /* the legnth in bytes of the target variable */
%local id_variables; /* the variable/s identifying a records (e.g. person id ,transaction id) which we want to display when scoring a data set */ 
%local variables_pca_statement; /* variables to use in the PCA algorihtm */
%local variables_to_drop; /* varaibles to drop for the original data set (XX in LEGEND) */

/* define target variable */
proc sql NOPRINT;
	select length(strip(VARNAME)) into: _length_ from  &list_var_file where LEGEND eq 'TG';
	select strip(VARNAME) length=&_length_ into: target_variable from &list_var_file where LEGEND eq 'TG';
quit;

/* define id variables  */
proc sql NOPRINT;select strip(VARNAME) into: id_variables  separated by ' '  from &list_var_file where LEGEND eq 'ID';quit;

/*proc sql NOPRINT;select VARNAME into: target_statement from &list_var_file where LEGEND eq 'T';quit;/*/
/*proc sql NOPRINT;select VARNAME into: variable_statement separated by ' '  from &list_var_file where LEGEND eq 'V';quit;*/
/*proc sql NOPRINT;select VARNAME into: id_statement separated by ' '  from &list_var_file where LEGEND eq 'I';quit;*/

/* variables for PCA statement */
proc sql NOPRINT;select strip(VARNAME) into: variables_pca_statement separated by ' '  from &list_var_file where LEGEND eq 'VI';quit;

/* variables to drop */
proc sql NOPRINT;select strip(VARNAME) into: variables_to_drop separated by ' '  from &list_var_file where LEGEND eq 'XX';quit;

/* */
data _temp1 (drop=&variables_to_drop);
	set &_infile_data_;
run;


ods listing close;
ods select none;
/* */
proc factor data=_temp1
	simple 
	method=principal
	priors=one
	mineigen=1
	rotate=varimax;
	var &variables_pca_statement;
	ods output Eigenvalues=_eigen_;
run;
ods listing;
ods select all;

/* */
proc sql NOPRINT;
	select count(*) into: nfactors from _eigen_ where Cumulative<0.8;
quit;

/* */
LIBNAME templib "&path_for_binary_pca_impl";
%let _filename_=templib.&namestore;
proc factor data=_temp1
	simple noprint
	method=principal
	priors=one
	mineigen=1
	rotate=varimax
	score nfact=&nfactors outstat=&_filename_;
	var &variables_pca_statement;
run;

/* */

proc score data=_temp1 score=&_filename_ out=&_outfile_data_ (drop= &variables_pca_statement);
   var &variables_pca_statement;
run;

/* */
proc contents data=&_outfile_data_ out=_contents_ (keep=NAME TYPE) NODETAILS;run;

/* */
proc sql;
	create table &new_list_var_file as 
		select NAME as VARNAME,TYPE,
		case when NAME in (select VARNAME from &list_var_file where LEGEND eq 'TG') then 'TG'
			when NAME in (select VARNAME from &list_var_file where LEGEND eq 'ID') then 'ID'
			when NAME in (select VARNAME from &list_var_file where LEGEND eq 'VN') then 'VN'
			when NAME in (select VARNAME from &list_var_file where LEGEND eq 'VC') then 'VC'
			else 'VI' end as LEGEND
		from _contents_;
quit;

/* remove temporary files */
proc sql; drop table _contents_,_eigen_,_temp1;quit;

%mend pca_num_variables;
