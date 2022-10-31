################################################################################
# RENTS OF FLATS AND HOUSES #
## This script accepts the (extracted) raw data that RWI ships and tidy it a bit.
## apartments for rent (_WM) and houses for rent (_HM) are bound together into rentals.dta
################################################################################

## required libraries
pkgs = c("haven", "data.table", "fixest", "geodist")
for (pkg in pkgs) {
  if (!requireNamespace(pkg)) {
    install.packages(pkg)
  } else {
    library(pkg, character.only = TRUE)
  }
}

## Data cleaning ----
# list of all the .dta files in each folder (apartments for rent, and houses for rent)
flist0 = dir("Stata/WM_SUF_ohneText", pattern=".dta$", full.names=TRUE)
flist1 = dir("Stata/HM_SUF_ohneText", pattern=".dta$", full.names=TRUE)
flist = list(wk=flist0, hk=flist1)

## read in files and bind them
rentals = vector('list', length(flist))
names(rentals) = names(flist)

for (i in seq_along(rentals)) {
rentals[[i]] = lapply(flist[[i]], function(f) {
  message("Reading <", f, "> ...")
  haven::read_dta(f)
})
}

# stacking up -- may break your machine
# add "R_MAX_VSIZE=100Gb" to your .Renviron, you can open it with usethis::edit_r_environ()

# stacking up files of apartments, and homes separately
rentals = lapply(rentals, \(.l) rbindlist(.l, use.names=TRUE, fill=TRUE))
# stacking apartments, and homes together into one big data.frame
rentals = rbindlist(rentals, use.names=TRUE, fill=TRUE)

## drop if the labor market region (erg_amd) or the grid cell (r1_id) is unknown
rentals = rentals[!(erg_amd==-9 | r1_id == "-9"), ]

vars = c(
  "obid", "mietekalt", "nebenkosten", "baujahr", "wohnflaeche", "etage",
  "anzahletagen", "zimmeranzahl", "immobilientyp", "ajahr", "amonat", "ejahr",
  "emonat", "balkon", "garten","keller", "ausstattung", "heizungsart",
  "kategorie_Haus", "kategorie_Wohnung"
)

rentals = rentals[, c(vars, "erg_amd", "r1_id"), with=FALSE]
rentals[, (vars) := lapply(.SD, function(x) fifelse(x<0, NA, x)), .SDcols=(vars)]
# summary of missing values
rentals[, lapply(.SD, function(x) sum(is.na(x)))]

## for variable translation and labeling
var_label = read.csv("variable-metadata.csv")
# translate variable names
setnames(rentals, 'ajahr', 'year')
setnames(rentals, var_label$var_de, var_label$var_en)

## define new vars
rentals[, lrent:=log(mietekalt)
       ][, rent_sqm:=mietekalt/wohnflaeche
         ][,lrent_sqm:=log(rentsqm)
           ][,region:=as.factor(erg_amd)
             ][,utilities_sqm:=nebenkosten/wohnflaeche
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

rm(grid, amr)

## Generate summary statistics table
rentals[, .(rentsqm, dist_cbd, floorspace, rooms, type, balcony, garden, basement, heating_type)
       ][, lapply(.SD, function(x) {
  list(count = length(x),mean = mean(x, na.rm = TRUE),sd = sd(x, na.rm = TRUE),
       p10 = quantile(x, 0.1, na.rm = TRUE),p90 = quantile(x, 0.9, na.rm = TRUE))
         })]


## Set missings to zero and control for missings by M`x'
vars = c(
  "rent", "rent_sqm", "utilities_sqm", "utilities", "constr_year", "floorspace",
  "floor","number_floors", "rooms","type", "year", "month", "balcony", "garden", "basement"
)

# M`x' = 1 if `x' is missing
rentals[, paste0("M",vars) := lapply(.SD, function(x) fifelse(is.na(x), 1, 0)),.SDcols=(vars)]

# Ersetze missings durch 0, aber kontrolliere für missing über M`x'
rentals[, (vars):=lapply(.SD, function(x) fifelse(is.na(x), 0, x)),.SDcols=(vars)]
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
