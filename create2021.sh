#!/bin/bash

if ! command -v unzip &> /dev/null
then
    echo required 'unzip' not found, please install unzip
    exit 1
fi

if ! command -v npm &> /dev/null
then
    echo required 'npm' not found, please install node
    exit 1
fi

if ! command -v docker &> /dev/null
then
    echo required 'docker' not found, please install docker
    exit 1
fi

if ! command -v curl &> /dev/null
then
    echo required 'curl' not found, please install curl
fi

mkdir -p intermediate
mkdir -p output

function download_data() {
    if [[ ! -f intermediate/cbswijkenbuurt.zip ]]
    then
        curl -o intermediate/cbswijkenbuurt.zip "https://www.cbs.nl/-/media/cbs/dossiers/nederland-regionaal/wijk-en-buurtstatistieken/wijkbuurtkaart_2021_v1.zip"
    fi
}

function start_docker() {
    if [ ! "$(docker ps -q -f name=pgtools)" ]; then
        echo "starting pgtools"
        if [ "$(docker ps -aq -f status=exited -f name=pgtools)" ]; then
            docker rm pgtools
        fi
        docker run -d --rm --name pgtools -v $(pwd):/var/local kartoza/postgis:pr-356-14-3.2
    fi
}

function get_geopackage() {
    if [ ! -f intermediate/cbswijkenbuurt.gpkg ]; then
        download_data
        echo "unzipping cbswijkenbuurt.gpkg from cbswijkenbuurt.zip"
        unzip -p intermediate/cbswijkenbuurt.zip WijkBuurtkaart_2021_v1/WijkBuurtkaart_2021_v1.gpkg > intermediate/cbswijkenbuurt.gpkg
    fi
}

function get_cbs_buurten_json() {
    if [ ! -f intermediate/cbs_buurten_2021.geo.json ]; then
        get_geopackage
        echo "extracting layer cbs_buurten_2021.geo.json..."
        start_docker
        docker exec -ti pgtools ogr2ogr -f "geojson" /var/local/intermediate/cbs_buurten_2021.geo.json -t_srs EPSG:4326 /var/local/intermediate/cbswijkenbuurt.gpkg cbs_buurten_2021
    fi
}

function get_node_modules() {
    if [ ! -f node_modules/mapshaper/bin/mapshaper.js ]; then
        npm install --quiet --no-progress &> /dev/null
    fi
}

