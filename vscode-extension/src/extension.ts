import * as path from 'path';
import * as fs from 'fs';
import * as os from 'os';
import * as vscode from 'vscode';
import { workspace, ExtensionContext } from 'vscode';
import { LanguageClient, LanguageClientOptions, ServerOptions, TransportKind } from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

function ensureEnginecOnPath(): void {
  const candidates = [
    process.env.ENGINEC_BIN,
    process.env.ENGINEC_PATH,
    path.join(os.homedir(), '.local', 'bin', process.platform === 'win32' ? 'enginec.exe' : 'enginec'),
    '/opt/homebrew/bin/enginec',
    '/usr/local/bin/enginec',
    '/usr/bin/enginec'
  ].filter((candidate): candidate is string => !!candidate && fs.existsSync(candidate));

  const resolved = candidates[0] || '/Users/heylinchoi/.local/bin/enginec';
  if (!fs.existsSync(resolved)) return;

  process.env.ENGINEC_BIN = resolved;
  process.env.ENGINEC_PATH = resolved;
  const binDir = path.dirname(resolved);
  const existingPath = process.env.PATH || '';
  const segments = existingPath.split(path.delimiter).filter(Boolean);
  if (!segments.includes(binDir)) {
    process.env.PATH = [binDir, ...segments].join(path.delimiter);
  }
}

export function activate(context: ExtensionContext) {
  ensureEnginecOnPath();

  const serverModule = context.asAbsolutePath(path.join('out', 'server', 'src', 'server.js'));

  const debugOptions = { execArgv: ['--nolazy', '--inspect=6009'] };

  const serverOptions: ServerOptions = {
    run: { module: serverModule, transport: TransportKind.ipc },
    debug: { module: serverModule, transport: TransportKind.ipc, options: debugOptions }
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'ec' }],
    synchronize: {
      fileEvents: workspace.createFileSystemWatcher('**/*.ec')
    }
  };

  client = new LanguageClient('ecLanguageServer', 'EngineC Language Server', serverOptions, clientOptions);

  client.start();
  context.subscriptions.push({ dispose: () => { if (client) client.stop(); } });
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
