//general settings 
clear all 
run "code/mainstream/auxiliar/all_paths.do"
run "code/mainstream/auxiliar/version_control.do" //centralized version control

//[REMEMBER TO CREATE INTERMEDIARY FILES FOLDER IN RAW_DATA FIRST] - 
	
//run all code from EIG 

/* To fully replicate EIG structure we need to follow this order: 
	1. 00_Paths 
	2. 0_0_EIGT_Translation
	3. 1_0_EIGT_Warehouse 
	4. 2_0_EIGT_Website 
*/
 	
*1.	
display as result "running 00_Paths..."
run "code/dashboards/eigt/00_Paths.do"	

*2. 
display as result "running 0_0_EIGT_Translation..."
run "code/dashboards/eigt/0_0_EIGT_Translation.do"	

*3. 
display as result "running 1_0_EIGT_Warehouse.do..."
run "code/dashboards/eigt/1_0_EIGT_Warehouse.do"

*4. 
display as result "running 2_0_EIGT_Website..."
run "code/dashboards/eigt/2_0_EIGT_Website.do"	


di as result "done building EIG tax!"

