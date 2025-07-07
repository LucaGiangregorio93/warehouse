
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
	
	// Integrate EYa and EYb together in a unique EYab_country.xlsx file	
	
	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	cd "$dir2"	
	
	levelsof GEO, local(levels)
    foreach country of local levels {
		foreach source in EY_EIG_Guide EY_Personal_Tax_Guide {
			
			if "`source'" == "EY_EIG_Guide" global name EYb_`country'				
			if "`source'" == "EY_Personal_Tax_Guide" global name EYa_`country'
			
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
	foreach source in EY_EIG_Guide EY_Personal_Tax_Guide {
	   	
		if "`source'" == "EY_EIG_Guide" global name EYb_`country'				
		if "`source'" == "EY_Personal_Tax_Guide" global name EYa_`country'
		
		local filepath "Sources/`source'/`country'"
		if fileexists("`filepath'/$name.xlsx") {
			qui append using "`$name'"
		}
	}
		if fileexists("`EYb_`country''") | fileexists("`EYa_`country''") {
			cap mkdir "Sources/Cross_national_corporate_research/`country'"
			qui export excel using "Sources/Cross_national_corporate_research/`country'/EYab_`country'.xlsx", firstrow(variables) sheet(Data) replace 
		}
		if fileexists("`EYb_`country''") & fileexists("`EYa_`country''") {
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
	
	save "countries_tocheck.dta", replace 
	
	// In countries_tocheck we have conutries with both EYa and EYb; check which ones have overlapping information
	
	foreach country of global listtocheck {
		if "`country'" != "FR" & "`country'" != "US" {
		display "`country'"
		local filepath "Sources/Cross_national_corporate_research/`country'"
		if fileexists("`filepath'/EYab_`country'.xlsx") {
			qui import excel "`filepath'/EYab_`country'.xlsx", sheet(Data) allstring firstrow clear

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
	}
	
	// Case 1 Chile 2006-2011, everybody estate. We keep EYb, more correct in the original source
	import excel "Sources/Cross_national_corporate_research/CL/EYab_CL.xlsx", sheet(Data) allstring firstrow clear
	drop if year_from == "2006" & year_to == "2011" & Source == "EY2011a" & tax == "estate" & applies_to == "everybody"
	qui export excel using "Sources/Cross_national_corporate_research/CL/EYab_CL.xlsx", firstrow(variables) sheet(Data) replace 
	
	// Case 2 Netherlands 2011, everybody estate. We keep EYb
	import excel "Sources/Cross_national_corporate_research/NL/EYab_NL.xlsx", sheet(Data) allstring firstrow clear
	drop if year_from == "2011" & year_to == "2011" & Source == "EY2011a" & tax == "estate" & applies_to == "everybody"
	qui export excel using "Sources/Cross_national_corporate_research/NL/EYab_NL.xlsx", firstrow(variables) sheet(Data) replace 
	
	// Case 3 New Zealand 2006-2011, everybody estate. We keep EYb
	import excel "Sources/Cross_national_corporate_research/NZ/EYab_NZ.xlsx", sheet(Data) allstring firstrow clear	
	forvalues i=2006/2011 {
		drop if year_from == "`i'" & year_to == "`i'" & Source == "EY`i'a" & tax == "estate" & applies_to == "everybody"
		drop if year_from == "`i'" & year_to == "`i'" & Source == "EY`i'a" & tax == "inheritance" & applies_to == "everybody"	
	}
	drop if year_from == "2011" & year_to == "2011" & Source == "EY2011a" & tax == "gift" & applies_to == "everybody"		
	qui export excel using "Sources/Cross_national_corporate_research/NZ/EYab_NZ.xlsx", firstrow(variables) sheet(Data) replace 	

	// Case 4 Portugal
	import excel "Sources/Cross_national_corporate_research/PT/EYab_PT.xlsx", sheet(Data) allstring firstrow clear
	forvalues i=2006/2011 {
		drop if year_from == "`i'" & year_to == "`i'" & Source == "EY`i'a"
	}	
	forvalues i=2004/2024 {
		replace note = "Inheritance and gift taxes were abolished effective January 1, 2004. A stamp duty of 10% applies to individual beneficiaries, except for spouses, ascendants, and descendants who are exempt." if year_from == "`i'" & year_to == "`i'" & tax != "estate"
	}
	qui export excel using "Sources/Cross_national_corporate_research/PT/EYab_PT.xlsx", firstrow(variables) sheet(Data) replace 		
	
	// Case 5 Sweden, EYa reports abolition in 2006, while it is in 2004. We keep EYb
	import excel "Sources/Cross_national_corporate_research/SE/EYab_SE.xlsx", sheet(Data) allstring firstrow clear
	drop if substr(Source, -1, 1) == "a"
	qui export excel using "Sources/Cross_national_corporate_research/SE/EYab_SE.xlsx", firstrow(variables) sheet(Data) replace 		
	
	// Case 6 Singapore, 2007 different information for exemption. We keep the EYa information and leave the exemptions in the notes
	import excel "Sources/Cross_national_corporate_research/SG/EYab_SG.xlsx", sheet(Data) allstring firstrow clear
	drop if year_from == "2007" & year_to == "2007" & Source == "EY2023b" & tax == "estate" & applies_to == "everybody"
	replace note = "There are few exemptions allowed such as: residential properties up to an aggregate value of S$9 million; Taxable property up to the greater of S$600,000 in property value or the deceased's balance in the CPF account." if ((year_from == "2007" & year_to == "2007") | (year_from == "2006" & year_to == "2006")) & tax == "estate"	
	
	forvalues i=2008/2011 {
		drop if year_from == "`i'" & year_to == "`i'" & Source == "EY`i'a" & tax == "estate" & applies_to == "everybody"
	}
	
	replace note = "Estate duty has been eliminated from Singapore tax regime for deaths occurring on or after 15 feb 2008." if tax == "estate" & applies_to == "everybody" & (Source == "EY2023b" | Source == "EY2024b")

	qui export excel using "Sources/Cross_national_corporate_research/SG/EYab_SG.xlsx", firstrow(variables) sheet(Data) replace 			
	
	// Case 7 Turkey, 2011 estate tax replicates. We keep the EYb
	import excel "Sources/Cross_national_corporate_research/TR/EYab_TR.xlsx", sheet(Data) allstring firstrow clear
	drop if year_from == "2011" & year_to == "2011" & Source == "EY2011a" & tax == "estate" & applies_to == "everybody"	
	qui export excel using "Sources/Cross_national_corporate_research/TR/EYab_TR.xlsx", firstrow(variables) sheet(Data) replace 
	
	
	// Rename all excel files 
	
	// Take the list of countries from the dictionary
	qui import excel "$hmade\dictionary.xlsx", sheet("GEO") cellrange(A1:C1000) firstrow clear
	
	rename Country GEO_long
	duplicates drop
	
	cd "$dir2"	
	
	levelsof GEO, local(levels)
    foreach country of local levels {
		if "`country'" != "FR" & "`country'" != "US" & "`country'" != "DE" {
		local filepath "Sources/Cross_national_corporate_research/`country'"
		if fileexists("`filepath'/EYab_`country'.xlsx") {
			qui import excel "`filepath'/EYab_`country'.xlsx", sheet(Data) allstring firstrow clear
			qui export excel using "`filepath'/CorpRes_`country'.xlsx", firstrow(variables) sheet(Data) replace 
			qui erase "`filepath'/EYab_`country'.xlsx"
		}
	}
	}
		
	