if [ ! -f output/cbs_buurten_2021_simplified.geo.json ]; then
    get_cbs_buurten_json
    get_node_modules
    echo "simplify buurten"
    npx mapshaper -i intermediate/cbs_buurten_2021.geo.json \
        -filter-slivers min-area=2000m2 \
        -clean gap-fill-area=2000m2 \
        -simplify 18% \
        -clean \
        -each "omgevingsadressendichtheid=null" where="omgevingsadressendichtheid===-99999999" \
        -each "stedelijkheid_adressen_per_km2=null" where="stedelijkheid_adressen_per_km2===-99999999" \
        -each "bevolkingsdichtheid_inwoners_per_km2=null" where="bevolkingsdichtheid_inwoners_per_km2===-99999999" \
        -each "aantal_inwoners=null" where="aantal_inwoners===-99999999" \
        -each "mannen=null" where="mannen===-99999999" \
        -each "vrouwen=null" where="vrouwen===-99999999" \
        -each "percentage_personen_0_tot_15_jaar=null" where="percentage_personen_0_tot_15_jaar===-99999999" \
        -each "percentage_personen_15_tot_25_jaar=null" where="percentage_personen_15_tot_25_jaar===-99999999" \
        -each "percentage_personen_25_tot_45_jaar=null" where="percentage_personen_25_tot_45_jaar===-99999999" \
        -each "percentage_personen_45_tot_65_jaar=null" where="percentage_personen_45_tot_65_jaar===-99999999" \
        -each "percentage_personen_65_jaar_en_ouder=null" where="percentage_personen_65_jaar_en_ouder===-99999999" \
        -each "percentage_ongehuwd=null" where="percentage_ongehuwd===-99999999" \
        -each "percentage_gehuwd=null" where="percentage_gehuwd===-99999999" \
        -each "percentage_gescheid=null" where="percentage_gescheid===-99999999" \
        -each "percentage_verweduwd=null" where="percentage_verweduwd===-99999999" \
        -each "aantal_huishoudens=null" where="aantal_huishoudens===-99999999" \
        -each "percentage_eenpersoonshuishoudens=null" where="percentage_eenpersoonshuishoudens===-99999999" \
        -each "percentage_huishoudens_zonder_kinderen=null" where="percentage_huishoudens_zonder_kinderen===-99999999" \
        -each "percentage_huishoudens_met_kinderen=null" where="percentage_huishoudens_met_kinderen===-99999999" \
        -each "gemiddelde_huishoudsgrootte=null" where="gemiddelde_huishoudsgrootte===-99999999" \
        -each "percentage_westerse_migratieachtergrond=null" where="percentage_westerse_migratieachtergrond===-99999999" \
        -each "percentage_niet_westerse_migratieachtergrond=null" where="percentage_niet_westerse_migratieachtergrond===-99999999" \
        -each "percentage_uit_marokko=null" where="percentage_uit_marokko===-99999999" \
        -each "percentage_uit_nederlandse_antillen_en_aruba=null" where="percentage_uit_nederlandse_antillen_en_aruba===-99999999" \
        -each "percentage_uit_suriname=null" where="percentage_uit_suriname===-99999999" \
        -each "percentage_uit_turkije=null" where="percentage_uit_turkije===-99999999" \
        -each "percentage_overige_nietwestersemigratieachtergrond=null" where="percentage_overige_nietwestersemigratieachtergrond===-99999999" \
        -each "oppervlakte_totaal_in_ha=null" where="oppervlakte_totaal_in_ha===-99999999" \
        -each "oppervlakte_land_in_ha=null" where="oppervlakte_land_in_ha===-99999999" \
        -each "oppervlakte_water_in_ha=null" where="oppervlakte_water_in_ha===-99999999" \
        -o output/cbs_buurten_2021_simplified.geo.json
fi

function get_wijken_json() {
    if [ ! -f intermediate/cbs_wijken_2021.geo.json ]; then
        get_geopackage
        start_docker
        echo "extracting layer cbs_wijken_2021.geo.json..."
        docker exec -ti pgtools ogr2ogr -f "geojson" /var/local/intermediate/cbs_wijken_2021.geo.json -t_srs EPSG:4326 /var/local/intermediate/cbswijkenbuurt.gpkg cbs_wijken_2021
    fi
}

