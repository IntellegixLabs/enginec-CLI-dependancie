import { createConnection, TextDocuments, Diagnostic, DiagnosticSeverity, ProposedFeatures, InitializeParams, DidChangeConfigurationNotification, CompletionItem, CompletionItemKind, TextDocumentPositionParams, Location, TextDocumentSyncKind } from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { execFile } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import * as os from 'os';
import { filterIncludeFalsePositives } from './includeDiagnostics';

const connection = createConnection(ProposedFeatures.all);
const documents: TextDocuments<TextDocument> = new TextDocuments(TextDocument);

let hasConfigurationCapability = false;

connection.onInitialize((params: InitializeParams) => {
  const capabilities = params.capabilities;
  hasConfigurationCapability = !!(
    capabilities.workspace && !!capabilities.workspace.configuration
  );
  return {
    capabilities: {
    textDocumentSync: TextDocumentSyncKind.Incremental,
      completionProvider: {
        resolveProvider: false
      },
      definitionProvider: true
    }
  };
});

// Simple regex-based symbol index for go-to-definition and basic completions
function indexSymbols(text: string) {
  const symbols: { name: string; line: number; col: number }[] = [];
  const lines = text.split(/\r?\n/);
  const patterns: RegExp[] = [
    /^\s*(?:function|def)\s+(\w+)/i,
    /^\s*class\s+(\w+)/i,
    /^\s*public\s+(\w+)\s+(\w+)/i, // e.g. public Arena bootstrap[]
    /^\s*object\s+(\w+)/i,
    /^\s*enum\s+(\w+)/i,
    /^\s*(?:const|var)\s+(\w+)/i
  ];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    for (const p of patterns) {
      const m = p.exec(line);
      if (m) {
        // If public pattern matched, prefer namespace.name format
        if (p === patterns[2] && m[1] && m[2]) {
          const combined = `${m[1]}.${m[2]}`;
          symbols.push({ name: combined, line: i, col: line.indexOf(m[2]) });
        } else {
          const name = m[1];
          symbols.push({ name, line: i, col: line.indexOf(name) });
        }
        break;
      }
    }
  }
  return symbols;
}

