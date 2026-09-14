"""Poll quota metadata only. No thread, turn, model call, or token access."""
import argparse
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import sqlite3
from contextlib import closing
import sys
import time

from budget import parse, calculate, validate_workdays, DEFAULT_WORKDAYS, short_window, QuotaError
from client import Client, ClientError
from wsl_client import list_wsl
from diagnostics import Journal


def read_source(folder):
    try:
        value = json.loads((folder / 'source.json').read_text(encoding='utf-8-sig')).get('source')
    except FileNotFoundError:
        return 'auto'
    if value in ('auto', 'windows') or (isinstance(value, str) and value.startswith('wsl:') and value[4:].strip()):
        return value
    raise ClientError('invalid_source')


def atomic_json(path, data):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
    os.replace(tmp, path)


def record(folder, row, model="codex"):
    if model not in ("codex", "spark"):
        raise ValueError("Unknown quota model")
    table = "samples" if model == "codex" else "samples_spark"
    if row.get('transient'):
        rows = [row]
    else:
        with closing(sqlite3.connect(folder / 'history.sqlite')) as db, db:
            db.row_factory = sqlite3.Row
            db.execute(f'CREATE TABLE IF NOT EXISTS {table} (account TEXT, at REAL, reset REAL, used REAL)')
            db.execute(f'INSERT INTO {table} VALUES (:account, :at, :reset, :used)', row)
            rows = [dict(r) for r in db.execute(
                f'SELECT * FROM {table} WHERE account=? AND reset=? ORDER BY at', (row['account'], row['reset']))]
    config_path = folder / 'workdays.json'
    config = json.loads(config_path.read_text(encoding='utf-8-sig')) if config_path.exists() else {'workdays': DEFAULT_WORKDAYS}
    result = calculate(rows, validate_workdays(config.get('workdays')), schedule_changes=config.get('changes'))
    result['snapshot_only'] = bool(row.get('transient'))
    return result


def collect(folder, payload, now):
    models = {}
    for model in ('codex', 'spark'):
        try:
            models[model] = dict(ok=True, **record(folder, parse(payload, now, model), model))
        except ValueError as exc:
            models[model] = dict(ok=False, updated=now, parse_code=exc.code if isinstance(exc, QuotaError) else 'planning_invalid')
    try:
        models['spark']['short'] = short_window(payload, now)
    except ValueError:
        models['spark']['short'] = dict(ok=False)
    return dict(models['codex'], models=models)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--data', type=Path, required=True)
    p.add_argument('--parent', type=int)
    p.add_argument('--once', action='store_true')
    args = p.parse_args()
    args.data.mkdir(parents=True, exist_ok=True)
    journal = Journal(args.data)
    status = args.data / 'status.json'
    client, parent = None, None
    selection = 'auto'
    active_selection = None
    available_sources = ['auto', 'windows'] + ['wsl:' + name for name in list_wsl()]
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
                selection = read_source(args.data)
                if client is not None and active_selection != selection:
                    client.close()
                    client = None
                if client is None:
                    journal.add('connecting', selection, 'discovery')
                    client = Client(selection)
                    active_selection = selection
                    journal.add('connected', client.source, 'initialize')
                journal.add('reading', client.source, 'account/rateLimits/read')
                payload = client.read_limits()
                result = collect(args.data, payload, time.time())
                result['source'] = client.source
                result['requested_source'] = selection
                result['available_sources'] = available_sources
                for entry in result['models'].values():
                    entry['source'] = client.source
                atomic_json(status, result)
                for model, entry in result['models'].items():
                    if not entry['ok']:
                        journal.add('unavailable', client.source, 'parse', model + '_weekly_unavailable')
                        journal.add('unavailable', client.source, 'parse', entry['parse_code'])
                    elif entry.get('snapshot_only'):
                        journal.add('snapshot_mode', client.source, 'parse', 'account_identity_missing')
                if not result['models']['spark']['short'].get('ok'):
                    journal.add('unavailable', client.source, 'parse', 'spark_5h_unavailable')
                if result['models']['codex']['ok'] or result['models']['spark']['ok']:
                    journal.add('quotas_ok', client.source, 'refresh')
                delay = 15
            except Exception as exc:
                journal.add('error', client.source if client else selection,
                            exc.stage if isinstance(exc, ClientError) else getattr(client, 'stage', 'refresh'),
                            exc.code if isinstance(exc, ClientError) else 'os_error' if isinstance(exc, OSError) else 'read_failed',
                            getattr(exc, 'rpc_code', None), getattr(exc, 'winerror', None) or getattr(exc, 'errno', None),
                            getattr(exc, 'exit_code', None))
                # Preserve the last successful observation, but mark it unavailable.
                try:
                    previous = json.loads(status.read_text(encoding='utf-8'))
                except (OSError, ValueError):
                    previous = {}
                for entry in previous.get('models', {}).values():
                    entry['ok'] = False
                    entry['source'] = client.source if client else None
                    entry['error_code'] = exc.code if isinstance(exc, ClientError) else 'read_failed'
                    if 'short' in entry:
                        entry['short']['ok'] = False
                previous.update(ok=False, source=client.source if client else None,
                                error_code=exc.code if isinstance(exc, ClientError) else 'read_failed',
                                error=exc.code if isinstance(exc, ClientError) else 'read_failed')
                previous['requested_source'] = selection
                previous['available_sources'] = available_sources
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
            from budget import local_zone
            zone = local_zone()
            now = datetime.now(zone)
            next_day = datetime.combine(now.date() + timedelta(days=1), daytime(), zone).timestamp()
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