if [ ! -f output/cbs_wijken_2021_simplified.geo.json ]; then
    get_wijken_json
    get_node_modules
    echo "simplify wijken"
    npx mapshaper -i intermediate/cbs_wijken_2021.geo.json \
        -filter-slivers min-area=2000m2 \
        -clean gap-fill-area=2000m2 \
        -simplify 10% \
        -clean \
        -filter-slivers min-area=2000m2 \
        -clean gap-fill-area=2000m2 \
        -each "omgevingsadressendichtheid=null" where="omgevingsadressendichtheid===-99999999" \
        -each "stedelijkheid_adressen_per_km2=null" where="stedelijkheid_adressen_per_km2===-99999999" \
        -each "bevolkingsdichtheid_inwoners_per_km2=null" where="bevolkingsdichtheid_inwoners_per_km2===-99999999" \
        -each "aantal_inwoners=null" where="aantal_inwoners===-99999999" \
        -each "mannen=null" where="mannen===-99999999" \
        -each "vrouwen=null" where="vrouwen===-99999999" \
        -each "percentage_personen_0_tot_15_jaar=null" where="percentage_personen_0_tot_15_jaar===-99999999" \
        -each "percentage_personen_15_tot_25_jaar=null" where="percentage_personen_15_tot_25_jaar===-99999999" \
        -each "percentage_personen_25_tot_45_jaar=null" where="percentage_personen_25_tot_45_jaar===-99999999" \
        -each "percentage_personen_45_tot_65_jaar=null" where="percentage_personen_45_tot_65_jaar===-99999999" \
        -each "percentage_personen_65_jaar_en_ouder=null" where="percentage_personen_65_jaar_en_ouder===-99999999" \
        -each "percentage_ongehuwd=null" where="percentage_ongehuwd===-99999999" \
        -each "percentage_gehuwd=null" where="percentage_gehuwd===-99999999" \
        -each "percentage_gescheid=null" where="percentage_gescheid===-99999999" \
        -each "percentage_verweduwd=null" where="percentage_verweduwd===-99999999" \
        -each "aantal_huishoudens=null" where="aantal_huishoudens===-99999999" \
        -each "percentage_eenpersoonshuishoudens=null" where="percentage_eenpersoonshuishoudens===-99999999" \
        -each "percentage_huishoudens_zonder_kinderen=null" where="percentage_huishoudens_zonder_kinderen===-99999999" \
        -each "percentage_huishoudens_met_kinderen=null" where="percentage_huishoudens_met_kinderen===-99999999" \
        -each "gemiddelde_huishoudsgrootte=null" where="gemiddelde_huishoudsgrootte===-99999999" \
        -each "percentage_westerse_migratieachtergrond=null" where="percentage_westerse_migratieachtergrond===-99999999" \
        -each "percentage_niet_westerse_migratieachtergrond=null" where="percentage_niet_westerse_migratieachtergrond===-99999999" \
        -each "percentage_uit_marokko=null" where="percentage_uit_marokko===-99999999" \
        -each "percentage_uit_nederlandse_antillen_en_aruba=null" where="percentage_uit_nederlandse_antillen_en_aruba===-99999999" \
        -each "percentage_uit_suriname=null" where="percentage_uit_suriname===-99999999" \
        -each "percentage_uit_turkije=null" where="percentage_uit_turkije===-99999999" \
        -each "percentage_overige_nietwestersemigratieachtergrond=null" where="percentage_overige_nietwestersemigratieachtergrond===-99999999" \
        -each "oppervlakte_totaal_in_ha=null" where="oppervlakte_totaal_in_ha===-99999999" \
        -each "oppervlakte_land_in_ha=null" where="oppervlakte_land_in_ha===-99999999" \
        -each "oppervlakte_water_in_ha=null" where="oppervlakte_water_in_ha===-99999999" \
        -o output/cbs_wijken_2021_simplified.geo.json
fi

function get_gemeenten_json()
{
    if [ ! -f intermediate/gemeenten_2021.geo.json ]; then
        get_geopackage
        echo "extracting layer gemeenten_2021.geo.json..."
        start_docker
        docker exec -ti pgtools ogr2ogr -f "geojson" /var/local/intermediate/gemeenten_2021.geo.json -t_srs EPSG:4326 /var/local/intermediate/cbswijkenbuurt.gpkg gemeenten2021
    fi
}


