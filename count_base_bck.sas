%macro count_base(_infile_data_,list_var_file,store_option_file,_distribution_)
 / store source des=""; 

%put Executing: count_base;

%local target_variable; /* proc glimmix statement to define the target variable of the model */
%local id_variables; /* list of  ID variables in the model (person ID, transaction ID, claim ID,.....)*/
%local _variables_; /* list of all predictors to be used */
%local class_variables; /* list of categorical variables */
%local class_statement; /* proc glimmix statement to include categorical variables as predictors in the model */
%local _length_;


/* initialize variables */
%let _variables_=;
%let class_variables=;
%let id_variables=;
%let target_variable=;

/* define target variable */
proc sql NOPRINT;
	select length(strip(VARNAME)) into: _length_ from  &list_var_file where LEGEND eq 'TG';
	select strip(VARNAME) length=&_length_ into: target_variable from &list_var_file where LEGEND eq 'TG';
quit;

/* define id variables */
proc sql NOPRINT;select strip(VARNAME) into: id_variables separated by ' '  from &list_var_file where LEGEND eq 'ID';quit;

/* define list of all predictors to be used */
proc sql NOPRINT;select strip(VARNAME) into: _variables_ separated by ' '  from &list_var_file where LEGEND in ('VN','VI','VC');quit;

/* check if class variables exists: if so make appropriate statement for proc glimmix -- START */
	/* define class statement */
proc sql NOPRINT;select strip(VARNAME) into: class_variables separated by ' '  from &list_var_file where LEGEND in ('VC','VN');quit;
%if %sysevalf(%superq(class_variables)=,boolean) ne 0 %then %do;
	%let class_statement=;
%end;
%else %do;
	%let  class_statement=%str(input )&class_variables.%str(/ level=nominal);
%end;
/* check if class variables exists: if so make appropriate statement for proc glimmix -- END */

/* */
ods listing close;
ods select none;
proc glimmix data=&_infile_data_  /*method=laplace*/;
	&class_statement;
	model &target_variable = &_variables_ / dist=&_distribution_ link=log S;
	store &store_option_file.;
	ID &id_variables &target_variable;
	ods output ParameterEstimates=coefficients;
	ods output FitStatistics=fit;
run;
ods listing;
ods select all;
/*%process_coeff_output(_temp_coefficients_,_coefficients_,&list_var_file);*/

/* remove temporary files */
/*proc sql; drop table _temp_coefficients_;quit;*/

%mend count_base;
