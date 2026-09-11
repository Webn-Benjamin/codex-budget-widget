"""Discover a Linux Codex installation without copying credentials out of WSL."""
import os
from pathlib import Path
import subprocess
import time


# Fixed shell code: distribution names are separate argv entries, never shell text.
# Login profiles may print text; the probe uses a marker and the RPC reader ignores it.
RESOLVE = r'''
cd "$HOME" || exit 1
candidate=$(command -v codex 2>/dev/null)
case "$candidate" in /mnt/*|*.exe|*.cmd|*.ps1) candidate= ;; /*) ;; *) candidate= ;; esac
if [ ! -x "$candidate" ]; then
    for candidate in "$HOME/.local/bin/codex" "$HOME/.npm-global/bin/codex" "$HOME/.npm/bin/codex" "$HOME/.volta/bin/codex"; do
        [ -x "$candidate" ] && break
    done
fi
if [ ! -x "$candidate" ] && [ -s "$HOME/.nvm/nvm.sh" ]; then
    . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
    candidate=$(command -v codex 2>/dev/null)
fi
[ -x "$candidate" ] || exit 1
case "$candidate" in /mnt/*|*.exe|*.cmd|*.ps1) exit 1 ;; esac
PATH="${candidate%/*}:$PATH"
export PATH
'''
PROBE = RESOLVE + '\nprintf "CODEX_WIDGET_FOUND\\n"\n'
RUN = RESOLVE + '\nexec "$candidate" app-server --stdio\n'


def decode_list(raw):
    text = raw.decode('utf-16') if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else raw.decode(
        'utf-16-le' if b'\x00' in raw else 'utf-8', errors='replace')
    return [line.strip().lstrip('\ufeff') for line in text.splitlines() if line.strip()]


def list_wsl():
    executable = Path(os.environ.get('SystemRoot', r'C:\Windows')) / 'System32' / 'wsl.exe'
    try:
        result = subprocess.run([str(executable), '--list', '--quiet'], stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=5,
                                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        if result.returncode == 0:
            return [name for name in decode_list(result.stdout) if not name.lower().startswith('docker-desktop')]
    except (OSError, subprocess.TimeoutExpired):
        pass
    return []


def find_wsl(distribution=None):
    executable = Path(os.environ.get('SystemRoot', r'C:\Windows')) / 'System32' / 'wsl.exe'
    if not executable.is_file():
        return None
    flags = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
    try:
        result = subprocess.run([str(executable), '--list', '--quiet'], stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                timeout=5, creationflags=flags)
        if result.returncode:
            return None
        names = [name for name in decode_list(result.stdout)
                 if not name.lower().startswith('docker-desktop')]
        if distribution is not None:
            names = [name for name in names if name == distribution]
        deadline = time.monotonic() + 20
        for name in names:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            prefix = [str(executable), '--distribution', name, '--exec', 'sh', '-lc']
            try:
                probe = subprocess.run(prefix + [PROBE], stdin=subprocess.DEVNULL,
                                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                       timeout=min(8, remaining), creationflags=flags)
            except subprocess.TimeoutExpired:
                continue
            if probe.returncode == 0 and b'CODEX_WIDGET_FOUND' in probe.stdout.splitlines():
                return prefix + [RUN], 'WSL / ' + name
    except (OSError, subprocess.TimeoutExpired):
        pass
    return None