if [ ! -f output/gemeenten_2021_simplified.geo.json ]; then
    get_gemeenten_json
    get_node_modules
    echo "simplify gemeenten"
    npx mapshaper -i intermediate/gemeenten_2021.geo.json \
        -filter-slivers min-area=2000m2 \
        -clean gap-fill-area=2000m2 \
        -simplify 3.5% \
        -clean \
        -filter-slivers min-area=2000m2 \
        -clean gap-fill-area=2000m2 \
        -each "omgevingsadressendichtheid=null" where="omgevingsadressendichtheid===-99999999" \
        -each "stedelijkheid_adressen_per_km2=null" where="stedelijkheid_adressen_per_km2===-99999999" \
        -each "bevolkingsdichtheid_inwoners_per_km2=null" where="bevolkingsdichtheid_inwoners_per_km2===-99999999" \
        -each "aantal_inwoners=null" where="aantal_inwoners===-99999999" \
        -each "mannen=null" where="mannen===-99999999" \
        -each "vrouwen=null" where="vrouwen===-99999999" \
        -each "percentage_personen_0_tot_15_jaar=null" where="percentage_personen_0_tot_15_jaar===-99999999" \
        -each "percentage_personen_15_tot_25_jaar=null" where="percentage_personen_15_tot_25_jaar===-99999999" \
        -each "percentage_personen_25_tot_45_jaar=null" where="percentage_personen_25_tot_45_jaar===-99999999" \
        -each "percentage_personen_45_tot_65_jaar=null" where="percentage_personen_45_tot_65_jaar===-99999999" \
        -each "percentage_personen_65_jaar_en_ouder=null" where="percentage_personen_65_jaar_en_ouder===-99999999" \
        -each "percentage_ongehuwd=null" where="percentage_ongehuwd===-99999999" \
        -each "percentage_gehuwd=null" where="percentage_gehuwd===-99999999" \
        -each "percentage_gescheid=null" where="percentage_gescheid===-99999999" \
        -each "percentage_verweduwd=null" where="percentage_verweduwd===-99999999" \
        -each "aantal_huishoudens=null" where="aantal_huishoudens===-99999999" \
        -each "percentage_eenpersoonshuishoudens=null" where="percentage_eenpersoonshuishoudens===-99999999" \
        -each "percentage_huishoudens_zonder_kinderen=null" where="percentage_huishoudens_zonder_kinderen===-99999999" \
        -each "percentage_huishoudens_met_kinderen=null" where="percentage_huishoudens_met_kinderen===-99999999" \
        -each "gemiddelde_huishoudsgrootte=null" where="gemiddelde_huishoudsgrootte===-99999999" \
        -each "percentage_westerse_migratieachtergrond=null" where="percentage_westerse_migratieachtergrond===-99999999" \
        -each "percentage_niet_westerse_migratieachtergrond=null" where="percentage_niet_westerse_migratieachtergrond===-99999999" \
        -each "percentage_uit_marokko=null" where="percentage_uit_marokko===-99999999" \
        -each "percentage_uit_nederlandse_antillen_en_aruba=null" where="percentage_uit_nederlandse_antillen_en_aruba===-99999999" \
        -each "percentage_uit_suriname=null" where="percentage_uit_suriname===-99999999" \
        -each "percentage_uit_turkije=null" where="percentage_uit_turkije===-99999999" \
        -each "percentage_overige_nietwestersemigratieachtergrond=null" where="percentage_overige_nietwestersemigratieachtergrond===-99999999" \
        -each "oppervlakte_totaal_in_ha=null" where="oppervlakte_totaal_in_ha===-99999999" \
        -each "oppervlakte_land_in_ha=null" where="oppervlakte_land_in_ha===-99999999" \
        -each "oppervlakte_water_in_ha=null" where="oppervlakte_water_in_ha===-99999999" \
        -o output/gemeenten_2021_simplified.geo.json
fi

if [ ! -f intermediate/gemeentenprov.geo.json ]; then
    get_node_modules
    npx mapshaper output/gemeenten_2021_simplified.geo.json -join gemeenten-alfabetisch-2021.csv keys=gemeentecode,GemeentecodeGM string-fields=GemeentecodeGM -o intermediate/gemeentenprov.geo.json
fi

