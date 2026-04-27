const fs = require('fs');

const filePath = 'C:\\Users\\fikri.eren\\AppData\\Roaming\\Claude\\local-agent-mode-sessions\\3db87182-3f90-47a8-9b2f-2b06c475fcc8\\9ac28963-d4c1-4a35-8039-b4a3f5e60600\\local_5a2eaa36-2a54-44b8-bb75-161ebdb6e5c8\\.claude\\projects\\C--Users-fikri-eren-AppData-Roaming-Claude-local-agent-mode-sessions-3db87182-3f90-47a8-9b2f-2b06c475fcc8-9ac28963-d4c1-4a35-8039-b4a3f5e60600-local-5a2eaa36-2a54-44b8-bb75-161ebdb6e5c8-outputs\\ec725ba1-0509-43ec-9012-4fc89c96fc88\\tool-results\\mcp-sqlserver-sql_query-1776280619660.txt';

console.log('Reading:', filePath);

const rawData = fs.readFileSync(filePath, 'utf8');
console.log('File read, size:', rawData.length);

const data = JSON.parse(rawData);
const rows = (data && data[0] && data[0].rows) ? data[0].rows : [];
console.log('Rows found:', rows.length);

const details = [];
for (const row of rows) {
  const fiiliGiris = row.FiiliGiris || null;
  const fiiliCikis = row.FiiliCikis || null;
  const mazeretKod = row.MazeretKod || null;
  const brutSure = row.BrutSure || null;

  let status;
  if (fiiliGiris !== null) {
    status = 'GELDI';
  } else if (fiiliGiris === null && !mazeretKod) {
    status = 'GELMEDI';
  } else if (mazeretKod) {
    status = 'IZINLI';
  }

  details.push([
    row.Sube,
    row.Bolum,
    row.Personel,
    row.PlanVardiya,
    row.PlanBas,
    row.PlanBit,
    fiiliGiris || '—',
    fiiliCikis || '—',
    brutSure,
    mazeretKod || '',
    status
  ]);
}

details.sort((a, b) => {
  if (a[0] !== b[0]) return a[0].localeCompare(b[0]);
  if (a[1] !== b[1]) return a[1].localeCompare(b[1]);
  return a[2].localeCompare(b[2]);
});

const aggregates = {};
for (const row of rows) {
  const sube = row.Sube;
  if (!aggregates[sube]) {
    aggregates[sube] = { plan: 0, geldi: 0, gelmedi: 0, izinli: 0 };
  }
  aggregates[sube].plan++;

  const mazeretKod = row.MazeretKod || null;
  const fiiliGiris = row.FiiliGiris || null;

  if (fiiliGiris !== null) {
    aggregates[sube].geldi++;
  } else if (fiiliGiris === null && !mazeretKod) {
    aggregates[sube].gelmedi++;
  } else if (mazeretKod) {
    aggregates[sube].izinli++;
  }
}

const branchAggregates = Object.keys(aggregates).sort().map(sube => [
  sube,
  aggregates[sube].plan,
  aggregates[sube].geldi,
  aggregates[sube].gelmedi,
  aggregates[sube].izinli
]);

let output = '// Detail Array\n';
output += 'const detailArray = [\n';
for (let i = 0; i < details.length; i++) {
  output += JSON.stringify(details[i]);
  if (i < details.length - 1) output += ',\n';
  else output += '\n';
}
output += '];\n\n';

output += '// Branch Aggregate Array\n';
output += 'const branchAggregates = [\n';
for (let i = 0; i < branchAggregates.length; i++) {
  output += JSON.stringify(branchAggregates[i]);
  if (i < branchAggregates.length - 1) output += ',\n';
  else output += '\n';
}
output += '];\n';

const outputPath = 'D:\\Dev\\sqlserver-mcp-server\\result.js';
fs.writeFileSync(outputPath, output, 'utf8');
console.log('Written to:', outputPath);
console.log('Details count:', details.length);
console.log('Branches count:', branchAggregates.length);
console.log('\nFirst detail entry:');
console.log(details[0]);
console.log('\nBranch aggregates:');
console.log(branchAggregates);
