
// Working directory and paths

macro drop _all 

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
	
	// Integrate Yale and TID together in a unique YaleTid_country.xlsx file	
	
	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	cd "$dir2"	
	
	levelsof GEO, local(levels)
    foreach country of local levels {
		foreach source in TIDData YaleInheritanceData {
			
			if "`source'" == "TIDData" global name TIDD_`country'				
			if "`source'" == "YaleInheritanceData" global name Yale_`country'
			
			local filepath "Sources/`source'/`country'"
			if fileexists("`filepath'/$name.xlsx") {

			    qui import excel "`filepath'/$name.xlsx", sheet(Data) allstring firstrow clear
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
		foreach source in TIDData YaleInheritanceData {
	   	
			if "`source'" == "TIDData" global name TIDD_`country'				
			if "`source'" == "YaleInheritanceData" global name Yale_`country'
		
		local filepath "Sources/`source'/`country'"
		if fileexists("`filepath'/$name.xlsx") {
			qui append using "`$name'"
		}
	}
		if fileexists("`TIDD_`country''") | fileexists("`Yale_`country''") {
			cap mkdir "Sources/Cross_national_academic_research/`country'"
			qui export excel using "Sources/Cross_national_academic_research/`country'/YaleTid_`country'.xlsx", firstrow(variables) sheet(Data) replace 
		}
		if fileexists("`TIDD_`country''") & fileexists("`Yale_`country''") {
			display "`country'"
			global listtocheck $listtocheck `country'
		}
	}
	
	clear
	display "$listtocheck"
	
	set obs 100
	gen country = ""
	local c = 1
	foreach i of global listtocheck {
		replace country = "`i'" in `c'
		local c = `c'+1
	}
	drop if country == ""
	
	save "countries_tocheck2.dta", replace 
	
	// In countries_tocheck we have conutries with both EYa and EYb; check which ones have overlapping information
	
	foreach country of global listtocheck {
		display "`country'"
		local filepath "Sources/Cross_national_academic_research/`country'"
		if fileexists("`filepath'/YaleTid_`country'.xlsx") {
			qui import excel "`filepath'/YaleTid_`country'.xlsx", sheet(Data) allstring firstrow clear

		qui {			
			gsort -GEO year_from year_to subnationallevel tax applies_to Source
			duplicates tag GEO_l year_from year_to tax applies_to subnationallevel, gen(dupl)
			tab dupl
			if `r(r)' == 2 continue, break
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
			
				duplicates tag GEO_l year tax applies_to subnationallevel, gen(dupl)
				tab dupl
				if `r(r)' == 2 continue, break
				tab year Source if dupl
				tab year tax if dupl
				tab year applies_to if dupl		
			restore		
		}
		}	
	}	
	
	// No adjustment needed for the 2 sources!
	
	// Rename all excel files 
	
	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	cd "$dir2"	
	
	levelsof GEO, local(levels)
    foreach country of local levels {
			
		local filepath "Sources/Cross_national_academic_research/`country'"
		
		if fileexists("`filepath'/YaleTid_`country'.xlsx") {
			qui import excel "`filepath'/YaleTid_`country'.xlsx", sheet(Data) allstring firstrow clear
			qui export excel using "`filepath'/CNRes_`country'.xlsx", firstrow(variables) sheet(Data) replace 
			qui erase "`filepath'/YaleTid_`country'.xlsx"
		}
	}	
