// data source https://www.cbs.nl/nl-nl/maatwerk/2023/35/inkomen-per-gemeente-en-wijk-2020
// file exported from excel to csv: kvk_2020-wb2023.csv

import fs from 'fs';
import { exit } from 'process';

const csvlines = fs.readFileSync('./kvk2020-wb2023.csv', 'utf8').split('\n').map(l => l.replace('\r', ''));

console.log(csvlines.length);

if (csvlines[13].split(';')[0] !== 'Nederland') {
  console.log('line 13 is not Nederland');
  exit(1)
}

function convertToRecord(parts) {
  return {
    "code": parts[0] ? parts[0] : parts[1],
    "naam": parts[2],
    "gemiddeld_inkomen": parseFloat(parts[3].replace(',', '.')),
    "percentage_laaginkomen": parseFloat(parts[4].replace(',', '.')),
    "percentage_hooginkomen": parseFloat(parts[5].replace(',', '.')),
  }
}

const nederland = [];
const gemeenten = [];
const wijken = [];

for (let i = 13; i < csvlines.length; i++) {
  const line = csvlines[i];
  const parts = line.split(';');
  if (parts.length !== 6) {
    console.error('line must have 6 parts, but has', parts.length);
    console.error(`line: ${line}`);
    exit(1);
  }
  if (!parts[5]) {
    // last line reached
    break;
  }
  if (i === 13) {
    if (parts[0] !== 'Nederland') {
      console.error('first line is not Nederland');
      console.error(`line: ${line}`);
      exit(1);
    }
    nederland.push(convertToRecord(parts));
  } else if (parts[0]) {
    gemeenten.push(convertToRecord(parts));
  } else {
    wijken.push(convertToRecord(parts));
  }
}

console.log(`nederland: ${nederland.length}`);
console.log(`gemeenten: ${gemeenten.length}`);
console.log(`wijken: ${wijken.length}`);

const gemeentenGeojson = JSON.parse(fs.readFileSync('../intermediate/gemeenten_2023.geo.json'));
for (const gemeente of gemeenten) {
  const features = gemeentenGeojson.features.filter(f => f.properties.gemeentecode === gemeente.code && f.properties.water !== 'JA');
  if (!features.length) {
    console.error(`gemeente ${gemeente.naam} not found in geojson`);
    exit(1);
  }
  for (const feature of features) {
    feature.properties.gemiddeld_inkomen = gemeente.gemiddeld_inkomen;
    feature.properties.percentage_laaginkomen = gemeente.percentage_laaginkomen;
    feature.properties.percentage_hooginkomen = gemeente.percentage_hooginkomen;
  }
}
fs.writeFileSync('../intermediate/gemeenten_2023_inkomen.geo.json', JSON.stringify(gemeentenGeojson));

const wijkenGeojson = JSON.parse(fs.readFileSync('../intermediate/cbs_wijken_2023.geo.json'));
for (const wijk of wijken) {
  const features = wijkenGeojson.features.filter(f => f.properties.wijkcode === wijk.code && f.properties.water !== 'JA');
  if (!features.length) {
    console.error(`wijk ${wijk.naam} not found in geojson`);
    exit(1);
  }
  for (const feature of features) {
      feature.properties.gemiddeld_inkomen = wijk.gemiddeld_inkomen;
      feature.properties.percentage_laaginkomen = wijk.percentage_laaginkomen;
      feature.properties.percentage_hooginkomen = wijk.percentage_hooginkomen;
  }
}
fs.writeFileSync('../intermediate/cbs_wijken_2023_inkomen.geo.json', JSON.stringify(wijkenGeojson));
console.log('done');