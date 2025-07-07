{smcl}

{title:Verification and adjustment code for EIGT}


{title:Syntax}

{p 8 8 2} {bf:eigt_verify} {it:source_name} {it:country_name} [, {it:options}]


{title:Options}

{col 5}{it:Options}{col 31}Description
{space 4}{hline}
{col 5}Tax credit options{col 31}{break}
{col 5}{bf:{ul:value}cr({it:string})}{col 31}Either {it:exemption} or a positive number. If absent, no tax credit is applied.
{col 5}{bf:{ul:dummy}cr({it:string})}{col 31}Name of the variable indicating whether the tax credit applies. Required if {bf:{ul:value}cr()} is specified.{col 138}{break}
{space 4}{hline}

{title:Description}

{p 4 4 2}
{bf:eigt_verify} ...  describe here the adjustment


{title:Options}

{p 4 4 2}
{bf:valuecr({it:string})} allows to state through {it:exemption} that the exemption column contains a tax credit; it also allows for a 
positive number as entry to directly specify the amount of tax credit if it does not coincide with the exemption.    {break}
It works in combination with {bf:dummycr({it:string})} (see below).    {break}

{p 4 4 2}
{bf:dummycr({it:string})} takes the name of the indicator variable in the input file
which assumes value 1 for the combinations of {it:year_from}, {it:year_to}, {it:tax}, and {it:applies_to} to which the indication in option {bf:value_cr({it:string})} applies.
It is required if option {bf:valuecr({it:string})} is specified.    {break}


{title:Remarks}

{p 4 4 2}
...    {break}


{title:Examples}

{p 4 4 2}
	. {bf:eigt_verify EY_EIG_Guide United_States, valuecr(exemption) dummycr(taxcredit)}    {break}
	
{p 4 4 2}
	. {bf:eigt_verify EY_EIG_Guide Philippines}    {break}


{title:Version}

{p 4 4 2}
This version: 18 July 2024    {break}