if [ ! -f output/provincies_2021.geo.json ]; then
    npx mapshaper -i intermediate/gemeentenprov.geo.json\
        -dissolve multipart water,Provinciecode,Provincienaam \
        calc='omgevingsadressendichtheid=Math.round(sum(omgevingsadressendichtheid * oppervlakte_land_in_ha)/sum(oppervlakte_land_in_ha)),bevolkingsdichtheid_inwoners_per_km2=Math.round(sum(bevolkingsdichtheid_inwoners_per_km2*oppervlakte_land_in_ha)/sum(oppervlakte_land_in_ha)),aantal_inwoners=sum(aantal_inwoners),mannen=sum(mannen),vrouwen=sum(vrouwen),percentage_personen_0_tot_15_jaar=Math.round(sum(percentage_personen_0_tot_15_jaar*aantal_inwoners)/sum(aantal_inwoners)),percentage_personen_15_tot_25_jaar=Math.round(sum(percentage_personen_15_tot_25_jaar*aantal_inwoners)/sum(aantal_inwoners)),percentage_personen_25_tot_45_jaar=Math.round(sum(percentage_personen_25_tot_45_jaar*aantal_inwoners)/sum(aantal_inwoners)),percentage_personen_45_tot_65_jaar=Math.round(sum(percentage_personen_45_tot_65_jaar*aantal_inwoners)/sum(aantal_inwoners)),percentage_personen_65_jaar_en_ouder=Math.round(sum(percentage_personen_65_jaar_en_ouder*aantal_inwoners)/sum(aantal_inwoners)),percentage_ongehuwd=Math.round(sum(percentage_ongehuwd*aantal_inwoners)/sum(aantal_inwoners)),percentage_gehuwd=Math.round(sum(percentage_gehuwd*aantal_inwoners)/sum(aantal_inwoners)),percentage_gescheid=Math.round(sum(percentage_gescheid*aantal_inwoners)/sum(aantal_inwoners)),percentage_verweduwd=Math.round(sum(percentage_verweduwd*aantal_inwoners)/sum(aantal_inwoners)),aantal_huishoudens=sum(aantal_huishoudens),percentage_eenpersoonshuishoudens=Math.round(sum(percentage_eenpersoonshuishoudens*aantal_huishoudens)/sum(aantal_huishoudens)),percentage_huishoudens_zonder_kinderen=Math.round(sum(percentage_huishoudens_zonder_kinderen*aantal_huishoudens)/sum(aantal_huishoudens)),percentage_huishoudens_met_kinderen=Math.round(sum(percentage_huishoudens_met_kinderen*aantal_huishoudens)/sum(aantal_huishoudens)),gemiddelde_huishoudsgrootte=Math.round(sum(gemiddelde_huishoudsgrootte*aantal_huishoudens)/sum(aantal_huishoudens)),percentage_westerse_migratieachtergrond=Math.round(sum(percentage_westerse_migratieachtergrond*aantal_inwoners)/sum(aantal_inwoners)),percentage_niet_westerse_migratieachtergrond=Math.round(sum(percentage_niet_westerse_migratieachtergrond*aantal_inwoners)/sum(aantal_inwoners)),percentage_uit_marokko=Math.round(sum(percentage_uit_marokko*aantal_inwoners)/sum(aantal_inwoners)),percentage_uit_nederlandse_antillen_en_aruba=Math.round(10*sum(percentage_uit_nederlandse_antillen_en_aruba*aantal_inwoners)/sum(aantal_inwoners))/10,percentage_uit_suriname=Math.round(sum(percentage_uit_suriname*aantal_inwoners)/sum(aantal_inwoners)),percentage_uit_turkije=Math.round(sum(percentage_uit_turkije*aantal_inwoners)/sum(aantal_inwoners)),percentage_overige_nietwestersemigratieachtergrond=Math.round(sum(percentage_overige_nietwestersemigratieachtergrond*aantal_inwoners)/sum(aantal_inwoners)),oppervlakte_totaal_in_ha=sum(oppervlakte_totaal_in_ha),oppervlakte_land_in_ha=sum(oppervlakte_land_in_ha),oppervlakte_water_in_ha=sum(oppervlakte_water_in_ha),jaarstatcode="2021PV"+Provinciecode,jaar=first(jaar)'\
        -clean\
        -o output/provincies_2021.geo.json
fi

if [ "$(docker ps -q -f name=pgtools)" ]; then
    docker stop pgtools
fi


echo "the resulting files should now be available in directory 'output'"