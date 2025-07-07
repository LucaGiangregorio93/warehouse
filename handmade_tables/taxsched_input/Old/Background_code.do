**************************************************************
*** Tax schedule data: input verification file background code
**************************************************************

// Author: Francesca
// Last update: 27 Jue 2024
// Aim: take the content of the Data sheet in the Excel of each source and 
		// 1) check the validity and the consistency of the data
		// 2) Fill the missing information when possible
		// 3) Save data in .dta format

	display as result "Stata version required: 16"
	version 16
	display as result "Source: $source" 
	display as result "Country: $country" 
	
	clear all
// Import raw data on tax schedules
	if "$source" == "EY EIG Guide" global name EYb_$country
	if "$source" == "EY Personal Tax Guide" global name EYa_$country

	qui import excel "$source/$country/$name.xlsx", sheet(Data) allstring firstrow
	
// Set current year	
	global current_year = substr(c(current_date), -4, 4)


////////////////////////////
////// VALIDITY CHECKS /////
////////////////////////////

// Missing mandatory variables

	local general GEO GEO_long currency // Mandatory general information
	local taxn year_from year_to subnationallevel status // Mandatory numeric tax-related information
	local taxs tax applies_to // Mandatory string tax-related information
	local sourceinfo AggSource Legend Source Link // Mandatory source-related information
	
	foreach var of local general {
		qui count if `var' == ""
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' missing `var'"
			continue, break
		}
	} 
	foreach var of local taxn {
		qui destring `var', replace
		qui count if `var' == .
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' missing `var'"	
			continue, break
		}
	} 
	foreach var of local taxs {
		qui count if `var' == ""
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' missing `var'"	
			continue, break
		}
	} 	
	foreach var of local sourceinfo {
		if (`var' == "") {
			display as error "ERROR: Missing `var'"
			continue, break
		}
	} 

// Duplicates 	
	qui duplicates report
	local dupl = r(N) - r(unique_value)
	if (`dupl' != 0) {
		qui: duplicates tag, gen(dupl)
		display as error "ERROR: `dupl' duplicated observations" 
		tab year_from year_to if dupl != 0
		drop dupl
		continue, break
	}

