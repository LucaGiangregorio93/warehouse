

// The .do file produces an sources_for_website.xlsx
// the file isolate refenrences infomration that are used in Tableau as hiperlyinks

global path 	"`:env USERPROFILE'/Dropbox/gcwealth"
cd "$path"

clear 
import delimited ".\output\databases\warehouse_viz.csv", 

keep source legend ref_link aggsource link citekey

gen n=1
collapse n , by(source legend ref_link legend ref_link aggsource link citekey) 

drop if source==""
bys source: gen N=_N
tab N


export excel using ///
"C:\Users\mtarga\Dropbox\gcwealth\output\databases\website\sources_for_website.xlsx", ///
firstrow(variables) replace
