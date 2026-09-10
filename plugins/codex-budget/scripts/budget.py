"""Account quota snapshots; no network, credentials, or third-party services."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import sys
from zoneinfo import ZoneInfo


def unpack(payload):
    if 'content' in payload and 'rateLimitsByLimitId' not in payload:
        for item in payload['content']:
            if item.get('type') == 'text':
                try:
                    candidate = json.loads(item['text'])
                except (ValueError, KeyError):
                    continue
                if isinstance(candidate, dict) and ('rateLimits' in candidate or 'rateLimitsByLimitId' in candidate):
                    return candidate
        raise ValueError('Réponse de limites indisponible.')
    return payload


def snapshot(payload, bucket, now):
    data = unpack(payload)
    if not data.get('accountId'):
        raise ValueError('Identifiant du compte indisponible : historique non modifié.')
    buckets = data.get('rateLimitsByLimitId')
    quota = buckets.get(bucket) if buckets is not None else data.get('rateLimits')
    if not quota or (quota.get('limitId') not in (None, bucket)):
        raise ValueError('Quota demandé indisponible.')
    windows = [quota.get(k) for k in ('primary', 'secondary')]
    window = next((w for w in windows if w and w.get('windowDurationMins') == 10080), None)
    if not window:
        raise ValueError('Fenêtre hebdomadaire indisponible ; aucun zéro supposé.')
    used, reset = window.get('usedPercent'), window.get('resetsAt')
    if not isinstance(used, (int, float)) or not math.isfinite(used) or not 0 <= used <= 100:
        raise ValueError('Pourcentage manquant ou invalide.')
    if not isinstance(reset, (int, float)) or not math.isfinite(reset) or reset <= now:
        raise ValueError('Date de reset manquante ou dépassée ; actualiser les limites.')
    return dict(at=now, account=hashlib.sha256(data['accountId'].encode()).hexdigest()[:24],
                bucket=bucket, used=used, reset=reset)


def report(state, bucket):
    zone = ZoneInfo(state['timezone'])
    all_rows = [s for s in state['snapshots'] if s['bucket'] == bucket]
    if not all_rows:
        raise ValueError('Aucun relevé pour ce quota.')
    last = all_rows[-1]
    rows = [s for s in all_rows if s['account'] == last['account'] and s['reset'] == last['reset']]
    # A downward revision is not negative consumption. Start a fresh baseline.
    revised = False
    for i in range(len(rows) - 1, 0, -1):
        if rows[i]['used'] < rows[i - 1]['used']:
            rows = rows[i:]
            revised = True
            break
    local = lambda t: datetime.fromtimestamp(t, zone)
    today = local(last['at']).date()
    reset = local(last['reset'])
    daily, gaps = {}, 0
    for row in rows:
        daily.setdefault(local(row['at']).date().isoformat(), None)
    for before, after in zip(rows, rows[1:]):
        delta = after['used'] - before['used']
        day = local(after['at']).date().isoformat()
        if local(before['at']).date() == local(after['at']).date():
            daily[day] = (daily[day] or 0) + delta
        else:
            gaps += delta
    used_today = daily.get(today.isoformat())
    remaining = 100 - last['used']
    cap = state['daily_cap']
    # Midnight reset gives no budget to the following civil day.
    last_day = datetime.fromtimestamp(last['reset'] - 0.001, zone).date()
    days = max(1, (last_day - today).days + 1)
    room = None if used_today is None else max(0, cap - used_today)
    suggested = min(cap, remaining / days, room if room is not None else cap)
    return dict(last=last, timestamp=local(last['at']).isoformat(), reset=reset.isoformat(),
                remaining=remaining, today_observed=used_today, daily_cap=cap,
                room_upper_bound=room, suggested=suggested, days=days, daily=daily,
                unallocated=gaps, revised=revised, exceeded=used_today is not None and used_today >= cap)


def render(r):
    n = lambda value: f'{value:.1f}'.replace('.', ',')
    lines = [f"Budget Codex — relevé du {r['timestamp']}",
             f"Quota hebdomadaire : {n(r['last']['used'])} % utilisés · {n(r['remaining'])} % restants",
             f"Prochain reset : {r['reset']}", f"Plafond : {n(r['daily_cap'])} points par jour"]
    if r['today_observed'] is None:
        lines += ["Aujourd'hui : inconnu — premier relevé, point de départ enregistré."]
    else:
        lines += [f"Aujourd'hui : au moins {n(r['today_observed'])} points observés (partiel)",
                  f"Marge au plafond : au plus {n(r['room_upper_bound'])} points"]
    lines += [f"Budget supplémentaire conseillé : {n(r['suggested'])} points, sous réserve des périodes non mesurées",
              f"Répartition sur {r['days']} jours civils, aujourd'hui inclus."]
    if r['exceeded']:
        lines.append('PLAFOND ATTEINT : arrêter pour aujourd’hui si ce plafond doit être respecté.')
    if r['revised']:
        lines.append('Quota révisé à la baisse : nouvelle référence, aucun delta négatif comptabilisé.')
    lines += ['', '| Jour | Consommation observée |', '|---|---|']
    lines += [f"| {day} | {'Point de départ' if value is None else n(value) + ' points (partiel)'} |"
              for day, value in sorted(r['daily'].items())]
    lines += ['', f"Écarts entre jours non attribuables : {n(r['unallocated'])} points.",
              'Valeurs arrondies par Codex. Relevés à la demande ; aucun blocage automatique.']
    return '\n'.join(lines)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input', type=Path)
    p.add_argument('--state', type=Path, default=Path.home() / '.codex-budget' / 'history.json')
    p.add_argument('--bucket', default='codex')
    p.add_argument('--daily-cap', type=float)
    p.add_argument('--timezone')
    p.add_argument('--json', action='store_true')
    args = p.parse_args()
    args.state.parent.mkdir(parents=True, exist_ok=True)
    lock = args.state.with_suffix('.lock')
    fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    try:
        state = json.loads(args.state.read_text(encoding='utf-8')) if args.state.exists() else dict(
            version=1, daily_cap=15, timezone='Europe/Paris', snapshots=[])
        if args.daily_cap is not None:
            if not math.isfinite(args.daily_cap) or not 0 < args.daily_cap <= 100:
                raise ValueError('Plafond attendu entre 0 exclu et 100.')
            state['daily_cap'] = args.daily_cap
        if args.timezone:
            state['timezone'] = args.timezone
        ZoneInfo(state['timezone'])
        if args.input:
            row = snapshot(json.loads(args.input.read_text(encoding='utf-8-sig')), args.bucket,
                           datetime.now(timezone.utc).timestamp())
            if state['snapshots'] and row['at'] < state['snapshots'][-1]['at']:
                raise ValueError('Horloge antérieure au dernier relevé.')
            state['snapshots'].append(row)
        result = report(state, args.bucket)
        tmp = args.state.with_suffix('.tmp')
        tmp.write_text(json.dumps(state, indent=2), encoding='utf-8')
        os.replace(tmp, args.state)
        print(json.dumps(result, ensure_ascii=False, indent=2) if args.json else render(result))
    finally:
        os.close(fd)
        lock.unlink()


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError) as exc:
        sys.exit(f'Budget non actualisé : {exc}')
