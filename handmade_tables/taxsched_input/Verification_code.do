**********************************************
*** Tax schedule data: input verification file 
**********************************************

// Author: Francesca
// Last update: 1 April 2025
// Aim: take the content of the Data sheet in Excel and 
		// 1) check the validity and the consistency of the data
		// 2) Fill the missing information when possible
		// 3) Save data in .dta format

// Set working directory and paths

	// Automatized user paths
	global username "`c(username)'"
	
	dis "$username" // Displays your user name on your computer
	
	* Francesca
	if "$username" == "fsubioli" { 
		global dir  "/Users/$username/Dropbox/gcwealth/handmade_tables/taxsched_input" 
	}
	if "$username" == "Francesca Subioli" | "$username" == "Francesca" | "$username" == "franc" { 
		global dir  "C:/Users/`c(username)'/Dropbox/gcwealth/handmade_tables/taxsched_input" 
	}
	
	* Luca
	if "$username" == "lgiangregorio" {
		global dir  "/Users/$username/Dropbox/gcwealth/handmade_tables/taxsched_input" 
	} 	
	
	cd "$dir"	

// Verify the input and save
	
	// Insert as arguments the name of the folder of the source followed by the name of the country
	// Example: eigt_verify EY_EIG_Guide Monaco

*	eigt_verify EY_EIG_Guide BE
*	eigt_verify Government_legislation IT
*	eigt_verify Academic_research UK
*	eigt_verify Academic_research US
	eigt_verify EY_EIG_Guide AU
	eigt_verify Yale_Inheritance_Data IE
	
	// Use this syntax in case of tax credit (type help eigt_verify for info about the options)
	*eigt_verify EY_EIG_Guide United_States, value(exemption) dummy(taxcredit)
	
