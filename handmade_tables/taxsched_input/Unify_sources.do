
// Working directory and paths

	*** automatized user paths
	global username "`c(username)'"
			
	* Francesca
	if "$username" == "fsubioli" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
		global dir2  "/Users/$username/Dropbox/gcwealth/handmade_tables/taxsched_input"
	}	
	if "$username" == "Francesca Subioli" | "$username" == "Francesca" | "$username" == "franc" { 
		global dir  "C:/Users/`c(username)'/Dropbox/gcwealth" 
		global dir2  "C:/Users/`c(username)'/Dropbox/gcwealth/handmade_tables/taxsched_input" 
	}	
	* Luca 
	if "$username" == "lgiangregorio" | "$username" == "lucagiangregorio" { 
		global dir  "/Users/`c(username)'/Dropbox/gcwealth" 
		global dir2  "/Users/$username/Dropbox/gcwealth/handmade_tables/taxsched_input"
	}
	
	global dofile "$dir/code/dashboards/eigt"
	global intfile "$dir/raw_data/eigt/intermediary_files"
	global hmade "$dir/handmade_tables"
	global supvars "$dir/output/databases/supplementary_variables"
	                   
	cd "$dir2"
	
	global supvarver 16Jul2024
	global oecdver 14april2025

// Select the country, loop over sources, and generate a unique excel file with verified data, with a warning if there are overlapping dates for the same tax

// Example with Germany

	local country DE

//---------------------------	
// 1) Verify each source file	
//---------------------------

	foreach source in Academic_research ///
					  Cross_national_corporate_research ///
					  Cross_national_academic_research ///
					  Government_legislation ///
					  Government_research  ///
					  TIDData  {
		
	 // Construct the file path
		if "`source'" == "TIDData" global name TIDD_`country'				
		if "`source'" == "Government_legislation" global name Lex_`country'
		if "`source'" == "Academic_research" global name Academic_`country'
		if "`source'" == "Government_research" global name GR_`country'
		if "`source'" == "Cross_national_corporate_research" global name CorpRes_`country'		
		if "`source'" == "Cross_national_academic_research" global name CNRes_`country'
		
		local filepath "Sources/`source'/`country'"
		
		if fileexists("`filepath'/$name.xlsx") {
		disp "`source'"
		if "`country'" != "United_States" eigt_verify `source' `country'
		else eigt_verify `source' `country', value(exemption) dummy(taxcredit)		
		}
	}

//---------------------------------------------
// 2) Append all source files in a unique Excel
//--------------------------------------------- 

	local country DE
	foreach source in Academic_research ///
					  Cross_national_corporate_research ///
					  Cross_national_academic_research ///
					  Government_legislation ///
					  Government_research  ///
					  TIDData  {

		if "`source'" == "TIDData" global name TIDD_`country'				
		if "`source'" == "Government_legislation" global name Lex_`country'
		if "`source'" == "Academic_research" global name Academic_`country'
		if "`source'" == "Government_research" global name GR_`country'
		if "`source'" == "Cross_national_corporate_research" global name CorpRes_`country'		
		if "`source'" == "Cross_national_academic_research" global name CNRes_`country'
		
		local filepath "Sources/`source'/`country'"
		if fileexists("`filepath'/$name.xlsx") {
			disp as result "`source'"
			clear
			qui import excel "`filepath'/$name.xlsx", sheet(Data) allstring firstrow 
			// Remove lead and last blank spaces 
			qui ds 
			foreach var in `r(varlist)' {
				qui replace `var' = strtrim(`var')
			}
			tempfile $name
			qui save "`$name'", replace
		}
	}
	clear
	foreach source in Academic_research ///
					  Cross_national_corporate_research ///
					  Cross_national_academic_research ///
					  Government_legislation ///
					  Government_research  ///
					  TIDData  {
					  	
		if "`source'" == "TIDData" global name TIDD_`country'				
		if "`source'" == "Government_legislation" global name Lex_`country'
		if "`source'" == "Academic_research" global name Academic_`country'
		if "`source'" == "Government_research" global name GR_`country'
		if "`source'" == "Cross_national_corporate_research" global name CorpRes_`country'		
		if "`source'" == "Cross_national_academic_research" global name CNRes_`country'					  	
		local filepath "Sources/`source'/`country'"
		if fileexists("`filepath'/$name.xlsx") qui append using "`$name'"
	}

