
// RENTS OF FLATS AND HOUSES
*****************************
// This script accepts the (extracted) raw data that RWI ships and tidy it a bit.
// apartments for rent (_WM) and houses for rent (_HM) are bound together into rentals.dta

// specify the working directory to be the directory where the raw data lives in
cd "F:/Allgemein/Data/RWI Regional Data/Immoscout/2022/extracted/"

set more off

//Data Shaping
**************
capture log close
log using "prepare_rents.log", replace

// folders where the rents data live -- relative to the working directory
global dir_wm "WM_SUF_ohneText/"
global dir_hm "HM_SUF_ohneText/"

// list of all the .dta files in each folder
local flistWM: dir "$dir_wm/" files "*.dta"
local flistHM: dir "$dir_hm/" files "*.dta"

// prepend the dir name to the .dta files to get the full path -> dir_wm/*.dta
foreach x in `flistWM' {
	local flist0 "`flist0' "$dir_wm/`x'""
}

foreach x in `flistHM' {
	local flist1 "`flist1' "$dir_hm/`x'""
}

// read the files in and append them
local counter = 0
foreach f in `flist0' `flist1' {
	disp "Reading <`f'> ..."
if `counter' == 0 {
	use "`f'", clear
}
else {
	append using "`f'"
}

local counter = `counter' + 1
}

drop if erg_amd==-9 /*drop if Arbeitsmarktregion unknown*/
drop if r1_id=="-9" /*drop if grid cell unknown*/

local vars "obid mietekalt nebenkosten baujahr wohnflaeche etage anzahletagen zimmeranzahl immobilientyp ajahr amonat ejahr emonat balkon garten keller ausstattung heizungsart kategorie_Haus kategorie_Wohnung"
keep `vars' erg_amd r1_id
foreach x in `vars' {
	replace `x'=. if `x'<0
}

misstable sum, all

gen lrent=log(mietekalt)
gen rentsqm=mietekalt/wohnflaeche
label var rentsqm "Rent per square meter"
gen lrentsqm=log(rentsqm)
egen region = group(erg_amd)
label var region "identifier labor market region"
gen nksqm=nebenkosten/wohnflaeche
label var nksqm "Nebenkosten pro qm"
egen type=group(immobilientyp)
replace immobilientyp=type-1
drop type

sort r1_id
merge m:1 r1_id using "../../grid.coordinaten.dta"
tab _merge
keep if _merge==3
drop _merge
sort erg_amd
merge m:1 erg_amd using "../../Centroids_CBDv1_mean.dta"
tab _merge
drop _merge
rename x d_long
label var d_long "longitude of destination"
rename y d_lat
label var d_lat "latitude of destination"
geodist o_lat o_long d_lat d_long, gen(dist_cbd)
label var dist_cbd "Distance to CBD"
gen ldist=log(dist_cbd)
label var ldist "log of distance to CBD"

//Generate summary statistics table

rename wohnflaeche floorspace
label var floorspace "Living space in sqm"
rename zimmeranzahl rooms
label var rooms "Number of rooms"
rename immobilientyp type
label var type "Type of housing, 1 if apartment"
rename balkon balcony
label var balcony "Balcony"
rename garten garden
label var garden "Garden"
rename keller basement
label var basement "Basement"
rename heizungsart heating_type
label var heating_type "Type of heating"
rename mietekalt rent
label var rent "Rent net of utilities"
rename nebenkosten utilities
rename nksqm utilitiessqm
rename baujahr constr_year
rename etage floor
label var floor "Floor location of apartment"
rename anzahletagen number_floors

tabstat rentsqm dist_cbd floorspace rooms type balcony garden basement heating_type, stat(count mean sd p10 p90) col(stat) format(%12.0gc)

// Set missings to zero and control for missings by M`x'

foreach x in obid rent utilities constr_year floorspace floor number_floors rooms ///
 type year balcony garden basement rentsqm utilitiessqm {
	gen M`x'=.
	replace M`x'=1 if `x'==.
	replace M`x'=0 if M`x'==.
	replace `x'=0 if `x'==.  /*Ersetze missings durch 0, aber kontrolliere für missing über M`x'*/
	label var M`x' "1 if `x' is missing"
	egen temp=mean(`x') /*Wir nehmen den zeitinvarianten Durchschnitt*/
	*bysort year: egen temp=mean(`x')
	gen D`x'=`x'-temp
	label var D`x' "`x' minus national average"
	drop temp
}

gen Mheating_type=0
replace Mheating_type=1 if heating_type==.
replace heating_type=0 if heating_type==.|heating_type==13

gen year=ajahr
drop ajahr

save "rentals", replace
log close


//Regression Analysis
*********************

*We follow this loop-approach as stata crashes with i.region#c.ldist in the whole dataset

use "rentals", clear
capture log close
log using "check_rent_reg.log", replace

gen lrentindex = .
gen bCBD =.
gen seCBD =.
forval num = 1/141 {
	reghdfe lrentsqm ldist Mfloorspace Dfloorspace Mrooms Drooms Mtype Dtype Mbalcony ///
	Dbalcony Mgarden Dgarden Mbasement Dbasement Mheating_type i.heating_type if region == `num', abs(FE=year)
	replace lrentindex = FE + _b[_cons] if region ==`num'
	replace bCBD= _b[ldist] if region ==`num'
	replace seCBD= _se[ldist] if region ==`num'
	drop FE
}
collapse (mean) lrentindex bCBD seCBD floorspace lrent (count) rentNregion=lrent, by(region year)
gen rentindex=exp(lrentindex)

save "rent_index", replace
log close


/*
//Regression Analysis Alternative
*********************************

*Here, we do apply i.region#c.ldist as it works with the cleaned dataset

use "rentals", clear
capture log close
log using "check_rent_reg_alt.log", replace

egen ryid = group(region year)
gen lrentindex = .
reghdfe lrentqm i.region#c.ldist Mwohnflaeche Dwohnflaeche Mzimmeranzahl Dzimmeranzahl ///
Mimmobilientyp Dimmobilientyp Mbalkon Dbalkon Mgarten Dgarten Mkeller Dkeller Mheizungsart Dheizungsart, abs(FE = ryid)
replace lrentindex = FE + _b[_cons]

collapse (mean) lrentindex wohnflaeche lrent (count) rentNregion=lrent, by(region year)
gen rentindex=exp(lrentindex)

save "rent_index2", replace
log close
*/
