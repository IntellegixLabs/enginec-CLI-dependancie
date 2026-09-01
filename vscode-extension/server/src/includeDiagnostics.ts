import * as fs from 'fs';
import * as path from 'path';

export function extractIncludeName(line: string): string | null {
  const match = line.match(/(?:#include|include)\s+([A-Za-z_][A-Za-z0-9_\.]*)/i);
  return match ? match[1] : null;
}

function findProjectRoot(startDir: string): string {
  let current = startDir;
  while (current !== path.dirname(current)) {
    if (fs.existsSync(path.join(current, '.vscode')) || 
        fs.existsSync(path.join(current, 'package.json')) ||
        fs.existsSync(path.join(current, 'ReplicatedStorage')) ||
        fs.existsSync(path.join(current, '.code-workspace'))) {
      return current;
    }
    current = path.dirname(current);
  }
  return startDir;
}

export function resolveIncludeTarget(filePath: string, includeName: string): string | undefined {
  const dir = path.dirname(filePath);
  const projectRoot = findProjectRoot(dir);
  
  const candidates = [
    path.resolve(dir, includeName),
    path.resolve(dir, `${includeName}.ec`),
    path.resolve(dir, `${includeName}.lua`),
    path.resolve(dir, `${includeName}.luau`),
    path.resolve(dir, 'dependencies', includeName),
    path.resolve(dir, 'dependencies', `${includeName}.ec`),
    path.resolve(dir, 'deps', includeName),
    path.resolve(dir, 'deps', `${includeName}.ec`),
    path.resolve(dir, 'includes', includeName),
    path.resolve(dir, 'includes', `${includeName}.ec`),
    path.resolve(dir, 'modules', includeName),
    path.resolve(dir, 'modules', `${includeName}.ec`),
    path.resolve(dir, includeName, 'index.ec'),
    path.resolve(dir, includeName, 'main.ec'),
    path.resolve(projectRoot, includeName),
    path.resolve(projectRoot, `${includeName}.ec`),
    path.resolve(projectRoot, 'ReplicatedStorage', 'EngineC'),
    path.resolve(projectRoot, 'ReplicatedStorage', includeName)
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return undefined;
}

export function filterIncludeFalsePositives(filePath: string, output: string): string {
  const lines = output.split(/\r?\n/);
  const filtered = lines.filter((line) => {
    if (!/unexpected token near .*?(?:#include|include)\b/i.test(line)) {
      return true;
    }

    const includeName = extractIncludeName(line);
    if (!includeName) {
      return true;
    }

    return !resolveIncludeTarget(filePath, includeName);
  });

  return filtered.join('\n').trim();
}
