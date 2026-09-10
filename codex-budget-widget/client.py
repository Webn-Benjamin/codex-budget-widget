"""Read-only JSON-RPC client for the installed Codex app-server."""
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import threading
import time


def find_codex():
    found = shutil.which('codex.exe') or shutil.which('codex')
    if found:
        return found
    base = Path(os.environ.get('LOCALAPPDATA', '')) / 'OpenAI' / 'Codex' / 'bin'
    candidates = list(base.glob('*/codex.exe'))
    if not candidates:
        raise RuntimeError('Codex introuvable. Ouvrir ou installer Codex.')
    return str(max(candidates, key=lambda p: p.stat().st_mtime))


class Client:
    def __init__(self):
        self.proc = subprocess.Popen([find_codex(), 'app-server', '--stdio'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, encoding='utf-8', creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        self.messages = queue.Queue()
        self.counter = 0
        threading.Thread(target=self._read, daemon=True).start()
        try:
            self.call('initialize', {'clientInfo': {'name': 'codex_budget_widget',
                'title': 'Budget Codex', 'version': '1.0.0'}})
            self._write({'method': 'initialized'})
        except Exception:
            self.close()
            raise

    def _read(self):
        for line in self.proc.stdout:
            try:
                self.messages.put(json.loads(line))
            except ValueError:
                continue
        self.messages.put(None)

    def _write(self, message):
        self.proc.stdin.write(json.dumps(message) + '\n')
        self.proc.stdin.flush()

    def call(self, method, params=None):
        if method not in ('initialize', 'account/rateLimits/read'):
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
                    raise RuntimeError('Lecture des limites refusée. Vérifier la connexion du compte dans Codex.')
                return message['result']
        raise TimeoutError('Codex ne répond pas. Nouvelle tentative dans une minute.')

    def close(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=5)
        for pipe in (self.proc.stdin, self.proc.stdout):
            pipe.close()
