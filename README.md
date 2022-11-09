# [AHS (2022)](https://doi.org/10.1016/j.regsciurbeco.2022.103836)

This repo contains scripts that prepare the raw [RWI-GEO-RED](https://www.rwi-essen.de/en/research-advice/further/research-data-center-ruhr-fdz/data-sets/rwi-geo-red/x-real-estate-data-and-price-indices) data for use in [Ahlfeldt, Heblich, and Seidel (2022)](https://doi.org/10.1016/j.regsciurbeco.2022.103836) algorithm.

## Instruction

1.  Unzip/extract the zipped data that comes from RWI FDZ (which you may have downloaded as `HiDrive.zip`) as below:

``` bash
├── csv
│   ├── HK_SUF_csv
│   ├── HM_SUF_csv
│   ├── WK_SUF_csv
│   ├── WM_SUF_csv
│   ├── HK_SUF_csv.zip
│   ├── HM_SUF_csv.zip
│   ├── WK_SUF_csv.zip
│   └── WM_SUF_csv.zip
├── Dokumentation
│   ├── Data report
│   ├── dup_id
│   ├── Frequencies
│   └── Labels
├── Raster_shp
└── Stata
    ├── HK_SUF_ohneText
    ├── HM_SUF_ohneText
    ├── WK_SUF_ohneText
    ├── WM_SUF_ohneText
        ├── WM_SUF_ohneText10.dta
        ├── WM_SUF_ohneText11.dta
        ├── WM_SUF_ohneText1.dta
        ├── WM_SUF_ohneText2.dta
        ├── WM_SUF_ohneText3.dta
        ├── WM_SUF_ohneText4.dta
        ├── WM_SUF_ohneText5.dta
        ├── WM_SUF_ohneText6.dta
        ├── WM_SUF_ohneText7.dta
        ├── WM_SUF_ohneText8.dta
        └── WM_SUF_ohneText9.dta
    ├── HK_SUF_ohneText.zip
    ├── HM_SUF_ohneText.zip
    ├── WK_SUF_ohneText.zip
    ├── WM_SUF_ohneText.zip
    ├── HK_SUF
    ├── HM_SUF
    ├── WK_SUF
    ├── WM_SUF
    ├── HK_SUF.zip
    ├── HM_SUF.zip
    ├── WK_SUF.zip
    └── WM_SUF.zip
```

2.  Run `prepare_rents.do` and `prepare_prices.do`.

Additionally, in the `extra/` folder, labor market regions ([Kosfeld and Werner (2012)](https://link.springer.com/article/10.1007/s13147-011-0137-8 "German Labour Markets—New Delineation after the Reforms of German District Boundaries 2007–2011")), (1kmx1km) grid, municipality, and district information are provided. Note: the Kosfeld and Werner (2012)'s labor market regions are updated for the 2019 (end of the year) administrative structure ([Verwaltungsgliederung am 31.12.2019](https://www.destatis.de/DE/Themen/Laender-Regionen/Regionales/Gemeindeverzeichnis/Administrativ/Archiv/Verwaltungsgliederung/31122019_Jahr.html)) of districts.
