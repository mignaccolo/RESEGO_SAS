%macro count_base(_infile_data_,list_var_file,store_option_file,_distribution_)
 / store source des=""; 

%put Executing: count_base;
/* declaring variables */
%local target_variable; /* the target variable of the model */
%local id_variables; /* list of  ID variables in the model (person ID, transaction ID, claim ID,.....)*/
%local _variables_; /* list of all predictors to be used */
%local class_variables; /* list of categorical variables */
%local class_statement; /* proc glimmix statement to include categorical variables as predictors in the model */
%local _length_; /* the legnth in bytes of the target variable */

/* initialize variables */
%let class_variables=;

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
	%let  class_statement=%str(input )&class_variables;
%end;
/* check if class variables exists: if so make appropriate statement for proc glimmix -- END */

/* run model -- START */
	/* POISSION or NEGBINOMIAL */
%if (%sysfunc(compare("POISSON","&_distribution_")) eq 0) or 
	(%sysfunc(compare("NEGBINOMIAL","&_distribution_")) eq 0)  %then %do;
	ods listing close;	
	ods select none;
	proc glimmix data=&_infile_data_  /*method=laplace*/;
		&class_statement;
		model &target_variable = &_variables_ / dist=&_distribution_ link=log S;
		store &store_option_file.;
		ID &id_variables &target_variable;
		ods output ParameterEstimates=coefficients (keep=Effect Estimate Probt);
	run;
	ods listing;
	ods select all;
%end;
	/* ZERO INFLATED POISSON or ZERO INFLATED NEGBINOMIAL */
%if (%sysfunc(compare("ZIP","&_distribution_")) eq 0) or 
	(%sysfunc(compare("ZINB","&_distribution_")) eq 0)  %then %do;
	ods listing close;	
	ods select none;
	proc countreg data=&_infile_data_  method=QN;
		&class_statement;
		model &target_variable = &_variables_ / dist=&_distribution_;
		zeromodel &target_variable ~ &_variables_ / link=logistic;
		store &store_option_file.;
		ods output ParameterEstimates=coefficients (keep=Parameter ParameterType Estimate Probt rename=(Parameter=Effect ParameterType=Type));
	run;
	ods listing;
	ods select all;
%end;
/* run model -- END */
%exit: %mend count_base;
