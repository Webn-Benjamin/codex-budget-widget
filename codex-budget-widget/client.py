"""Read-only JSON-RPC client for the installed Codex app-server."""
import json
import os
from pathlib import Path
import queue
import subprocess
import threading
import time
import platform
from wsl_client import find_wsl


class ClientError(RuntimeError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def npm_binary(prefix):
    """Resolve npm's native binary without executing cmd/PowerShell shims."""
    arch = 'aarch64' if platform.machine().lower() in ('arm64', 'aarch64') else 'x86_64'
    suffix = Path('vendor') / (arch + '-pc-windows-msvc') / 'codex' / 'codex.exe'
    package = prefix / 'node_modules' / '@openai' / 'codex'
    candidates = [package / suffix,
                  prefix / 'node_modules' / '@openai' / ('codex-win32-' + ('arm64' if arch == 'aarch64' else 'x64')) / suffix,
                  package / 'node_modules' / '@openai' / ('codex-win32-' + ('arm64' if arch == 'aarch64' else 'x64')) / suffix]
    candidates = [variant for p in candidates for variant in (p.parent.parent / 'bin' / 'codex.exe', p)]
    return next((str(p) for p in candidates if p.is_file()), None)


def find_codex():
    # Follow PATH order, including npm prefixes with only codex.cmd/codex.ps1.
    for directory in os.get_exec_path():
        if not directory:
            continue
        prefix = Path(directory)
        if (prefix / 'codex.exe').is_file():
            return str(prefix / 'codex.exe')
        found = npm_binary(prefix)
        if found:
            return found
    if os.environ.get('APPDATA'):
        found = npm_binary(Path(os.environ['APPDATA']) / 'npm')
        if found:
            return found
    base = Path(os.environ.get('LOCALAPPDATA', '')) / 'OpenAI' / 'Codex' / 'bin'
    candidates = list(base.glob('*/codex.exe'))
    if not candidates:
        raise ClientError('codex_missing')
    return str(max(candidates, key=lambda p: p.stat().st_mtime))


class Client:
    def __init__(self):
        try:
            command, self.source = [find_codex(), 'app-server', '--stdio'], 'Windows'
        except ClientError:
            found = find_wsl()
            if found is None:
                raise ClientError('codex_missing') from None
            command, self.source = found
        self.proc = subprocess.Popen(command,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, encoding='utf-8', creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        self.messages = queue.Queue()
        self.counter = 0
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()
        try:
            self.call('initialize', {'clientInfo': {'name': 'codex_budget_widget',
                'title': 'Budget Codex', 'version': '1.2.0'}})
            self._write({'method': 'initialized'})
        except Exception:
            self.close()
            raise

    def _read(self):
        for line in self.proc.stdout:
            try:
                message = json.loads(line)
                if isinstance(message, dict):
                    self.messages.put(message)
            except ValueError:
                continue
        self.messages.put(None)

    def _write(self, message):
        self.proc.stdin.write(json.dumps(message) + '\n')
        self.proc.stdin.flush()

    def call(self, method, params=None):
        if method not in ('initialize', 'account/read', 'account/rateLimits/read'):
            raise ValueError('Méthode non autorisée par ce client en lecture seule.')
        self.counter += 1
        request = {'id': self.counter, 'method': method}
        if params is not None:
            request['params'] = params
        self._write(request)
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                message = self.messages.get(timeout=max(0.01, deadline - time.monotonic()))
            except queue.Empty:
                break
            if message is None:
                raise RuntimeError('Connexion Codex interrompue.')
            if message.get('id') == self.counter:
                if 'error' in message:
                    # Do not persist arbitrary server errors that might contain personal data.
                    raise ClientError('read_failed')
                return message['result']
        raise TimeoutError('Codex ne répond pas. Nouvelle tentative dans une minute.')

    def read_limits(self):
        account = self.call('account/read', {'refreshToken': False}).get('account')
        if account is None:
            raise ClientError('wsl_login_required' if getattr(self, 'source', '').startswith('WSL / ') else 'login_required')
        if account.get('type') == 'apiKey':
            raise ClientError('api_key')
        return self.call('account/rateLimits/read')

    def close(self):
        # EOF lets app-server exit inside WSL without terminating a distribution.
        try:
            self.proc.stdin.close()
        except OSError:
            pass
        if self.proc.poll() is None:
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.terminate()
                self.proc.kill()
                self.proc.wait(timeout=5)
        self.reader.join(timeout=1)
        if not self.reader.is_alive():
            self.proc.stdout.close()
