***********************************
*** EIGT data: adjust for warehouse
***********************************

// Author: Francesca
// Last update: July 2025

// Data used: $intfile/eigt_v1_transformed.dta; $hdmade/dictionary.xlsx
// Output:  and $intfile/eigt_countries_v1_ready.dta
	qui use "$intfile/eigt_countries_v1_transformed.dta", clear
	
	// Drop observations with N status before the first year
	
// d2 sector 1st digit for tax  
	
	*p	property & net wealth
	qui gen d1_a = "t" if tax == "estate, inheritance & gift"
*	replace d1_a = "m" if tax == "estate & inheritance"
	*r	immovable property
	*w	net wealth
	qui replace d1_a  = "i" if tax == "inheritance"
	qui replace d1_a  = "e" if tax == "estate"
	qui replace d1_a  = "g" if tax == "gift"
	
// d2_sector 2nd digit for "applies_to"
	
	qui gen d1_b = applies_to
	qui replace d1_b  = "g" if applies_to == "general"
	qui replace d1_b  = "c" if applies_to == "children"
	qui replace d1_b = "e" if applies_to == "everybody"	
	qui replace d1_b = "u" if applies_to == "unknown"
	
	*replace d1_b  = "s" if applies_to == "spouse"
	*replace d1_b = "l" if applies_to == "siblings"
	*replace d1_b = "r" if applies_to == "other relatives"
	*replace d1_b = "n" if applies_to == "non relatives"

// Keep only information on children (or everybody or unknown)
	qui drop if d1_b == applies_to
	
	*nf	net financial wealth
	*nw	net total wealth
	*re	real estate
	
	qui gen d2 = d1_a + d1_b
	qui drop d1_* 
	
// Save metadata
	preserve 
		qui keep if br == 0
		qui keep GEO year d2 Source* taxnote
		qui duplicates drop
		tempfile metadata 
		qui save "`metadata'", replace
		qui count 
		di as red "1) saved metadata `r(N)' obs."
	restore	
	qui drop Source* taxnote applies_to tax
	
// Remove labels 
	label drop _all
	qui sum bracket
	local max `r(max)'
	di as red "2) reshaping wide..." _continue
	qui reshape wide adjlbo adjubo adjmrt curren status typtax firsty exempt toprat toplbo homexe revenu prorev revgdp, i(GEO year d2) j(bracket)
	qui count 
	di as red "done (`r(N)' obs)"

	foreach var in adjlbo adjubo adjmrt curren status typtax firsty exempt toprat toplbo homexe revenu prorev revgdp {
		forvalues i = 0/`max' {
			local vars`var'`i' `var'`i'
			*disp "`vars`var'`i''"
			qui rename `vars`var'`i'' value`vars`var'`i''
		}
	}
	
	qui compress
	qui ds value*
	foreach var in `r(varlist)' {
		qui count if !missing(`var') 
		if (`r(N)' == 0) {
			drop `var'
			di as red "dropped `var'"
		}	
	}
	
// Attach metadata 
	
	merge 1:1 d2 GEO year using "`metadata'", nogen
	qui count 
	di as red "3) after metadata merge: `r(N)' obs"
	qui reshape long value, i(GEO year d2) j(concept) string
	qui count 
	di as red "4) after first long reshape (`r(N)' obs)"
	qui format value %30.2f
	qui drop if value == . 
	qui sort GEO year d2 concept
	
	qui label define labels -999 "Missing" -998 "_na" -997 "_and_over"
	qui label values value labels, nofix

// d3_vartype
	
	qui gen d3 = "cat" if substr(concept, 1, 6) == "curren" | substr(concept, 1, 6) == "status" ///
					| substr(concept, 1, 6) == "typtax" | substr(concept, 1, 6) == "homexe" 
	qui replace d3 = "rat" if substr(concept, 1, 6) == "adjmrt" | substr(concept, 1, 6) == "toprat"				
	qui replace d3 = "thr" if substr(concept, 1, 6) == "adjlbo" | substr(concept, 1, 6) == "adjubo" ///
					| substr(concept, 1, 6) == "toplbo" | substr(concept, 1, 6) == "exempt" 					
	qui replace d3 = "per" if substr(concept, 1, 6) == "firsty" 			
	qui replace d3 = "rto" if substr(concept, 1, 6) == "prorev" | substr(concept, 1, 6) == "revgdp"
	qui replace d3 = "tot" if substr(concept, 1, 6) == "revenu" 

	
	qui replace concept = substr(concept, 1, 6) + "0" + substr(concept, 7, .) if strlen(substr(concept, 7, .)) == 1
	qui replace concept = substr(concept, 1, 6) + "-" + substr(concept, 7, 2)

	qui gen varcode = "x-" + d2 + "-" + d3 + "-" + concept

	qui gen percentile = "p0p100"
	qui sort GEO GEO_long year varcode 
	qui keep GEO GEO_long year perc varcode value Source* taxnote
	qui order GEO GEO_long year perc varcode value
	qui drop if value == -999
	qui sort GEO year varcode 	
	