//////////////////////////////////////////////	
// Inadmissible entries in mandatory variables
//////////////////////////////////////////////
 
	// Unmatched GEO or GEO_long
		preserve 
			qui import excel "$source/$country/$name.xlsx", sheet("Country codes") firstrow clear
			rename Country GEO_long
			qui drop if GEO == ""
			tempfile names 
			save "`names'", replace
		restore 
		qui merge m:1 GEO_long GEO using "`names'", keep(master matched) 
		qui count if _m == 1
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' unmatched country codes or naming"
			tab GEO_long GEO if _m == 1
			continue, break
		}
		qui drop _m

	// Unmatched currency 
		preserve 
			qui import excel "$source/$country/$name.xlsx", sheet("Currency") firstrow clear
			rename Country GEO
			rename Currency currency
			qui drop if GEO == ""
			drop Name
			tempfile curren 
			save "`curren'", replace
		restore 
		qui merge m:1 GEO currency using "`curren'", keep(master matched) 
		qui count if _m == 1
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' unmatched currency codes. Historical currency?"
			tab currency GEO if _m == 1
		}	
		qui drop _m
		
	// Errors in year_from, year_to
		qui count if year_from > year_to
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' cases of year_from > year_to"
			tab year_from year_to if year_from > year_to
			continue, break
		}
		qui count if year_from > $current_year | year_to > $current_year
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' years in the future"
			tab year_from year_to if year_from > $current_year | year_to > $current_year
			continue, break
		}
		qui count if year_from < 1600 | year_to < 1600
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' years < 1600, check"
			tab year_from year_to if year_from < 1600 | year_to < 1600
			continue, break
		}
		
	// Errors in tax
		qui count if tax != "inheritance" & tax != "estate" & tax != "gift" ///
					 & tax != "net wealth" & tax != "immovable property"
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' inadmissible entries for tax"
			tab tax if tax != "inheritance" & tax != "estate" & tax != "gift" ///
					      & tax != "net wealth" & tax != "immovable property"
			continue, break
		}
		
	// Errors in applies_to
		qui split(applies_to), parse(,)
		forvalues i = 1/`r(nvars)' {
				qui count if applies_to`i' != "children" & applies_to`i' != "spouse" & ///
							 applies_to`i' != "siblings" & applies_to`i' != "other relatives" & ///
							 applies_to`i' != "non relatives" & applies_to`i' != "everybody" & ///
							 applies_to`i' != "net financial wealth" & applies_to`i' != "net total wealth" & ///
							 applies_to`i' != "real estate" & ///
							 applies_to`i' != "unknown" & applies_to`i' != ""
				if (`r(N)' != 0) {
					display as error "ERROR: `r(N)' inadmissible entries for applies_to"
					tab applies_to`i' if applies_to`i' != "children" & applies_to`i' != "spouse" & ///
							 applies_to`i' != "siblings" & applies_to`i' != "other relatives" & ///
							 applies_to`i' != "non relatives" & applies_to`i' != "everybody" & ///
							 applies_to`i' != "net financial wealth" & applies_to`i' != "net total wealth" & ///
							 applies_to`i' != "real estate" & ///
							 applies_to`i' != "unknown" & applies_to`i' != ""
							 continue, break
				}
			cap drop applies_to`i'
		}		

	// Errors in status
		qui count if status != 0 & status != 1
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' inadmissible entries for status"
			tab status if status != 0 & status != 1
			continue, break
		}
	
	// Errors in subnational level
		qui count if subnationallevel != 0 & subnationallevel != 1
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' inadmissible entries for subnational level"
			tab subnationallevel if subnationallevel != 0 & subnationallevel != 1
			continue, break
		}
		
/////////////////////////////////////////////	
// Inadmissible entries in optional variables
/////////////////////////////////////////////	

	qui destring typetax firstyear exemption toprate toplowerbound fhome_exemp fbusiness_exemp taxablevalue different_tax, replace

	// Errors in firstyear
		qui count if firstyear > $current_year & firstyear < .
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' years in the future"
			tab firstyear if firstyear > $current_year & firstyear < .
			continue, break
		}
		qui count if firstyear < 1600
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' firstyear < 1600, check"
			tab firstyear if firstyear < 1600
		}
		
	// Errors in exemption
		qui count if exemption < 0 
		if (`r(N)' != 0) {
			display as error "WARNING: `r(N)' negative exemption"
			tab exemption if exemption < 0 
			continue, break
		}	

	// Errors in family home exempt
		qui count if fhome_exemp != 0 & fhome_exemp != 1 & fhome_exemp != .
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' inadmissible entries for fhome_exemp"
			tab fhome_exemp if fhome_exemp != 0 & fhome_exemp != 1 & fhome_exemp != .
			continue, break
		}
		
	// Errors in family business exempt
		qui count if fbusiness_exemp != 0 & fbusiness_exemp != 1 & fbusiness_exemp != .
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' inadmissible entries for fbusiness_exemp"
			tab fbusiness_exemp if fbusiness_exemp != 0 & fbusiness_exemp != 1 & fbusiness_exemp != .
			continue, break
		}		
	
	// Errors in taxable value
		qui count if taxablevalue != 1 & taxablevalue != 2 & taxablevalue != 3 & taxablevalue != .
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' inadmissible entries for taxablevalue"
			tab taxablevalue if taxablevalue != 1 & taxablevalue != 2 & taxablevalue != 3 & taxablevalue != .
			continue, break
		}

	// Errors in different_tax
		qui count if status == 1 & different_tax != 0 & different_tax != 1
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' inadmissible entries for different_tax"
			tab different_tax if status == 1 & different_tax != 0 & different_tax != 1
			continue, break
		}		
		qui count if status == 0 & different_tax != 0 & different_tax != 1 & different_tax != .
		if (`r(N)' != 0) {
			display as error "ERROR: `r(N)' inadmissible entries for different_tax"
			tab different_tax if status == 0 & different_tax != 0 & different_tax != 1 & different_tax != .
			continue, break
		}		
		
