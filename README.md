# RESEGO = ready set go

Quickly run models in a cross validation set up using SAS 9.4. You need only to specify a table decalring the variable names and their role in the model.

Example 
%model_ranfor_base(mylib.mydata,mylib.myvar,/pathtosavemodelbinaryfile,
modelname,nominal,50,5,1729,trainvalidation=stratified,train_with_equistrata=Y,equistrata_option=tomin);

Use the dataset mylib.mydata to build a random forest model (maxdepth=50, variables to use for executing a split is 5). 
Gather the role of each variable in the dataset from the dataset mylib.myvar. 
The target is a "nominal" variable".
Execute cross validation splitting in a "strtatified" way given the target.
Create Train and Validation so that target varaible is uniformed distributed.
Use population of less populated target value as level for all teh other target values.

