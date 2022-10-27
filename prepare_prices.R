################################################################################
# PURCHASES OF FLATS AND HOUSES #
## This script accepts the (extracted) raw data that RWI ships and tidy it a bit.
## apartments for sale (_WK) and houses for sale (_HK) are bound together into purchases.dta
################################################################################

## required libraries
pkgs = c('haven', 'data.table', 'fixest', 'geodist')
if (!requireNamespace(pkg)) {
  install.packages(pkg)
} else {
  library(pkg, character.only = TRUE)
}

## Data cleaning ----
# list of all the .dta files in each folder (apartments for sale,and houses for sale)
flist0 = dir("WK_SUF_ohneText", pattern = ".dta$", full.names = TRUE)
flist1 = dir("HK_SUF_ohneText", pattern = ".dta$", full.names = TRUE)

## read in files and bind them
purchases = lapply(c(flist0, flist1), function(f) {
  message("Reading <", f, "> ...")
  haven::read_dta
}) # your computer might not handle
purchases = rbindlist(purchases, use.names=TRUE, fill=TRUE)
## drop if the labor market region (erg_amd) or the grid cell (r1_id) is unknown
purchases = purchases[!(erg_amd==-9 | r1_id == "-9"), ]
setNames(purchases, 'ajahr', 'year')

vars = c(
  "obid", "nebenkosten", "kaufpreis", "mieteinnahmenpromonat", "heizkosten", "baujahr",
  "letzte_modernisierung", "wohnflaeche", "grundstuecksflaeche", "nutzflaeche", "etage",
  "anzahletagen", "zimmeranzahl", "nebenraeume", "schlafzimmer", "badezimmer",
  "parkplatzpreis", "wohngeld", "ev_kennwert", "laufzeittage", "hits", "click_schnellkontakte",
  "click_customer", "click_weitersagen", "click_url", "immobilientyp", "ajahr",
  "amonat", "ejahr", "emonat", "aufzug", "balkon", "betreut", "denkmalobjekt",
  "einbaukueche", "einliegerwohnung", "ev_wwenthalten", "ferienhaus", "foerderung",
  "gaestewc", "garten", "heizkosten_in_wm_enthalten", "kaufvermietet",
  "keller", "parkplatz", "rollstuhlgerecht", "bauphase", "ausstattung",
  "energieeffizienzklasse", "energieausweistyp", "haustier_erlaubt", "heizungsart",
  "kategorie_Wohnung", "kategorie_Haus", "objektzustand"
)


purchases[, (vars) := lapply(.SD, function(x) fifelse(x<0, NA, x)), .SDcols=(vars)]
# summary of missing values
purchases[, lapply(.SD, function(x) sum(is.na(x)))]

## variable translation and labeling
var_label = read.csv("variable-metadata.csv")

## define new vars
purchases[, lprice:=log(kaufpreis)
          ][, pricesqm:=kaufpreis/wohnflaeche
            ][,lpricesqm:=log(pricesqm)
              ][,region:=as.factor(erg_amd)
                ][,nksqm:=nebenkosten/wohnflaeche
                  ][,type:=as.factor(immobilientyp)
                    ][,immobilientyp:=type-1
                      ][,type:=NULL]

grid = read_dta("../grid.coordinaten.dta")
purchases = merge(purchases, grid, by="r1_id")
amr = read.dta("../Centroids_CBDv1_mean.dta")
names(amr)[grepl("^x$|^y$", names(amr))] = c('d_long', 'd_lat')

purchases = merge(purchases, amr, by="erg_amd")
purchases[, dist_cbd:=geodist(cbind(o_lat, o_long, d_lat, d_long), measure = "geodesic")
][,ldist:=log(dist_cbd)] # log of distance to CBD
setnames(purchases, var_label$var_de, var_label$var_en)
rm(grid, amr)

## Generate summary statistics table
purchases[, .(rentsqm, dist_cbd, floorspace, rooms, type, balcony, garden, basement, heating_type)
][, lapply(.SD, function(x) {
  list(count = length(x),mean = mean(x, na.rm = TRUE),sd = sd(x, na.rm = TRUE),
       p10 = quantile(x, 0.1, na.rm = TRUE),p90 = quantile(x, 0.9, na.rm = TRUE))
})]


## Set missings to zero and control for missings by M`x'
vars = c("kaufpreis", "priceqm", "nebenkosten", "nkqm", "baujahr", "wohnflaeche", "etage", "anzahletagen", "zimmeranzahl", "schlafzimmer", "badezimmer", "immobilientyp", "ajahr", "balkon", "einbaukueche", "foerderung", "garten", "keller", "ausstattung", "heizungsart", "kategorie_Haus", "kategorie_Wohnung", "objektzustand")


# M`x' = 1 if `x' is missing
purchases[, paste0("M",vars) := lapply(.SD, function(x) fifelse(is.na(x), 1, 0)),.SDcols=(vars)]

# Ersetze missings durch 0, aber kontrolliere für missing über M`x'
purchases[, (vars):=lapply(.SD, function(x) fifelse(is.na(x), 0)),.SDcols=(vars)]
# Wir nehmen den zeitinvarianten Durchschnitt
# D`x' = `x' minus national average
purchases[,paste0("D", vars):=lapply(.SD, function(x) x-mean(x, na.rm=TRUE)), .SDcols=(vars)]

purchases[, Mheating_type:=0
][is.na(Mheating_type), Mheating_type:=1
][is.na(heating_type)|heating_type==13,heating_type:=0]


## add variable label attribute
purchases[, (vars) := Map(
  function(x, l) labelled(x, label = l),
  .SD, var_label$label[match(vars, var_label$var_de)]
),
.SDcols = (vars)
]

purchases[, paste0("M", vars) := Map(
  function(x, l) labelled(x, label = sprintf("1 if %s is missing", l)),
  .SD, vars),
  .SDcols = paste0("M", vars)
]

purchases[, paste0("D", vars) := Map(
  function(x, l) labelled(x, label = sprintf("%s minus national average", l)),
  .SD, vars),
  .SDcols = paste0("D", vars)
]


write_dta(purchases, "purchases.dta")

