
// PURCHASES OF FLATS AND HOUSES
********************************
// This script accepts the (extracted) raw data that RWI ships and tidy it a bit.
// apartments for sale (_WK) and houses for sale (_HK) are bound together into purchases.dta

// specify the working directory to be the directory where the raw data lives in
cd "F:/Allgemein/Data/RWI Regional Data/Immoscout/2022/extracted/"

set more off

//Data Shaping
**************
capture log close
log using "prepare_prices.log", replace

// folders where the prices data live -- relative to the working directory
global dir_wk "WK_SUF_ohneText/"
global dir_hk "HK_SUF_ohneText/"

// list of all the .dta files in each folder
local flistWK: dir "$dir_wk/" files "*.dta"
local flistHK: dir "$dir_hk/" files "*.dta"

// prepend the dir name to the .dta files to get the full path -> dir_wk/*.dta
foreach x in `flistWK' {
    local flist0 "`flist0' "$dir_wk/`x'""
}

foreach x in `flistHK' {
    local flist1 "`flist1' "$dir_hk/`x'""
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

foreach x in obid nebenkosten kaufpreis mieteinnahmenpromonat heizkosten baujahr ///
 letzte_modernisierung wohnflaeche grundstuecksflaeche nutzflaeche etage anzahletagen ///
 zimmeranzahl nebenraeume schlafzimmer badezimmer parkplatzpreis wohngeld ev_kennwert ///
 laufzeittage hits click_schnellkontakte click_customer click_weitersagen click_url ///
 immobilientyp ajahr amonat ejahr emonat aufzug balkon betreut denkmalobjekt einbaukueche ///
 einliegerwohnung ev_wwenthalten ferienhaus foerderung gaestewc garten heizkosten_in_wm_enthalten ///
 kaufvermietet keller parkplatz rollstuhlgerecht bauphase ausstattung energieeffizienzklasse ///
 energieausweistyp haustier_erlaubt heizungsart kategorie_Wohnung kategorie_Haus objektzustand {
    replace `x'=. if `x'<0
}
misstable sum, all

gen lprice=log(kaufpreis)
gen priceqm=kaufpreis/wohnflaeche
label var priceqm "Kaufpreis pro Quadratmeter"
gen lpriceqm=log(priceqm)
egen region = group(erg_amd)
label var region "identifier labor market region"
gen nkqm=nebenkosten/wohnflaeche
label var nkqm "Nebenkosten pro qm"
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
label var d_long "longitude of distination"
rename y d_lat
label var d_lat "latitude of destination"
geodist o_lat o_long d_lat d_long, gen(dist_cbd)
gen ldist=log(dist_cbd)
label var ldist "log of distance to CBD"


// Set missings to zero and control for missings by M`x'

foreach x in kaufpreis priceqm nebenkosten nkqm baujahr wohnflaeche etage anzahletagen zimmeranzahl schlafzimmer badezimmer immobilientyp ajahr balkon einbaukueche foerderung garten keller ausstattung heizungsart kategorie_Haus kategorie_Wohnung objektzustand {
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

gen year=ajahr
drop ajahr

save "purchases", replace
log close


//Regression Analysis
*********************

use "purchases", clear
capture log close
log using "check_reg_buy.log", replace

*We follow this approach as stata crashes with i.region#c.ldist in the whole dataset

gen lbuyindex = .
gen bCBD =.
gen seCBD =.
forval num = 1/141{
    reghdfe lpriceqm ldist Mwohnflaeche Dwohnflaeche Mzimmeranzahl Dzimmeranzahl Mimmobilientyp Dimmobilientyp Mbalkon Dbalkon Mgarten Dgarten Mkeller Dkeller Mheizungsart Dheizungsart if region == `num', abs(FE=year)
    replace lbuyindex = FE + _b[_cons] if region ==`num'
    replace bCBD= _b[ldist] if region ==`num'
    replace seCBD= _se[ldist] if region ==`num'
    drop FE
}
collapse (mean) lbuyindex bCBD seCBD wohnflaeche lpriceqm (count) rentNregion=lpriceqm, by(region year)
gen buyindex=exp(lbuyindex)

save "buyindex", replace
log close

// merge with the rental index
*sort region year
*merge 1:1 region year using "rentindex"
*drop _merge
*save "HPI", replace

*tabstat priceqm dist_cbd wohnflaeche zimmeranzahl immobilientyp balkon garten keller heizungsart , stat(co n me sd p10 p90) format(%9.2fc)