function resolveEnginecExecutable(): string | undefined {
  const configured = process.env.ENGINEC_BIN || process.env.ENGINEC_PATH;
  if (configured && fs.existsSync(configured)) {
    return configured;
  }

  const homeDir = os.homedir();
  const candidates = [
    configured,
    path.join(homeDir, '.local', 'bin', process.platform === 'win32' ? 'enginec.exe' : 'enginec'),
    '/Users/heylinchoi/.local/bin/enginec',
    '/opt/homebrew/bin/enginec',
    '/usr/local/bin/enginec',
    '/usr/bin/enginec',
    'enginec'
  ].filter((candidate): candidate is string => !!candidate);

  for (const candidate of candidates) {
    if (!candidate) continue;
    if (candidate === 'enginec') {
      return candidate;
    }
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return undefined;
}

function getEnginecPathEnv(): string {
  const extras = [
    process.env.ENGINEC_BIN ? path.dirname(process.env.ENGINEC_BIN) : '',
    path.join(os.homedir(), '.local', 'bin'),
    '/opt/homebrew/bin',
    '/usr/local/bin',
    '/usr/bin',
    process.env.PATH || ''
  ].filter(Boolean);

  return [...new Set(extras)].join(path.delimiter);
}

function sanitizeDiagnosticRange(docText: string, lineNumber: number, character: number, length = 1) {
  const lines = docText.split(/\r?\n/);
  const targetLine = lines[Math.max(0, lineNumber)] ?? '';
  const visibleIndex = targetLine.search(/\S/);
  const safeLine = Math.max(0, lineNumber);
  const baseChar = character === 0 && visibleIndex > -1 ? visibleIndex : Math.max(0, character);

  return {
    start: { line: safeLine, character: baseChar },
    end: { line: safeLine, character: baseChar + Math.max(1, length) }
  };
}

// Run enginec comp on the given file and parse output into diagnostics
function compileAndParseDiagnostics(filePath: string, docText: string): Promise<Diagnostic[]> {
  return new Promise((resolve) => {
    const enginecExecutable = resolveEnginecExecutable();
    const env = { ...process.env, PATH: getEnginecPathEnv() };

    if (!enginecExecutable) {
      resolve([{
        severity: DiagnosticSeverity.Error,
        range: {
          start: { line: 0, character: 0 },
          end: { line: 0, character: 1 }
        },
        message: 'EngineC CLI not found: install the `enginec` command, add it to your PATH, or set the `ENGINEC_BIN` environment variable before using this extension.',
        source: 'enginec'
      }]);
      return;
    }

    execFile(enginecExecutable, ['comp', filePath], { cwd: path.dirname(filePath), env, timeout: 15000 }, (err, stdout, stderr) => {
      let output = `${stdout || ''}\n${stderr || ''}`.trim();
      output = filterIncludeFalsePositives(filePath, output);
      const diags: Diagnostic[] = [];

      if (!output) {
        resolve([]);
        return;
      }

      if (err && (err as NodeJS.ErrnoException).code === 'ENOENT') {
        diags.push({
          severity: DiagnosticSeverity.Error,
          range: {
            start: { line: 0, character: 0 },
            end: { line: 0, character: 1 }
          },
          message: 'EngineC CLI not found: install the `enginec` command, add it to your PATH, or set the `ENGINEC_BIN` environment variable before using this extension.',
          source: 'enginec'
        });
        resolve(diags);
        return;
      }

      if (!output) {
        // No output — return empty diagnostics
        resolve(diags);
        return;
      }

      const lines = output.split(/\r?\n/);
      // Try to match patterns like: file:line:col: error: message
      const patternFull = /^(.*):(\d+):(\d+):\s*(error|warning):\s*(.*)$/i;
      // Match module-or-file:line: message (e.g. ReplicatedStorage.EngineC.Compiler:76: EngineC ...)
      const patternModuleLine = /^(.*):(\d+):\s*(.*)$/i;
      // Match 'line N: message'
      const patternLineOnly = /line\s+(\d+):\s*(.*)$/i;

      for (const line of lines) {
        let m = patternFull.exec(line);
        if (m) {
          const lineNum = parseInt(m[2], 10) - 1;
          const colNum = parseInt(m[3], 10) - 1;
          diags.push({
            severity: m[4].toLowerCase() === 'error' ? DiagnosticSeverity.Error : DiagnosticSeverity.Warning,
            range: sanitizeDiagnosticRange(docText, lineNum, colNum, 1),
            message: m[5],
            source: 'enginec'
          });
          continue;
        }

        m = patternModuleLine.exec(line);
        if (m) {
          // module:line: message — use the line number and attach to that line in the file if possible
          const lineNum = parseInt(m[2], 10) - 1;
          diags.push({
            severity: /error/i.test(m[3]) ? DiagnosticSeverity.Error : DiagnosticSeverity.Warning,
            range: sanitizeDiagnosticRange(docText, lineNum, 0, 1),
            message: m[3],
            source: 'enginec'
          });
          continue;
        }

        m = patternLineOnly.exec(line);
        if (m) {
          const lineNum = parseInt(m[1], 10) - 1;
          diags.push({
            severity: DiagnosticSeverity.Error,
            range: sanitizeDiagnosticRange(docText, lineNum, 0, 1),
            message: m[2],
            source: 'enginec'
          });
          continue;
        }

        // fallback: any line containing "error" mark whole doc
        if (/error/i.test(line)) {
          diags.push({
            severity: DiagnosticSeverity.Error,
            range: sanitizeDiagnosticRange(docText, 0, 0, 1),
            message: line,
            source: 'enginec'
          });
        }
      }

      resolve(diags);
    });
  });
}

// Validate a single document
async function validateTextDocument(textDocument: TextDocument): Promise<void> {
  const filePath = textDocument.uri.startsWith('file://') ? textDocument.uri.slice(7) : textDocument.uri;
  try {
    const diags = await compileAndParseDiagnostics(filePath, textDocument.getText());
    connection.sendDiagnostics({ uri: textDocument.uri, diagnostics: diags });
  } catch (e) {
    connection.sendDiagnostics({ uri: textDocument.uri, diagnostics: [{
      severity: DiagnosticSeverity.Error,
      range: { start: { line: 0, character: 0 }, end: { line: 0, character: 1 } },
      message: `Failed to run enginec: ${String(e)}`,
      source: 'enginec'
    }]});
  }
}

documents.onDidChangeContent(change => {
  validateTextDocument(change.document);
});

documents.onDidOpen(change => {
  validateTextDocument(change.document);
});

// Basic completion handler using indexed symbols in workspace and current doc
connection.onCompletion((params: TextDocumentPositionParams): CompletionItem[] => {
  const uri = params.textDocument.uri;
  const doc = documents.get(uri);
  const items: CompletionItem[] = [];
  if (doc) {
    const symbols = indexSymbols(doc.getText());
    for (const s of symbols) {
      items.push({ label: s.name, kind: CompletionItemKind.Function });
    }
  }
  // Also scan other open documents
  for (const d of documents.all()) {
    if (d.uri === uri) continue;
    const sy = indexSymbols(d.getText());
    for (const s of sy) items.push({ label: s.name, kind: CompletionItemKind.Function });
  }
  return items;
});

// Basic definition provider: find symbol declaration across open docs
connection.onDefinition((params: TextDocumentPositionParams) => {
  const word = getWordAtPosition(documents.get(params.textDocument.uri), params.position.line, params.position.character);
  if (!word) return null;

  for (const d of documents.all()) {
    const sy = indexSymbols(d.getText());
    for (const s of sy) {
      if (s.name === word) {
        return Location.create(d.uri, {
          start: { line: s.line, character: s.col },
          end: { line: s.line, character: s.col + s.name.length }
        });
      }
    }
  }
  return null;
});

function getWordAtPosition(doc: TextDocument | undefined, line: number, character: number): string | null {
  if (!doc) return null;
  const textLine = doc.getText({ start: { line, character: 0 }, end: { line, character: 10000 } });
  const left = textLine.slice(0, character + 1).match(/[A-Za-z0-9_]+$/);
  const right = textLine.slice(character).match(/^[A-Za-z0-9_]+/);
  if (left || right) return ((left && left[0]) || '') + ((right && right[0]) || '');
  return null;
}

// Make the text document manager listen on the connection
documents.listen(connection);
connection.listen();