// Sources and notes

	qui replace varcode = substr(varcode, 3, .)
	
// Import legend entries from dictionary 
	preserve
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("Sources") firstrow case(lower) allstring clear
		qui keep if section == "Estate, Inheritance, and Gift Taxes" 
		qui keep legend source citekey
		qui duplicates drop
		qui drop if leg == ""
		tempfile sources 
		save "`sources'", replace
		qui count 
		di as red "5) saved sources from dictionary (`r(N)' obs)"
	restore

	forvalues n=1/6{
		qui rename Source_`n' source 
		qui merge m:1 source using "`sources'", keep(master matched) 
		di as red "6) merged with sources"
		qui count if _m==1 & source != "" & source != "Own estimates using OECD_Rev" & source != "Inferred"
		if (`r(N)' != 0) {
			display in red "WARNING: `r(N)' cases of sources not found in dictionary in Source_`n'"
			tab source if _m==1 & source != "" & source != "Own estimates using OECD_Rev" & source != "Inferred"
		}
		qui count if _m==3 & source != "Own estimates using OECD_Rev" & source != "Inferred" & legend == ""
		if (`r(N)' != 0) {
			display in red "WARNING: `r(N)' cases of missing legend in dictionary in Source_`n'"
			tab source if _m==3 & source != "Own estimates using OECD_Rev" & source != "Inferred"  & legend == ""
		}
		qui count if _m==3 & source != "Own estimates using OECD_Rev" & source != "Inferred" & citekey == ""
		if (`r(N)' != 0) {
			display in red "WARNING: `r(N)' cases of missing citekey in dictionary in Source_`n'"
			tab source if _m==3 & source != "Own estimates using OECD_Rev" & source != "Inferred"  & citekey == ""
		}		
		qui drop _m
		qui replace legend = source if source == "Own estimates using OECD_Rev" | source == "Inferred"
		qui rename legend source_legend`n'
		qui rename citekey citekey`n'		
		qui rename source Source_`n'
	}

// Concatenate and clean citekey
	qui egen citekey_concat = concat(citekey*), punct(/)
	qui egen source_legend_concat = concat(source_legend*), punct(/)
	forvalues sn=1/6{
		qui rename Source_`sn' sourcekey`sn'
	}
	qui egen source_concat = concat(sourcekey*), punct(/)
	
	foreach var in citekey_concat source_legend_concat source_concat {
		qui replace `var' = subinstr(`var', "////", "", .)
		qui replace `var' = subinstr(`var', "///", "", .)
		qui replace `var' = subinstr(`var', "//", "", .)
		qui replace `var' = subinstr(`var', "/", "", 1) if substr(`var', 1, 1) == "/"
		qui gen ck1 = strreverse(`var')
		qui replace ck1 = subinstr(ck1, "/", "", 1) if substr(ck1, 1, 1) == "/"
		qui replace `var' = strreverse(ck1)
		qui drop ck1		
	}
	qui rename citekey_concat c_citekey 
	qui drop citekey*		

	qui order GEO GEO_long year perc varcode value source_concat 
	
	*** drop excess sources 
	qui keep GEO GEO_long year percentile varcode value source_concat source_legend_concat c_citekey taxnote
	qui rename source_concat source
	qui rename source_legend_concat source_legend
	qui order GEO GEO_long year percentile varcode value source source_legend c_citekey taxnote

	
// Generate vartype
	qui gen code = substr(varcode, 4,3)
	
	preserve 
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("d3_vartype") firstrow case(lower) allstring clear
		qui keep code label
		qui rename label vartype
		qui drop if code == ""
		tempfile d3
		qui save "`d3'", replace
		qui count 
		di as red "7) saved d3 (`r(N)' obs)"
	restore

	qui merge m:1 code using "`d3'", keep(master matched)
	qui count if _m==1 
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' cases of d3_vartype not found in dictionary"
		tab code if _m==1 
	}	
	qui count 
	di as red "8) merged d3 (`r(N)' obs)"
	qui drop code _m
			
// Generate varname 

	// Concept
	qui gen code = substr(varcode, 8, 6)
	preserve 
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("d4_concept") firstrow case(lower) allstring clear
		qui keep code label
		qui rename label varname
		qui drop if code == ""
		tempfile d4
		qui save "`d4'", replace
		qui count 
		di as red "9) saved d4 (`r(N)' obs)"
	restore
	
	qui merge m:1 code using "`d4'", keep(master matched)
	qui count 
	di as red "10) merged d4 (`r(N)' obs)"
	qui count if _m==1 & code != "curren"
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' cases of d4_concept not found in dictionary"
		tab code if _m==1 & code != "curren"
	}	
	qui drop code _m
	
	// Sector
	qui gen code = substr(varcode, 1, 2)
	preserve 
		qui import excel "$hmade/dictionary.xlsx", ///
			sheet("d2_sector") firstrow case(lower) allstring clear
		qui keep code label
		qui duplicates drop 
		qui rename label sector
		qui drop if code == ""
		tempfile d2
		qui save "`d2'", replace	
		qui count 
		di as red "11) saved d2 (`r(N)' obs)"
	restore
	
	qui merge m:1 code using "`d2'", keep(master matched)
	qui count 
	di as red "12) merged d2 (`r(N)' obs)"
	qui count if _m==1 
	if (`r(N)' != 0) {
		display in red "WARNING: `r(N)' cases of d4_concept not found in dictionary"
		tab code if _m==1 
	}	
	qui drop code _m

