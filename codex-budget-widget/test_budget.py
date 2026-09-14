import unittest
import random
from datetime import datetime
from budget import calculate as calculate_in_zone, parse, schedule, validate_workdays
from zoneinfo import ZoneInfo
ZONE = ZoneInfo('Europe/Paris')

def calculate(rows, workdays=None):
    return calculate_in_zone(rows, workdays, zone=ZONE)

def ts(day, hour=12):
    return datetime(2026, 9, day, hour, tzinfo=ZONE).timestamp()

RESET = ts(16, 0)

def row(day, used, hour=12, reset=RESET, account='a'):
    return dict(at=ts(day, hour), used=used, reset=reset, account=account)


class BudgetTests(unittest.TestCase):
    def test_five_workdays_give_twenty_and_ten_bonus(self):
        r = calculate([row(9,10,23), row(10,10,0),row(10,10)])
        self.assertEqual((r['bonus_low'],r['bonus_high'],r['available']), (10,10,30))
        self.assertEqual(r['cap'],20)
        self.assertEqual(r['today_high'], 0)

    def test_daily_base_then_bonus_is_spent(self):
        r=calculate([row(9,10,23),row(10,10,0),row(10,37)])
        self.assertEqual((r['available'],r['bonus_low'],r['today_low']), (3,3,27))

    def test_no_usage_day_rolls_over(self):
        r=calculate([row(9,0),row(10,0,0),row(11,0,0),row(11,0)])
        self.assertEqual((r['available'],r['bonus_low']), (60,40))

    def test_missing_history_is_range(self):
        r=calculate([row(10,16)])
        self.assertEqual((r['available'],r['today_low'],r['today_high']), (None,0,16))
        self.assertEqual((r['bonus_low'],r['bonus_high']), (4,20))
        self.assertTrue(r['uncertain'])

    def test_midnight_gap_not_invented(self):
        r=calculate([row(9,8,23),row(10,11,1),row(10,13)])
        self.assertEqual((r['today_low'],r['today_high']), (2,5))
        self.assertEqual((r['bonus_low'],r['bonus_high']), (9,12))

    def test_reset_discards_old_bonus(self):
        r=calculate([row(10,0),row(16,2,9,reset=ts(23,0))])
        self.assertEqual((r['available'],r['bonus_high']), (18,0))

    def test_account_isolation(self):
        r=calculate([row(10,1,0,account='old'),row(10,16)])
        self.assertTrue(r['uncertain'])

    def test_budget_never_exceeds_real_remaining(self):
        r=calculate([row(15,95)])
        if r['available'] is not None:
            self.assertLessEqual(r['available'],5)
        self.assertLessEqual(r['bonus_high'],5)

    def test_overspend_has_no_negative_balance(self):
        r=calculate([row(10,0,0),row(10,50)])
        self.assertEqual(r['available'],0)

    def test_missing_or_expired_not_zero(self):
        with self.assertRaises(ValueError): parse({'accountId':'a','rateLimits':{}}, ts(10))
        payload={'accountId':'a','rateLimits':{'primary':dict(usedPercent=3,windowDurationMins=10080,resetsAt=ts(9))}}
        with self.assertRaises(ValueError): parse(payload,ts(10))

    def test_downward_revision_does_not_create_negative_usage(self):
        r=calculate([row(10,20,0),row(10,5)])
        self.assertTrue(r['revised'])
        self.assertEqual(r['today_low'],0)

    def test_rest_day_spends_bonus_without_earning_more(self):
        r=calculate([row(9,0,0),row(10,20,0),row(11,40,0),row(12,40,0),row(12,45)])
        self.assertFalse(r['working_today'])
        self.assertEqual((r['cap'],r['available'],r['bonus_low']), (0,15,15))

    def test_custom_three_days(self):
        r=calculate([row(9,0)], [0,2,4])
        self.assertAlmostEqual(r['cap'],100/3)

    def test_daily_target_is_not_prorated_by_reset_hour(self):
        allowances=schedule(datetime.fromtimestamp(ts(9,8),ZONE),datetime.fromtimestamp(ts(16,8),ZONE),[0,1,2,3,4])
        self.assertEqual(allowances[datetime(2026,9,9).date()],20)
        self.assertEqual(allowances[datetime(2026,9,16).date()],20)

    def test_empty_schedule_rejected(self):
        with self.assertRaises(ValueError): validate_workdays([])

    def test_change_schedule_recomputes_from_same_history(self):
        rows=[row(9,5),row(10,5,0),row(10,10)]
        self.assertNotEqual(calculate(rows,[0,1,2,3,4])['available'],calculate(rows,list(range(7)))['available'])

    def test_reported_bug_does_not_claim_weekly_usage_is_today(self):
        r=calculate([row(10,16),row(10,17,13)],list(range(7)))
        self.assertAlmostEqual(r['cap'],100/7)
        self.assertIsNone(r['available'])
        self.assertFalse(r['balance_known'])
        self.assertIsNone(r['pace'])
        self.assertEqual(r['today_low'],1)

    def test_yesterday_overspend_reduces_new_daily_budget(self):
        r=calculate([row(9,17,23),row(10,17,0),row(10,19)],list(range(7)))
        self.assertAlmostEqual(r['available'],200/7-19)
        self.assertEqual(r['bonus_high'],0)

    def test_today_consumption_and_known_bonus(self):
        r=calculate([row(9,10,23),row(10,10,0),row(10,12)],list(range(7)))
        self.assertAlmostEqual(r['available'],100/7-2+(100/7-10))

    def test_unused_day_repays_deficit_before_earning_bonus(self):
        r=calculate([row(9,0,0),row(10,30,0),row(11,30,0),row(11,32)])
        self.assertAlmostEqual(r['opening_bonus_low'],10)
        self.assertAlmostEqual(r['available'],28)

    def test_completed_cycle_exhausted_never_creates_extra_quota(self):
        r=calculate([row(15,100)],list(range(7)))
        self.assertEqual(r['available'],0)
        self.assertEqual(r['bonus_high'],0)

    def test_generated_histories_against_daily_ledger(self):
        rng=random.Random(441)
        for _ in range(250):
            workdays=sorted(rng.sample(list(range(7)),rng.randint(1,7)))
            target=100/len(workdays)
            spent_total=0
            bonus=0
            samples=[row(9,0,0)]
            for day in range(9,15):
                cost=rng.randint(0,min(30,100-spent_total))
                cap=target if datetime(2026,9,day).weekday() in workdays else 0
                bonus=bonus+cap-cost
                spent_total+=cost
                samples.append(row(day+1,spent_total,0))
            cost=rng.randint(0,min(25,100-spent_total))
            spent_total+=cost
            samples.append(row(15,spent_total))
            cap=target if datetime(2026,9,15).weekday() in workdays else 0
            expected=min(100-spent_total,max(0,cap+bonus-cost))
            r=calculate(samples,workdays)
            self.assertTrue(r['balance_known'])
            self.assertAlmostEqual(r['available'],expected)
            self.assertLessEqual(r['bonus_high'],100-spent_total)
            sparse=[samples[0]]+[r for r in samples[1:-1] if rng.random()>.5]+[samples[-1]]
            r=calculate(sparse,workdays)
            if r['balance_known']:
                self.assertAlmostEqual(r['available'],expected)
            expected_bonus=min(100-spent_total,max(0,bonus-max(0,cost-cap)))
            self.assertLessEqual(r['bonus_low'],expected_bonus+1e-8)
            self.assertGreaterEqual(r['bonus_high']+1e-8,expected_bonus)

    def test_deficit_reduces_today_and_persists_over_rest_days(self):
        r=calculate([row(9,0,0),row(10,30,0),row(10,32)])
        self.assertEqual((r['available'],r['carry_low'],r['carry_high']), (8,-10,-10))
        r=calculate([row(9,0,0),row(10,90,0),row(11,90,0),row(12,90,0),row(13,90,0),row(14,90,0)])
        self.assertEqual((r['opening_bonus_low'],r['available']),(-30,0))

    def test_reset_discards_old_deficit(self):
        r=calculate([row(10,90),row(16,2,9,reset=ts(23,0))])
        self.assertEqual((r['available'],r['carry_low'],r['carry_high']), (18,0,0))

    def test_deficit_and_tomorrow_follow_every_observation(self):
        for spent, debt, forecast in [(42,-2,18),(45,-5,15),(65,-25,0)]:
            r=calculate([row(9,0,0),row(10,30,0),row(10,spent)])
            self.assertEqual((r['carry_low'],r['carry_high'],r['tomorrow_available']), (debt,debt,forecast))
        # With no midnight history the same global usage gives the same forecast.
        self.assertEqual(calculate([row(10,45)])['tomorrow_available'],15)

    def test_tomorrow_rest_reset_and_weekly_cap(self):
        r=calculate([row(11,65)])
        self.assertEqual(r['tomorrow_available'],0)
        self.assertFalse(r['tomorrow_working'])
        r=calculate([row(15,95)])
        self.assertIsNone(r['tomorrow_available'])
        self.assertTrue(r['tomorrow_reset'])
        r=calculate([row(14,95)])
        self.assertLessEqual(r['tomorrow_available'],5)

    def test_schedule_edit_preserves_past_allowances(self):
        samples=[row(9,0,0),row(10,10,0),row(10,12)]
        changes=[dict(at=0,workdays=list(range(7))),dict(at=ts(10,10),workdays=[0,1,3,4,5])]
        old=calculate_in_zone(samples,list(range(7)),ZONE)
        new=calculate_in_zone(samples,[0,1,3,4,5],ZONE,schedule_changes=changes)
        self.assertEqual(new['cap'],20)
        self.assertAlmostEqual(new['opening_bonus_low'],old['opening_bonus_low'])
        self.assertAlmostEqual(new['available']-old['available'],20-100/7)
        self.assertAlmostEqual(new['planning_balance'],100/7+20-12)
        # A new cycle uses the latest schedule, without old daily targets.
        new=calculate_in_zone([row(17,0,0,reset=ts(23,0))],[0,1,3,4,5],ZONE,schedule_changes=changes)
        self.assertEqual(new['opening_bonus_low'],0)
        self.assertEqual(new['cap'],20)

if __name__=='__main__': unittest.main()