////////////////////////////	
// Automatic fill if no tax 
////////////////////////////	

	// Not applicable (-998)
	local na typetax exemption toprate toplowerbound fhome_exemp fbusiness_exemp taxablevalue
	
	foreach var of local na {
		qui replace `var' = -998 if status == 0
	} 
	
	// Tax brackets
	qui replace schedulelowerbounds = "0" if status == 0
	qui replace scheduleupperbounds = "-997" if status == 0
	qui replace marginalrates = "0" if status == 0
	qui replace toprate = 0 if status == 0
	qui replace toplowerbound = 0 if status == 0
				
	// Errors in lower bounds
		qui split(schedulelowerbounds), parse(,) notrim
		local nlb = `r(nvars)'
		forvalues i = 1/`nlb' {
			qui destring schedulelowerbounds`i', replace
			qui count if schedulelowerbounds`i' < 0 
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' negative schedule lower bounds"
				tab schedulelowerbounds`i' if schedulelowerbounds`i' < 0
				continue, break
			}			
		}
		drop schedulelowerbounds

	// Errors in upper bounds
		qui split(scheduleupperbounds), parse(,) notrim
		local nub = `r(nvars)'
		forvalues i = 1/`nub' {
			qui replace scheduleupperbounds`i' = "-997" if scheduleupperbounds`i' == "_and_over"
			qui destring scheduleupperbounds`i', replace
			qui count if scheduleupperbounds`i' < 0 & scheduleupperbounds`i' != -997
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' negative schedule upper bounds"
				tab scheduleupperbounds`i' if scheduleupperbounds`i' < 0 & scheduleupperbounds`i' != -997
				continue, break
			}
		}
		drop scheduleupperbounds
		
	// Errors in marginal rates
		qui split(marginalrates), parse(,) notrim
		local nmr = `r(nvars)'
		forvalues i = 1/`nmr' {
			destring marginalrates`i', replace
			qui count if marginalrates`i' < 0 
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' negative marginal rate"
				tab marginalrates`i' if marginalrates`i' < 0 
				continue, break
			}
			qui count if marginalrates`i' > 100 & marginalrates`i' < . 			
			if (`r(N)' != 0) {
				display as error "ERROR: `r(N)' marginal rate > 100"
				tab marginalrates`i' if marginalrates`i' > 100 & marginalrates`i' < . 	
				continue, break
			}
		}
		drop marginalrates
		
	// Check that lower bounds, upper bounds and marginal rates have the same 
	// number of entries
	if (`nlb' != `nub') | (`nlb' != `nmr') | (`nub' != `nmr') {
		display as error "ERROR: n. lower bound != n. upper bounds != n. marginal rates"
		continue, break
	}	
		