// Generate longname
	
	// bracket
	gen brac = substr(varcode, -2,2)
	destring brac, replace
	tostring brac, replace

	forvalues i = 1/30 {
		qui replace brac="`i'th Bracket" if brac=="`i'"
	}
		
	qui replace brac = subinstr(brac,"1th","1st",.)
	qui replace brac = subinstr(brac,"2th","2nd",.)
	qui replace brac = subinstr(brac,"3th","3rd",.)
	qui replace brac = subinstr(brac,"11st","11th",.)
	qui replace brac = subinstr(brac,"12nd","12th",.)
	qui replace brac = subinstr(brac,"13rd","13th",.)
	qui replace brac = "Not Bracket-Specific" if brac=="0"

	qui gen longname = vartype + "; " +  varname + " applicable to " + sector + "; " + "(" + brac + ")"
	
	* drop sector
	qui sort GEO year varcode
		
	qui drop if value == -999
	
// Save and export eig 
	qui replace varcode = "x-" + varcode

// Check the currency is once per country-year
	preserve 
		qui keep if substr(varcode, 10, 6) == "curren"
		qui keep GEO* year varcode value
		qui replace varcode = "x-tg-cat-curren-00"
		qui duplicates drop 
		qui gen source = "ISO4217"
		qui gen source_legend = "ISO 4217 Currency codes"		
		qui gen longname = "Categorical Variable; Currency applicable to EIG Tax; (Not Bracket-Specific)"
		qui gen percentile = "p0p100"
		tempfile curr 
		save "`curr'", replace
		qui count 
		di as red "13) saved curr (`r(N)' obs)"
	restore
	qui drop if substr(varcode, 10, 6) == "curren"
	qui append using "`curr'"
	sort GEO year varcode
	qui count 
	di as red "14) appended curr (`r(N)' obs)"
	
// Remove observations before first year 
	qui gen first = value if substr(varcode, 10, 6) == "firsty"
	qui gen tax = inlist(substr(varcode, 3, 1), "e", "i", "t")
	qui egen fi = min(first), by(GEO tax)
	qui drop if year < fi & fi != . & inlist(substr(varcode, 3, 1), "e", "i", "t")
	qui drop tax fi
	qui gen tax = inlist(substr(varcode, 3, 1), "g", "t")
	qui egen fi = min(first), by(GEO tax)
	qui drop if year < fi & fi != . & inlist(substr(varcode, 3, 1), "g", "t")
	qui drop first tax fi
		
// Follow the economic-criteria: set status = 0 if full exemption and lower and upper bounds 
	gen exemption = value if substr(varcode, 10, 6) == "exempt"
	gen status = value if substr(varcode, 10,6) == "status" 
	gen tax = substr(varcode, 3, 1)
	egen flag = min(status), by(GEO year tax)
	egen flag_ex = min(exemption), by(GEO tax year flag) 

	replace value = 0 if substr(varcode, 10,6)=="status" & flag == 1 & substr(varcode, 3, 2) != "tg" & substr(varcode, 3, 2) != "gg" & flag_ex == -997	
	replace value = 0 if substr(varcode, 10,6)=="adjlbo" & flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3,2) != "tg" & flag_ex == -997 
	replace value = -997 if substr(varcode, 10,6)=="adjubo" & flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3,2) != "tg" & flag_ex == -997 
	replace value = 0 if substr(varcode, 10,6)=="adjmrt" & flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3,2) != "tg" & flag_ex == -997
	replace value = 0 if substr(varcode, 10,6)=="toplbo" & flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3,2) != "tg" & flag_ex == -997	
	replace value = 0 if substr(varcode, 10,6)=="toprat" & flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3,2) != "tg" & flag_ex == -997 
	replace value = -998 if substr(varcode, 10,6)=="typtax" & flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3,2) != "tg" & flag_ex == -997
	replace taxnote = taxnote + "Children are fully exempted from tax even if tax is legally levied" if flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3,2) != "tg" & flag_ex == -997 & taxnote != ""
	replace taxnote = "Children are fully exempted from tax even if tax is legally levied" if flag == 1 & substr(varcode, 3,2) != "tg" & substr(varcode, 3,2) != "tg" & flag_ex == -997 & taxnote == ""
	
	keep GEO* year value percentile varcode source source_legend longname taxnote
	rename taxnote note
	
	qui save "$intfile/eigt_countries_v1_ready.dta", replace


	
	
	
	







