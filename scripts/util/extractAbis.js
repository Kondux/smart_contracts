const fs = require('fs');
const path = require('path');

const contracts = [
  { name: 'KonduxBeaconFactory', path: 'out/KonduxBeaconFactory.sol/KonduxBeaconFactory.json' },
  { name: 'KonduxImplementation', path: 'out/KonduxImplementation.sol/KonduxImplementation.json' },
  { name: 'KonduxRoyaltySplitter', path: 'out/KonduxRoyaltySplitter.sol/KonduxRoyaltySplitter.json' },
  { name: 'UpgradeableBeacon', path: 'out/UpgradeableBeacon.sol/UpgradeableBeacon.json' },
  { name: 'BeaconProxy', path: 'out/BeaconProxy.sol/BeaconProxy.json' },
];

const outDir = path.join(__dirname, '..', 'abis');

// Create output directory if it doesn't exist
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

for (const contract of contracts) {
  const fullPath = path.join(__dirname, '..', contract.path);

  if (!fs.existsSync(fullPath)) {
    console.log(`Warning: ${contract.name} not found at ${fullPath}`);
    continue;
  }

  const artifact = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
  const abi = artifact.abi;

  const outPath = path.join(outDir, `${contract.name}.json`);
  fs.writeFileSync(outPath, JSON.stringify(abi, null, 2));
  console.log(`Extracted: ${contract.name}.json`);
}

console.log(`\nABIs exported to: ${outDir}`);
