# CBS Buurt, Wijk, Gemeente en Provincie
Download, extract and transform data from the Dutch Statistical Institute (Centraal Bureau voor de Statistiek, CBS).

CBS delivers map data on buurt (neighborhood), wijk (district/ward) and gemeente (municipality/city) levels.
The data includes demographics and migration. 

This project simplifies the map lines, solving some overlaps, slivers and gaps. Also it replaces the -999999 values used by CBS to indicate 'no data' by 'null'

This project also creates a map for provinces (provincies) as an aggregate of the municipality map.

## Prerequisites
* bash 
* git
* nodejs (tested with version 16)
* docker (or podman)
* curl
* unzip

## usage
```bash
git clone this_repository
cd this_repository
npm install
# download, convert and create files for 2023, see output directory
./create2023.sh

# manually download the 2121 data first, the previously working url no longer works
./create2021.sh
```