################################################################################
# RENTS OF FLATS AND HOUSES #
## This script accepts the (extracted) raw data that RWI ships and tidy it a bit.
## apartments for rent (_WM) and houses for rent (_HM) are binded together into rentals.dta
################################################################################

## required libraries
pkgs = c('haven', 'data.table', 'fixest', 'geodist')
if (!requireNamespace(pkg)) {
  install.packages(pkg)
} else {
  library(pkg, character.only = TRUE)
}

## Data cleaning ----
# list of all the .dta files in each folder (apartments for rent, and houses for rent)
flist0 = dir("WM_SUF_ohneText", pattern = ".dta$", full.names = TRUE)
flist1 = dir("HM_SUF_ohneText", pattern = ".dta$", full.names = TRUE)

## read in files and bind them
rentals = lapply(c(flist0, flist1), function(f) {
  message("Reading in <", f, "> ...")
  haven::read_dta
  }) # your computer might not handle
rentals = rbindlist(rentals, use.names=TRUE, fill=TRUE)
## drop if the labor market region (erg_amd) or the grid cell (r1_id) is unknown
rentals = rentals[!(erg_amd==-9 | r1_id == "-9"), ]
setNames(rentals, 'ajahr', 'year')

vars = c(
  "obid", "mietekalt", "nebenkosten", "baujahr", "wohnflaeche", "etage",
  "anzahletagen", "zimmeranzahl", "immobilientyp", "year", "balkon", "garten",
  "keller", "ausstattung", "heizungsart", "kategorie_Haus", "kategorie_Wohnung"
)

rentals = rentals[, c(vars, "erg_amd", "r1_id"), with=FALSE]
rentals[, (vars) := lapply(.SD, function(x) fifelse(x<0, NA, x)), .SDcols=(vars)]
# summary of missing values
rentals[, lapply(.SD, function(x) sum(is.na(x)))]

## variable translation and labeling
var_label = read.csv("variable-metadata.csv")

## define new vars
rentals[, lrent:=log(mietekalt)
       ][, rentsqm:=mietekalt/wohnflaeche
         ][,lrentsqm:=log(rentsqm)
           ][,region:=as.factor(erg_amd)
             ][,nksqm:=nebenkosten/wohnflaeche
               ][,type:=as.factor(immobilientyp)
                 ][,immobilientyp:=type-1
                   ][,type:=NULL]

grid = read_dta("../grid.coordinaten.dta")
rentals = merge(rentals, grid, by="r1_id")
amr = read.dta("../Centroids_CBDv1_mean.dta")
names(amr)[grepl("^x$|^y$", names(amr))] = c('d_long', 'd_lat')

rentals = merge(rentals, amr, by="erg_amd")
rentals[, dist_cbd:=geodist(cbind(o_lat, o_long, d_lat, d_long), measure = "geodesic")
       ][,ldist:=log(dist_cbd)] # log of distance to CBD
setnames(rentals, var_label$var_de, var_label$var_en)
rm(grid, amr)

## Generate summary statistics table
rentals[, .(rentsqm, dist_cbd, floorspace, rooms, type, balcony, garden, basement, heating_type)
       ][, lapply(.SD, function(x) {
  list(count = length(x),mean = mean(x, na.rm = TRUE),sd = sd(x, na.rm = TRUE),
       p10 = quantile(x, 0.1, na.rm = TRUE),p90 = quantile(x, 0.9, na.rm = TRUE))
         })]


## Set missings to zero and control for missings by M`x'
vars = c(
  "obid", "rent", "utilities", "constr_year", "floorspace", "floor","number_floors",
  "rooms", "type", "year", "balcony", "garden", "basement","rentsqm", "utilitiessqm"
)

# M`x' = 1 if `x' is missing
rentals[, paste0("M",vars) := lapply(.SD, function(x) fifelse(is.na(x), 1, 0)),.SDcols=(vars)]

# Ersetze missings durch 0, aber kontrolliere für missing über M`x'
rentals[, (vars):=lapply(.SD, function(x) fifelse(is.na(x), 0)),.SDcols=(vars)]
# Wir nehmen den zeitinvarianten Durchschnitt
# D`x' = `x' minus national average
rentals[,paste0("D", vars):=lapply(.SD, function(x) x-mean(x, na.rm=TRUE)), .SDcols=(vars)]

rentals[, Mheating_type:=0
       ][is.na(Mheating_type), Mheating_type:=1
         ][is.na(heating_type)|heating_type==13,heating_type:=0]


## add variable label attribute
rentals[, (vars) := Map(
  function(x, l) labelled(x, label = l),
  .SD, var_label$label[match(vars, var_label$var_de)]
  ),
  .SDcols = (vars)
  ]

rentals[, paste0("M", vars) := Map(
  function(x, l) labelled(x, label = sprintf("1 if %s is missing", l)),
  .SD, vars),
  .SDcols = paste0("M", vars)
  ]

rentals[, paste0("D", vars) := Map(
  function(x, l) labelled(x, label = sprintf("%s minus national average", l)),
  .SD, vars),
  .SDcols = paste0("D", vars)
]


write_dta(rentals, "rentals.dta")

