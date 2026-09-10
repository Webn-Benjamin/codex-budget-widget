"""Poll quota metadata only. No thread, turn, model call, or token access."""
import argparse
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import sqlite3
import sys
import time

from budget import parse, calculate, validate_workdays, DEFAULT_WORKDAYS
from client import Client


def atomic_json(path, data):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
    os.replace(tmp, path)


def record(folder, row):
    with sqlite3.connect(folder / 'history.sqlite') as db:
        db.row_factory = sqlite3.Row
        db.execute('CREATE TABLE IF NOT EXISTS samples (account TEXT, at REAL, reset REAL, used REAL)')
        db.execute('INSERT INTO samples VALUES (:account, :at, :reset, :used)', row)
        rows = [dict(r) for r in db.execute(
            'SELECT * FROM samples WHERE account=? AND reset=? ORDER BY at', (row['account'], row['reset']))]
    config_path = folder / 'workdays.json'
    config = json.loads(config_path.read_text(encoding='utf-8-sig')) if config_path.exists() else {'workdays': DEFAULT_WORKDAYS}
    return calculate(rows, validate_workdays(config.get('workdays')))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--data', type=Path, required=True)
    p.add_argument('--parent', type=int)
    p.add_argument('--once', action='store_true')
    args = p.parse_args()
    args.data.mkdir(parents=True, exist_ok=True)
    status = args.data / 'status.json'
    client, parent = None, None
    if args.parent:
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        parent = kernel.OpenProcess(0x00100000, False, args.parent)
        if not parent:
            return
    try:
        while True:
            if parent and kernel.WaitForSingleObject(parent, 0) == 0:
                break
            try:
                if client is None:
                    client = Client()
                payload = client.call('account/rateLimits/read')
                result = record(args.data, parse(payload, time.time()))
                atomic_json(status, dict(ok=True, **result))
                delay = 60
            except Exception as exc:
                # Preserve the last successful observation, but mark it unavailable.
                try:
                    previous = json.loads(status.read_text(encoding='utf-8'))
                except (OSError, ValueError):
                    previous = {}
                previous.update(ok=False, error=str(exc) if isinstance(exc, (ValueError, RuntimeError, TimeoutError))
                                else 'Actualisation impossible. Nouvelle tentative dans une minute.')
                atomic_json(status, previous)
                if client:
                    client.close()
                    client = None
                delay = 60
            if args.once:
                if sys.stdout is not None:
                    print(status.read_text(encoding='utf-8'))
                return
            # Wake at midnight to delimit the next day's observations as closely as possible.
            from datetime import datetime, timedelta, time as daytime
            from budget import ZONE
            now = datetime.now(ZONE)
            next_day = datetime.combine(now.date() + timedelta(days=1), daytime(), ZONE).timestamp()
            deadline = time.monotonic() + min(delay, max(1, next_day - time.time()))
            while time.monotonic() < deadline:
                if parent and kernel.WaitForSingleObject(parent, 0) == 0:
                    return
                if (args.data / 'refresh').exists():
                    (args.data / 'refresh').unlink(missing_ok=True)
                    break
                time.sleep(1)
    finally:
        if client:
            client.close()
        if parent:
            kernel.CloseHandle(parent)


if __name__ == '__main__':
    main()