//-------------------------------------
// 3) Verify the overlapping and choose
//-------------------------------------
	
	gsort -GEO year_from year_to subnationallevel tax applies_to
	duplicates tag GEO_l year_from year_to tax applies_to subnationallevel, gen(dupl)
	tab dupl
	drop dupl
	preserve
		keep GEO_long year_from year_to applies_to tax subnationallevel Source
		duplicates drop
		destring year_from, replace
		destring year_to, replace
		gen expans = year_to - year_from + 1
		expand expans, gen(dupl)
		gen year = year_from
		egen group = group(GEO applies_to tax Source year_from year_to subnationallevel)
		sort group year dupl
		replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
		drop dupl year_* expans group
		order GEO* year appl tax Source
		sort GEO* year appl tax Source
	
		duplicates tag GEO_l year tax applies_to, gen(dupl)
		tab year Source if dupl
		tab year tax if dupl
		tab year applies_to if dupl		
		bro if dupl
	restore
	// Overlapping for 1906-1935 of inheritance tax for children, fully exempted, same information. We drop Shultz1926 covering less years
	drop if Source == "Shultz1926" & year_from == "1906" & year_to == "1912" & applies_to =="children" & tax == "inheritance"
	drop if Source == "Shultz1926" & year_from == "1867" & year_to == "1912" & applies_to =="everybody" & tax == "estate"	
	
	// Overlapping for 2006-2008 of inheritance tax for children, fully exempted, same information. We drop EYa having only status and top rate
	drop if Source == "EY2006a" & year_from == "2006" & year_to == "2006" & applies_to =="children" & tax == "inheritance"
	drop if Source == "EY2007a" & year_from == "2007" & year_to == "2007" & applies_to =="children" & tax == "inheritance"
	drop if Source == "EY2008a" & year_from == "2008" & year_to == "2008" & applies_to =="children" & tax == "inheritance"	
	replace note = "Parents and grandchildren are taxed up to 40% according to EYa" if Source == "YaleInheritanceData" & year_from == "2002" & year_to == "2007" & applies_to =="children" & tax == "inheritance"
	replace note = "Parents and grandchildren are taxed up to 40% according to EYa" if Source == "YaleInheritanceData" & year_from == "2008" & year_to == "2008" & applies_to =="children" & tax == "inheritance"
	
	// Same overlapping for estate tax (status no) for everybody
	drop if Source == "EY2006a" & year_from == "2006" & year_to == "2006" & applies_to =="everybody" & tax == "estate"
	drop if Source == "EY2007a" & year_from == "2007" & year_to == "2007" & applies_to =="everybody" & tax == "estate"
	drop if Source == "EY2008a" & year_from == "2008" & year_to == "2008" & applies_to =="everybody" & tax == "estate"		
	
	// Further possible overlapping: everybody and children
	gen applies = "children" if applies_to == "children" | applies_to == "everybody"
	gsort -GEO year_from year_to subnationallevel tax applies
	duplicates tag GEO_l year_from year_to tax applies, gen(dupl)
	tab dupl if applies == "children"
	drop dupl
	preserve
		keep GEO_long year_from year_to applies tax Source
		keep if applies == "children"
		duplicates drop
		destring year_from, replace
		destring year_to, replace
		gen expans = year_to - year_from + 1
		expand expans, gen(dupl)
		gen year = year_from
		egen group = group(GEO tax Source year_from year_to)
		sort group year dupl
		replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
		drop dupl year_* expans group
		order GEO* year tax Source
		sort GEO* year tax Source
	
		duplicates tag GEO_l year tax, gen(dupl)
		tab year Source if dupl
		tab year tax if dupl
		bro if dupl
	restore
	drop applies 
	
//-----------------------------------------
// 4) Save a full excel with no overlapping
//-----------------------------------------

	export excel using "Final_Data/DE/Final_DE.xlsx", firstrow(variables) sheet(Data) replace

	eigt_verify Final_Data DE
	
//--------------
// 5) Manipulate
//--------------
	
	// Replicate for years 
	gen expans = year_to - year_from + 1
	expand expans, gen(dupl)
	gen year = year_from
	egen group = group(GEO applies_to tax year_from year_to bracket)
	sort group year bracket dupl
	replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1] & dupl
	drop dupl year_* expans group
	order GEO* year appl tax 
	sort GEO* year appl tax br
				
	// Replicate for kinship
	qui split(applies_to), parse(,)
	gen expans = `r(k_new)'
	local k = `r(k_new)'
	local k = `r(k_new)'
	forvalues i = `k'(-1)1 {
		replace expans = expans - 1 if applies_to`i' == "" 
	}			
	expand expans, gen(dupl)
	sort GEO year applies_to tax bracket dupl

	egen group = group(GEO applies_to tax year)
	replace applies_to = applies_to1 if dupl == 0		
	forvalues i = 2/`k' {
		local j = `i' -1
		replace applies_to = applies_to`i' if dupl == 1 & dupl[_n-`j'] == 0 & group == group[_n-`j'] & applies_to`i' != ""
	}	
	drop applies_to1-applies_to`k' expans dupl group
	
	drop subnationallevel
	save "Final_Data/DE/final_DE", replace
