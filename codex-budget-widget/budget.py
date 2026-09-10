"""Civil-day allowance with carryover; all numbers are quota percentage points."""
from datetime import datetime, time as daytime, timedelta
import hashlib
import math
from pathlib import Path
import sys
from zoneinfo import ZoneInfo

if not getattr(sys, 'frozen', False):
    sys.path.insert(0, str(Path(__file__).resolve().parent / 'vendor'))
ZONE = ZoneInfo('Europe/Paris')
DEFAULT_WORKDAYS = [0, 1, 2, 3, 4]


def validate_workdays(days):
    if not isinstance(days, list) or not days or any(type(d) is not int or d not in range(7) for d in days):
        raise ValueError('Choisir au moins un jour travaillé, du lundi au dimanche.')
    return sorted(set(days))


def schedule(start, reset, workdays):
    """A selected civil day has a full daily target; the real quota caps spending."""
    allowances = {}
    day = start.date()
    while day <= reset.date():
        begin = datetime.combine(day, daytime(), ZONE).timestamp()
        end = datetime.combine(day + timedelta(days=1), daytime(), ZONE).timestamp()
        overlap = max(0, min(end, reset.timestamp()) - max(begin, start.timestamp()))
        if day.weekday() in workdays and overlap:
            allowances[day] = 100 / len(workdays)
        day += timedelta(days=1)
    if not allowances:
        raise ValueError('Aucun jour travaillé avant le reset.')
    return allowances


def parse(payload, now):
    buckets = payload.get('rateLimitsByLimitId')
    quota = buckets.get('codex') if buckets is not None else payload.get('rateLimits')
    if not quota or quota.get('limitId') not in (None, 'codex'):
        raise ValueError('Quota Codex indisponible.')
    windows = [quota.get(k) for k in ('primary', 'secondary')]
    weekly = next((w for w in windows if w and w.get('windowDurationMins') == 10080), None)
    if not weekly or not payload.get('accountId'):
        raise ValueError('Limite hebdomadaire ou compte indisponible.')
    used, reset = weekly.get('usedPercent'), weekly.get('resetsAt')
    if not isinstance(used, (int, float)) or not math.isfinite(used) or not 0 <= used <= 100:
        raise ValueError('Pourcentage indisponible.')
    if not isinstance(reset, (int, float)) or not math.isfinite(reset) or not now < reset <= now + 604860:
        raise ValueError('Reset expiré ou invalide. En attente des nouvelles limites.')
    return dict(account=hashlib.sha256(payload['accountId'].encode()).hexdigest()[:24],
                at=now, reset=reset, used=used)


def calculate(rows, workdays=None):
    workdays = validate_workdays(DEFAULT_WORKDAYS if workdays is None else workdays)
    current = rows[-1]
    rows = [r for r in rows if r['account'] == current['account'] and r['reset'] == current['reset']]
    revised = False
    for i in range(len(rows) - 1, 0, -1):
        if rows[i]['used'] < rows[i - 1]['used']:
            rows = rows[i:]
            revised = True
            break
    now = datetime.fromtimestamp(current['at'], ZONE)
    reset = datetime.fromtimestamp(current['reset'], ZONE)
    start = datetime.fromtimestamp(current['reset'] - 604800, ZONE)
    prior_days = max(0, (now.date() - start.date()).days)
    allowances = schedule(start, reset, workdays)
    cap = allowances.get(now.date(), 0)
    used = current['used']
    remaining = 100 - used
    def boundary(timestamp):
        before = [r['used'] for r in rows if r['at'] <= timestamp]
        after = [r['used'] for r in rows if r['at'] >= timestamp]
        return (before[-1] if before else 0, after[0] if after else used)

    # Carry over each day's positive remainder; yesterday's overspend is not a debt.
    # Bounds deliberately remain conservative when a gap spans several days.
    opening_low, opening_high = 0, 0
    previous_low, previous_high = 0, 0
    day = start.date()
    while day < now.date():
        next_midnight = datetime.combine(day + timedelta(days=1), daytime(), ZONE).timestamp()
        end_low, end_high = boundary(next_midnight)
        spent_low = max(0, end_low - previous_high)
        spent_high = max(0, end_high - previous_low)
        day_cap = allowances.get(day, 0)
        opening_low = max(0, opening_low + day_cap - spent_high)
        opening_high = max(0, opening_high + day_cap - spent_low)
        previous_low, previous_high = end_low, end_high
        day += timedelta(days=1)
    if revised:
        # A quota revision invalidates all earlier daily deltas, including the first day.
        previous_low, previous_high = boundary(datetime.combine(now.date(), daytime(), ZONE).timestamp())
        opening_low, opening_high = 0, sum(value for d, value in allowances.items() if d < now.date())
    today_low, today_high = used - previous_high, used - previous_low
    bonus_low = min(remaining, max(0, opening_low - max(0, today_high - cap)))
    bonus_high = min(remaining, max(0, opening_high - max(0, today_low - cap)))
    balance_low = min(remaining, max(0, cap - today_high + opening_low))
    balance_high = min(remaining, max(0, cap - today_low + opening_high))
    balance_known = math.isclose(balance_low, balance_high, abs_tol=1e-8)
    available = balance_low if balance_known else None
    days_left = sum(1 for day in allowances if day >= now.date())
    return dict(updated=current['at'], used=used, remaining=100-used, available=available,
                today_low=max(0, today_low), today_high=max(0, today_high),
                bonus_low=bonus_low, bonus_high=bonus_high,
                balance_known=balance_known,
                uncertain=previous_low != previous_high, cap=cap,
                opening_bonus_low=opening_low, opening_bonus_high=opening_high,
                workdays=workdays, standard_cap=100/len(workdays), working_today=cap > 0,
                workdays_left=days_left,
                reset=current['reset'], reset_label=reset.strftime('%d/%m à %H:%M'),
                day=now.strftime('%d/%m'), pace=min(available, remaining/max(1, days_left)) if available is not None and cap > 0 else None,
                cycle_day=prior_days+1, revised=revised)
