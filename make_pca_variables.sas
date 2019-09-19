%macro make_pca_variables (_infile_data_,list_var_file,_outfile_data_,path_for_binary_pca_impl,namestore)
 / store source des=""; 

%put Executing: make_pca_variables;
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

/* variables for PCA statement */
proc sql NOPRINT;select strip(VARNAME) into: variables_pca_statement separated by ' '  from &list_var_file where LEGEND eq 'VI';quit;

/* variables to drop */
proc sql NOPRINT;select strip(VARNAME) into: variables_to_drop separated by ' '  from &list_var_file where LEGEND eq 'XX';quit;

/* */
data _temp1_ (drop=&variables_to_drop);
	set &_infile_data_;
run;

%put AAA &id_variables;
%put BBB &variables_to_drop;

/* */
LIBNAME templib "&path_for_binary_pca_impl";
%let _filename_=templib.&namestore;
/* */
proc score data=_temp1_ score=&_filename_ out=&_outfile_data_ (drop= &variables_pca_statement);
   var &variables_pca_statement;
run;

/* remove temporary files */
proc sql; drop table _temp1_;quit;

%mend make_pca_variables;
