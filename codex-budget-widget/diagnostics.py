"""Bounded support journal. Never store server messages, payloads or credentials."""
import json
import os
import time

VERSION = '1.2.10'
EVENTS = {'connecting', 'connected', 'reading', 'quotas_ok', 'snapshot_mode', 'unavailable', 'error'}
STAGES = {'discovery', 'launch', 'initialize', 'account/read', 'account/rateLimits/read', 'parse', 'refresh', 'settings'}
CODES = {'codex_missing', 'wsl_missing', 'invalid_source', 'login_required', 'wsl_login_required',
         'quota_missing', 'weekly_missing', 'used_invalid', 'reset_invalid', 'reset_expired', 'planning_invalid', 'account_identity_missing',
         'api_key', 'read_failed', 'method_unsupported', 'auth_rejected', 'connection_closed',
         'timeout', 'os_error', 'codex_weekly_unavailable', 'spark_weekly_unavailable', 'spark_5h_unavailable'}


def safe_source(value):
    if not isinstance(value, str):
        return 'unknown'
    return ''.join(c for c in value if c.isprintable())[:100]


class Journal:
    def __init__(self, folder):
        self.path = folder / 'diagnostics.json'
        # Each monitor run starts a fresh session, keeping reports focused on this version.
        self.entries = []

    def add(self, event, source='auto', stage='refresh', code=None, rpc_code=None, system_code=None, exit_code=None):
        entry = dict(at=time.time(), event=event if event in EVENTS else 'error',
                     source=safe_source(source), stage=stage if stage in STAGES else 'refresh')
        if code:
            entry['code'] = code if code in CODES else 'read_failed'
        for name, number in (('rpc_code', rpc_code), ('system_code', system_code), ('exit_code', exit_code)):
            if type(number) is int:
                entry[name] = number
        self.entries = (self.entries + [entry])[-40:]
        try:
            tmp = self.path.with_suffix('.tmp')
            tmp.write_text(json.dumps(dict(version=VERSION, entries=self.entries)), encoding='utf-8')
            os.replace(tmp, self.path)
        except OSError:
            # Diagnostics must never prevent quota retrieval.
            pass