/////////////////////////////////////////	
// Automatic fill if schedule is reported 
/////////////////////////////////////////	

	// Correct the exemption if the first bracket includes it 
	qui replace exemption = exemption + scheduleupperbounds1 if status == 1 & exemption != . & exemption != -997 & schedulelowerbounds1 == 0 & marginalrates1 == 0
	 
	// Lower bounds
	qui replace schedulelowerbounds1 = . if status == 1 & exemption != . & exemption != -997 & schedulelowerbounds1 == 0 & marginalrates1 == 0
	qui replace schedulelowerbounds1 = 1 if status == 1 & exemption != . & exemption != -997 & marginalrates1 == 0	
	qui egen schedulelowerbounds = concat(schedulelowerbounds*), punct(",") 
	qui replace schedulelowerbounds = subinstr(schedulelowerbounds, ".,", "", .) 
	drop schedulelowerbounds1-schedulelowerbounds`nlb'
		
	qui split(schedulelowerbounds), parse(,) notrim
	local nlb = `r(nvars)'
	forvalues i = 1/`nlb' {
		qui destring schedulelowerbounds`i', replace
	}
	drop schedulelowerbounds

	// Upper bounds
	qui replace scheduleupperbounds1 = . if status == 1 & exemption != . & exemption != -997 & marginalrates1 == 0
	qui egen scheduleupperbounds = concat(scheduleupperbounds*), punct(",") 
	qui replace scheduleupperbounds = subinstr(scheduleupperbounds, ".,", "", .) 
	drop scheduleupperbounds1-scheduleupperbounds`nub'
		
	qui split(scheduleupperbounds), parse(,) notrim
	local nub = `r(nvars)'
	forvalues i = 1/`nub' {
		qui destring scheduleupperbounds`i', replace
	}
	drop scheduleupperbounds	
			
	// Marginal rates
	qui replace marginalrates1 = . if status == 1 & exemption != . & exemption != -997 & marginalrates1 == 0
	qui egen marginalrates = concat(marginalrates*), punct(",") 
	qui replace marginalrates = subinstr(marginalrates, ".,", "", .) 
	drop marginalrates1-marginalrates`nmr'
		
	qui split(marginalrates), parse(,) notrim
	local nmr = `r(nvars)'
	forvalues i = 1/`nmr' {
		qui destring marginalrates`i', replace
	}
	drop marginalrates		

	// Type of tax (before adjustment)
	if (`nmr' == 1)	qui replace typetax = 2 if status == 1 & typetax == . // Flat
	else {
		qui replace typetax = 2 if status == 1 & schedulelowerbounds1 != . & ///
							typetax == . & schedulelowerbounds2 == . // Flat 
		qui replace typetax = 3 if status == 1 & schedulelowerbounds2 != . & ///
							   typetax == . & schedulelowerbounds1 == schedulelowerbounds2 // Progressive
		qui replace typetax = 4 if status == 1 & schedulelowerbounds1 != . & schedulelowerbounds2 != . ///
							   & typetax == . & schedulelowerbounds1 != schedulelowerbounds2 // Progressive by brackets	
	}
	qui replace typetax = -999 if typetax == .
	
	// Additional filling
	qui egen first = min(firstyear)
	qui qui replace firstyear = first 
	qui replace firstyear = -999 if firstyear == .
	drop first
	
	qui replace fhome_exemp = -999 if fhome_exemp == .
	qui replace fbusiness_exemp = -999 if fbusiness_exemp == .
	qui replace taxablevalue = -999 if taxablevalue == .
	qui replace exemption = -999 if exemption == .
	qui replace different_tax = 0 if status == 1 & different_tax == .
		
	forvalues i = 1/`nlb' {
		qui replace schedulelowerbounds`i' = -999 if schedulelowerbounds1 == .	
		qui replace scheduleupperbounds`i' = -999 if scheduleupperbounds1 == .	
		qui replace marginalrates`i' = -999 if marginalrates1 == .	
	}		

////////////////////	
// Additional checks 
////////////////////		
	
// Check source is contant within GEO-year_from-year_to
	foreach var of local sourceinfo {
		qui egen mistake = nvals(`var'), by(GEO year_from year_to)
		qui count if mistake != 1 & mistake != .
		if (`r(N)' != 0) {
			display as error "ERROR: `var' not constant within GEO-year_from-year_to cells"
			tab `var' if mistake != 1 & mistake != .
		}	
		qui drop mistake
	}

// Check notes are constant within GEO-year_from-year_to-applies_to-tax groups
	qui egen mistake = nvals(note), by(GEO year_from year_to applies_to tax)
	qui count if mistake != 1 & mistake != .
	if (`r(N)' != 0) {
		display as error "ERROR: note not constant within GEO-year_from-year_to-applies_to-tax groups"
		tab note if mistake != 1 & mistake != .
	}	
	qui drop mistake
	
// Check currency is constant within GEO-year_from-year_to-applies_to-tax groups
	qui egen mistake = nvals(curren), by(GEO year_from year_to applies_to tax)
	qui count if mistake != 1 & mistake != .
	if (`r(N)' != 0) {
		display as error "ERROR: currency not constant within GEO-year_from-year_to-applies_to-tax groups"
		tab note if mistake != 1 & mistake != .
	}	
	qui drop mistake	

	
/////////////////////////////////
////// COMPATIBILITY CHECKS /////
/////////////////////////////////
	
	// First year must be lower or equal to year_from 
	qui count if firstyear > year_from & status == 1
	if (`r(N)' != 0) {
		display as error "ERROR: firstyear > year_from"
		tab firstyear year_from if firstyear > year_from & status == 1
	}		
	
	
/////////////////////
///	MANIPULATIONS ///
/////////////////////
	qui {
		
	// Schedule adjustment to the exemption threshold 
	gen schedulelowerbounds0 = 0 if exemption > 0 & marginalrates1 != 0 & schedulelowerbounds1 != . & schedulelowerbounds1 != -999
	gen marginalrates0 = 0 if exemption > 0 & marginalrates1 != 0 & marginalrates1 != . & marginalrates1 != -999
	gen scheduleupperbounds0 = exemption if exemption > 0 & marginalrates1 != 0 & marginalrates1 != . & marginalrates1 != -999
	
	forvalues i = 1/`nlb' {
		replace schedulelowerbounds`i' = schedulelowerbounds`i' + exemption if schedulelowerbounds0 == 0
		replace scheduleupperbounds`i' = scheduleupperbounds`i' + exemption if schedulelowerbounds0 == 0 & scheduleupperbounds`i' != -997 & scheduleupperbounds`i' != . 	
	}
	replace schedulelowerbounds0 = schedulelowerbounds1 if schedulelowerbounds0 == . 
	replace scheduleupperbounds0 = scheduleupperbounds1 if scheduleupperbounds0 == . 
	replace marginalrates0 = marginalrates1 if marginalrates0 == . 

	forvalues i = `nlb'(-1)0 {
		local j = `i' + 1
		rename schedulelowerbounds`i' schedulelowerbounds`j'
		rename scheduleupperbounds`i' scheduleupperbounds`j'
		rename marginalrates`i' marginalrates`j'
	}	
	
	forvalues i = `nlb'(-1)2 {
		local k = `i' + 1		
		local j = `i' - 1
		replace schedulelowerbounds`i' = schedulelowerbounds`k' if round(schedulelowerbounds`i', .01) == round(schedulelowerbounds`j', .01)
		replace scheduleupperbounds`i' = scheduleupperbounds`k' if round(scheduleupperbounds`i', .01) == round(scheduleupperbounds`j', .01)
		replace marginalrates`i' = marginalrates`k' if round(marginalrates`i', .01) == round(marginalrates`j', .01)
	}
	
	replace schedulelowerbounds2 = . if round(schedulelowerbounds2, .01) == round(schedulelowerbounds1, .01)
	replace scheduleupperbounds2 = . if round(scheduleupperbounds2, .01) == round(scheduleupperbounds1, .01)
	replace marginalrates2 = . if round(marginalrates2, .01) == round(marginalrates1, .01)
	cap drop schedulelowerbounds0 scheduleupperbounds0 marginalrates0 
	
	// Reshape the brackets
	gen schedulelowerbounds0 = .
	gen scheduleupperbounds0 = .
	gen marginalrates0 = .

	// Top Rate 
	replace toprate = marginalrates`nmr' if toprate == .
	local mr = `nmr' -1
	forvalues i = 1/`mr' {
		loca j = `i' + 1
		replace toprate = marginalrates`i' if toprate == . & marginalrates`j' == .
	}
	replace toprate = -999 if toprate == .

	////////////////////////////////////////////////////////////////////////////
	// Fill the Top Rate Lower Bound 
	replace toplowerbound = schedulelowerbounds`nlb' if toplowerbound == .
	local lb = `nlb' -1
	forvalues i = 1/`lb' {
		loca j = `i' + 1
		replace toplowerbound = schedulelowerbounds`i' if toplowerbound == . & schedulelowerbounds`j' == .
	}
	replace toplowerbound = -999 if toplowerbound == .
	////////////////////////////////////////////////////////////////////////////
	
	reshape long schedulelowerbounds scheduleupperbounds marginalrates, i(GEO year* applies_to tax) j(bracket)
	drop if schedulelowerbounds == . & bracket != 0

	local nums subnationallevel status typetax firstyear exemption toprate toplowerbound fhome_exemp fbusiness_exemp taxablevalue different_tax
	local strin currency AggSource Legend Source Link note
	foreach var of local nums {
		replace `var' = . if bracket != 0
	}
	foreach var of local strin {
		replace `var' = "" if bracket != 0
	}

	sort GEO tax applies_to year_f year_t br
	order GEO GEO_long year_f year_t applies_to tax bracket schedulelowerbounds scheduleupperbounds marginalrates ///
			curre status typetax firstyear exemption toprate toplowerbound ///
			fhome_exemp fbusiness_exemp subnationallevel taxablevalue different_tax AggSource ///
			Legend Source Link note  
	compress

	// Rename variables for publication (5 digit)
	rename schedulelowerbounds adjlbo
	rename scheduleupperbounds adjubo
	rename marginalrates adjmrt
	rename status status
	rename typetax typtax
	rename firstyear firsty
	rename exemption exempt
	rename toprate toprat
	rename toplowerbound toplbo 
	rename fhome_exemp homexe
	rename fbusiness_exemp bssexe	
	
	// Format variables 
	format adjlbo adjubo exempt toplbo %20.0f
	format adjmrt toprat %5.2f
	
	// The other variables will go in the metadata: subnationallevel taxablevalue
	
	// Define labels 
	label var curren "Currency from the source"
	label var applies_to "Sector"
	label var tax "Tax" 
	label var bracket "Number of bracket in tax schedule"
	label var status "Tax Indicator"
	label var firsty "First Year for Tax"
	label var typtax "Type of Tax (1 Lump-sum, 2 Flat, 3 Progressive, 4 Progressive by brackets)"
	label var exempt "Exemption Threshold"
	label var adjlbo "Lower Bound for Exemption-adjusted Tax Bracket"
	label var adjubo "Upper Bound for Exemption-adjusted Tax Bracket"
	label var adjmrt "Tax Marginal Rate for Exemption-adjusted Tax Bracket"
	label var toprat "Top Marginal Rate"
	label var toplbo "Top Marginal Rate Applicable From"
	label var homexe "Whether Family Home is Exempt"
	label var bssexe "Whether Family Business is Exempt"	
	label var subnationallevel "Whether the information applies to subnational units"
	label var taxablevalue "Method of evaluation of the assets for the tax base (1 Purchase cost, 2 FMV, 3 Notional)"
	label var different_tax "Whether EIG are taxed through non-EIG taxes"

	label define labels -999 "Missing" -998 "_na" -997 "_and_over"
	foreach var in exempt toprat toplbo adjlbo adjubo adjmrt firsty {
		label values `var' labels, nofix
	}	
	
	label define indicator 0 "No" 1 "Yes" -999 "Missing" -998 "_na"
	foreach var in status homexe bssexe subnational different_tax {
		label values `var' labels, nofix
	}	
	
	label define typtax 1 "Lump-sum" 2 "Flat" 3 "Progressive" 4 "Progressive by brackets" -999 "Missing" -998 "_na"
	label values typtax typtax 

	label define value 1 "Purchase cost" 2 "Fair market value" 3 "Notional value" -999 "Missing" -998 "_na"
	label values taxablevalue value 
	
	compress
	}
	display as result "End!" 

	/* Replicate for years 
	gen expans = year_to - year_from + 1
	expand expans, gen(dupl)
	gen year = year_from
	egen group = group(GEO applies_to tax year_from year_to)
	sort group year dupl
	replace year = year[_n-1] + 1 if year[_n-1] != . & group == group[_n-1]
	drop dupl year_* expans group