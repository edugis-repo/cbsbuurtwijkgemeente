// data source inkomen https://www.cbs.nl/nl-nl/maatwerk/2023/35/inkomen-per-gemeente-en-wijk-2020
// data source autobezit https://www.cbs.nl/nl-nl/maatwerk/2024/08/autobezit-per-huishouden-1-januari-2023
// files manually exported from excels to csv: 
//   kvk_2020-wb2023.csv
//   gem-autobezit-huishouden_2023_gem.csv
//   gem-autobezit-huishouden_2023_wijk.csv

import fs from 'fs';
import { exit } from 'process';

const inkomencsvlines = fs.readFileSync('./kvk2020-wb2023.csv', 'utf8').split('\n').map(l => l.replace('\r', ''));
console.log(`inkomen csv file has ${inkomencsvlines.length} lines`);
const autobezitcsvlinesgem = fs.readFileSync('./gem-autobezit-huishouden_2023_gem.csv', 'utf8').split('\n').map(l => l.replace('\r', ''));
console.log(`autobezit csv file gemeente has ${autobezitcsvlinesgem.length} lines`);
const autobezitcsvlineswijk = fs.readFileSync('./gem-autobezit-huishouden_2023_wijk.csv', 'utf8').split('\n').map(l => l.replace('\r', ''));
console.log(`autobezit csv file wijk has ${autobezitcsvlineswijk.length} lines`);

if (inkomencsvlines[13].split(';')[0] !== 'Nederland') {
  console.log('kvk2020-wb2023.csv: line 13 is not Nederland');
  exit(1)
}
if (autobezitcsvlinesgem[2].split(';')[0] !== 'Gemeentenaam') {
  console.log('gem-autobezit-huishouden_2023_gem.csv: line 2 is not Gemeentenaam');
  exit(1)
}
if (autobezitcsvlineswijk[2].split(';')[0].trim() !== 'Wijknaam') {
  console.log('gem-autobezit-huishouden_2023_wijk.csv: line 2 is not Wijknaam');
  exit(1)
}

function convertToInkomenRecord(parts) {
  return {
    "code": parts[0] ? parts[0] : parts[1],
    "naam": parts[2],
    "gemiddeld_inkomen": parseFloat(parts[3].replace(',', '.')),
    "percentage_laaginkomen": parseFloat(parts[4].replace(',', '.')),
    "percentage_hooginkomen": parseFloat(parts[5].replace(',', '.'))
  }
}

function assignFeatureProperties(feature, record) {
  feature.properties.gemiddeld_inkomen_2020 = record.gemiddeld_inkomen;
  feature.properties.percentage_laaginkomen_2020 = record.percentage_laaginkomen;
  feature.properties.percentage_hooginkomen_2020 = record.percentage_hooginkomen;
  if (record.autobezit) {
    feature.properties.autobezit_huishouden = record.autobezit;
  }
}

const nederland = [];
const gemeenten = [];
const wijken = [];

for (let i = 13; i < inkomencsvlines.length; i++) {
  const line = inkomencsvlines[i];
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
    nederland.push(convertToInkomenRecord(parts));
  } else if (parts[0]) {
    gemeenten.push(convertToInkomenRecord(parts));
  } else {
    wijken.push(convertToInkomenRecord(parts));
  }
}

for (let i = 3; i < autobezitcsvlinesgem.length; i++) {
  const line = autobezitcsvlinesgem[i];
  const parts = line.split(';');
  if (parts.length !== 3) {
    console.error('autobezit gemeente line must have 3 parts, but has', parts.length);
    console.error(`line: ${line}`);
    exit(1);
  }
  if (!parts[1]) {
    // last line reached
    break;
  }
  const gemeente = gemeenten.find(g => g.code === parts[1]);
  if (!gemeente) {
    console.error(`gemeente ${parts[0]} ${parts[1]} not found in gemeenten`);
    exit(1);
  }
  const autobezit = parseFloat(parts[2].replace(',', '.'));
  if (!isNaN(autobezit)) {
    gemeente.autobezit = autobezit;
  }
}

for (let i = 3; i < autobezitcsvlineswijk.length; i++) {
  const line = autobezitcsvlineswijk[i];
  const parts = line.split(';');
  if (parts.length !== 6) {
    console.error('autobezit wijk line must have 5 parts, but has', parts.length);
    console.error(`line: ${line}`);
    exit(1);
  }
  if (!parts[1]) {
    // last line reached
    break;
  }
  const wijk = wijken.find(w => w.code === parts[1].trim());
  if (!wijk) {
    console.error(`wijk ${parts[0]} ${parts[1]} ${parts[2]} not found in wijken`);
    exit(1);
  }
  const autobezit = parseFloat(parts[4].replace(',', '.'));
  if (!isNaN(autobezit)) {
    wijk.autobezit = autobezit;
  }
}

//console.log(`nederland: ${nederland.length}`);
//console.log(`gemeenten: ${gemeenten.length}`);
//console.log(`wijken: ${wijken.length}`);

let result = [];

const gemeentefile = "../intermediate/gemeenten_2023.geo.json";
const gemeenteinkomenfile = "../intermediate/gemeenten_2023_extra.geo.json";
if (!fs.existsSync(gemeenteinkomenfile) && fs.existsSync(gemeentefile)) {
  const gemeentenGeojson = JSON.parse(fs.readFileSync(gemeentefile));
  for (const gemeente of gemeenten) {
    const features = gemeentenGeojson.features.filter(f => f.properties.gemeentecode === gemeente.code && f.properties.water !== 'JA');
    if (!features.length) {
      console.error(`gemeente ${gemeente.naam} not found in geojson`);
      exit(1);
    }
    for (const feature of features) {
      assignFeatureProperties(feature, gemeente);
    }
  }
  fs.writeFileSync(gemeenteinkomenfile, JSON.stringify(gemeentenGeojson));
  result.push('gemeenten');
}

const wijkenfile = "../intermediate/cbs_wijken_2023.geo.json";
const wijkenextrafile = "../intermediate/cbs_wijken_2023_extra.geo.json";
if (!fs.existsSync(wijkenextrafile) && fs.existsSync(wijkenfile)) {
  const wijkenGeojson = JSON.parse(fs.readFileSync(wijkenfile));
  for (const wijk of wijken) {
    const features = wijkenGeojson.features.filter(f => f.properties.wijkcode === wijk.code && f.properties.water !== 'JA');
    if (!features.length) {
      console.error(`wijk ${wijk.naam} not found in geojson`);
      exit(1);
    }
    for (const feature of features) {
        assignFeatureProperties(feature, wijk);
    }
  }
  fs.writeFileSync(wijkenextrafile, JSON.stringify(wijkenGeojson));
  result.push('wijken');
}
if (result.length) {
  console.log(`importextra done for ${result.join(', ')}`);
} else {
  console.log(`importextra done, nothing to do (${result.length})`);
}