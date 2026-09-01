const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));

const expectedMain = path.resolve(root, pkg.main || './out/src/extension.js');
const expectedServer = path.resolve(root, 'out/server/src/server.js');

const missing = [];

if (!fs.existsSync(expectedMain)) {
  missing.push(`missing extension entry: ${path.relative(root, expectedMain)}`);
}

if (!fs.existsSync(expectedServer)) {
  missing.push(`missing language server entry: ${path.relative(root, expectedServer)}`);
}

if (missing.length) {
  console.error('Smoke test failed:');
  for (const item of missing) {
    console.error(` - ${item}`);
  }
  process.exit(1);
}

console.log('Smoke test passed: compiled extension and language server outputs exist.');
