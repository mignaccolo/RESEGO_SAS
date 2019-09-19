%macro score_with_model_count_base(_infile_data_score_,_outfile_data_score_,list_var_file,
path_for_binary_mdl_impl,model_identifier,_distribution_) / store source des="";

/* PARAMETERS

*/

%put Executing: score_with_model_count_base;

%local _filename_; /* full (path + file name) system  name for the binary file where to store details of the model (useful to score new data set) */
%local target_variable; /* the name of the target variable  */
%local id_variables; /* the variable/s identifying a records (e.g. person id ,transaction id) which we want to display when scoring a data set */ 
%local dsempty; /* flag indicating the absence (1) or not (0) of the target variable in the data set to score */


/* check if the distribution is available */
%if (%sysfunc(compare("POISSON","&_distribution_")) ne 0) and 
	(%sysfunc(compare("NEGBINOMIAL","&_distribution_")) ne 0) and 
	(%sysfunc(compare("ZIP","&_distribution_")) ne 0) and 
	(%sysfunc(compare("ZINB","&_distribution_")) ne 0) %then %do;
	%put ERROR: Valid values for the distribution parameter are POISSON, NEGBINOMIAL, ZIP (ZERO INFLATED POISSON), ZINB (ZERO INFLATED NEGATIVE BINOMIAL);  %goto exit;%goto exit;
%end;

/* define target variable */
proc sql NOPRINT;
	select strip(VARNAME) into: target_variable from &list_var_file where LEGEND eq 'TG';
quit;

/* define id variables  */
proc sql NOPRINT;select strip(VARNAME) into: id_variables  separated by ' '  from &list_var_file where LEGEND eq 'ID';quit;

/* check if data set to score contains the target variable. if so add target variable to the list of varible to keep in the scored file -- START */
proc datasets nodetails nolist; 
   contents data=&_infile_data_score_ out=_contents_ (keep=NAME LENGTH where=(strip(NAME)="&target_variable"));
run;

%let dsempty=0;
data _null_;
	if eof then do;call symput('dsempty',1);end;
	stop;
	set  _contents_ end=eof;
run;
%let dsempty=%sysfunc(strip(&dsempty));

	/* update outscore and id statements if target variable is not in the data set */
%if %sysfunc(compare("1","&dsempty")) eq 0 %then %do;
	%let target_variable=;
%end;
/* check if data set to score contains the target variable. if so add target variable to the list of varible to keep in the scored file -- END */

LIBNAME templib "&path_for_binary_mdl_impl";
%let _filename_=templib.&model_identifier.;
/* score validation data set -- START */
	/* POISSION or NEGBINOMIAL */
%if (%sysfunc(compare("POISSON","&_distribution_")) eq 0) or 
	(%sysfunc(compare("NEGBINOMIAL","&_distribution_")) eq 0)  %then %do;
		/* score validation */
	proc plm source=&_filename_;
		score data=&_infile_data_score_ out=&_outfile_data_score_ (keep=&id_variables &target_variable predicted) / ilink;
	run;

%end;

	/* ZERO INFLATED POISSON or ZERO INFLATED NEGBINOMIAL */
%if (%sysfunc(compare("ZIP","&_distribution_")) eq 0) or 
	(%sysfunc(compare("ZINB","&_distribution_")) eq 0)  %then %do;
	/* score validation data */	
	proc countreg restore=templib.&model_identifier. data=&_infile_data_score_;
		score out=&_outfile_data_score_ (keep=&id_variables &target_variable predicted pzero P_0)  mean=predicted probcount(0) probzero=pzero;
	run;
%end;
/* score validation data set -- END */


/* remove temporary files */
proc sql; drop table _contents_; quit;

/* clear templib library */
LIBNAME templib clear;
%exit: %mend score_with_model_count_base;
