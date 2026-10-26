"""Tests for the beta metrics report (tools/beta/report.py)."""

from __future__ import annotations

import json
from datetime import date, datetime, timedelta
from pathlib import Path

import pytest

from tools.beta import report

REPO = Path(__file__).resolve().parents[3]
START = datetime(2026, 11, 2, 9, 0)  # a Monday


def attempt(passage: str, at: datetime, overall: int) -> dict:
    """An attempt as the app exports it (AttemptResult.toJson)."""
    return {
        "id": f"{passage}-{at.isoformat()}",
        "passageId": passage,
        "at": at.isoformat(),
        "overall": overall,
        "accuracy": overall,
        "fluency": 80,
        "words": [],
        "audioPath": None,
        "tier": "light",
    }


def backup(attempts: list[dict], sessions: list[datetime], exported: datetime) -> dict:
    """A progress file as the app exports it (ProgressBackup.toJson)."""
    return {
        "schemaVersion": 1,
        "exportedAt": exported.isoformat(),
        "profile": {"level": 2},
        "attempts": attempts,
        "soundStats": [],
        "reviewQueue": [],
        "levelHistory": [],
        "practiceSessions": [{"start": s.isoformat(), "duration": 360_000_000} for s in sessions],
    }


def write(tmp_path: Path, name: str, data: dict | str) -> Path:
    path = tmp_path / f"{name}.json"
    path.write_text(data if isinstance(data, str) else json.dumps(data), encoding="utf-8")
    return path


def keen(tmp_path: Path) -> Path:
    """Practice sessions on 4 days a week for 4 weeks, plus readings on days 13 and 20
    (18 practice days); passage p1 rises 60 -> 78, p2 70 -> 74."""
    sessions = [START + timedelta(weeks=w, days=d) for w in range(4) for d in (0, 1, 3, 5)]
    attempts = [
        attempt("p1", START, 60),
        attempt("p2", START + timedelta(days=1), 70),
        attempt("p1", START + timedelta(days=13), 65),
        attempt("p1", START + timedelta(days=26), 78),
        attempt("p2", START + timedelta(days=20), 74),
        attempt("p3", START + timedelta(days=3), 50),
        # After the 4-week window: ignored.
        attempt("p2", START + timedelta(days=30), 99),
    ]
    return write(tmp_path, "keen", backup(attempts, sessions, START + timedelta(days=35)))


def casual(tmp_path: Path) -> Path:
    """Practises once a week; reads p1 twice (+4)."""
    sessions = [START + timedelta(weeks=w, days=2) for w in range(4)]
    attempts = [attempt("p1", sessions[0], 55), attempt("p1", sessions[3], 59)]
    return write(tmp_path, "casual", backup(attempts, sessions, START + timedelta(days=40)))


def test_keen_learner(tmp_path):
    r = report.analyse(report.load(keen(tmp_path)))
    assert r.label == "keen"
    assert r.window_start == "2026-11-02" and r.window_end == "2026-11-29"
    assert r.weeks == 4.0
    assert r.practice_days == 18
    assert r.days_per_week == 4.5 and r.meets_3_days
    assert r.gains == {"p1": 18, "p2": 4}
    assert r.repeated_passages == 2 and r.mean_gain == 11.0


def test_casual_learner(tmp_path):
    r = report.analyse(report.load(casual(tmp_path)))
    assert r.days_per_week == 1.0 and not r.meets_3_days
    assert r.mean_gain == 4.0


def test_window_is_cut_at_the_export_date(tmp_path):
    sessions = [START + timedelta(days=d) for d in (0, 2, 4)]
    path = write(tmp_path, "early", backup([], sessions, START + timedelta(days=4)))
    r = report.analyse(report.load(path))
    # 5 days so far count as one week: 3 practice days meet the target.
    assert r.weeks == 1.0 and r.practice_days == 3 and r.meets_3_days
    assert r.mean_gain is None and r.repeated_passages == 0


def test_explicit_start_and_weeks(tmp_path):
    r = report.analyse(report.load(keen(tmp_path)), start=date(2026, 11, 16), weeks=1)
    assert r.window_start == "2026-11-16" and r.window_end == "2026-11-22"
    assert r.practice_days == 5  # 4 sessions and a reading on day 20
    assert r.gains == {}


def test_learner_without_activity(tmp_path):
    path = write(tmp_path, "idle", backup([], [], START))
    r = report.analyse(report.load(path))
    assert r.practice_days == 0 and not r.meets_3_days and r.window_start is None


def test_attempts_count_as_practice_days(tmp_path):
    attempts = [attempt("p1", START + timedelta(days=d), 70) for d in (0, 1, 2)]
    path = write(tmp_path, "readings", backup(attempts, [], START + timedelta(days=6)))
    assert report.analyse(report.load(path)).practice_days == 3


def test_summary_against_targets(tmp_path):
    reports = [
        report.analyse(report.load(p))
        for p in (keen(tmp_path), casual(tmp_path), write(tmp_path, "idle", backup([], [], START)))
    ]
    s = report.summarise(reports)
    assert s.learners == 3 and s.active_learners == 2
    assert s.share_3_days == pytest.approx(1 / 3, abs=1e-4)
    assert s.meets_share_target is False
    assert s.learners_with_repeats == 2
    assert s.mean_gain == 7.5 and s.meets_gain_target is False
    text = report.format_text(s)
    assert "Practising 3+ days a week: 33% of learners (target 40%): not met" in text
    assert "+7.5 points over 2 learner(s) (target +10): not met" in text
    assert "no practice" in text


def test_summary_of_nothing():
    s = report.summarise([])
    assert s.share_3_days is None and s.meets_share_target is None
    assert "n/a" in report.format_text(s)


@pytest.mark.parametrize(
    ("content", "message"),
    [
        ("not json", "not a readable JSON file"),
        ("[]", "not a progress backup"),
        ('{"exportedAt": "2026-11-01T00:00:00", "schemaVersion": 2}', "unsupported"),
        ('{"exportedAt": "2026-11-01T00:00:00", "attempts": [{"at": "x"}]}', "malformed"),
    ],
)
def test_load_rejects_other_files(tmp_path, content, message):
    with pytest.raises(ValueError, match=message):
        report.load(write(tmp_path, "bad", content))


def test_utc_times_are_accepted(tmp_path):
    data = backup([attempt("p1", START, 70)], [], START)
    data["attempts"][0]["at"] = "2026-11-02T09:00:00.000Z"
    data["exportedAt"] = "2026-11-03T09:00:00.000Z"
    r = report.analyse(report.load(write(tmp_path, "utc", data)))
    assert r.practice_days == 1


def test_main_prints_and_writes_json(tmp_path, capsys):
    out = tmp_path / "out.json"
    bad = write(tmp_path, "bad", "nope")
    code = report.main([str(keen(tmp_path)), str(casual(tmp_path)), str(bad), "--json", str(out)])
    assert code == 0
    captured = capsys.readouterr()
    assert "Learners: 2" in captured.out
    assert "skipped" in captured.err
    data = json.loads(out.read_text(encoding="utf-8"))
    assert data["learners"] == 2 and data["share_3_days"] == 0.5
    assert data["meets_share_target"] is True and data["mean_gain"] == 7.5


def test_main_strict_and_errors(tmp_path, capsys):
    assert report.main([str(keen(tmp_path)), "--strict"]) == 0
    assert report.main([str(casual(tmp_path)), "--strict"]) == 1
    assert report.main([str(write(tmp_path, "bad", "nope"))]) == 2
    with pytest.raises(SystemExit):
        report.main([str(keen(tmp_path)), "--weeks", "0"])
    capsys.readouterr()


def test_export_format_still_matches_the_app():
    # The keys the report reads, as json_serializable generates them for the export.
    generated = {
        "lib/core/models/progress_backup.g.dart": [
            "'schemaVersion'",
            "'exportedAt'",
            "'attempts'",
            "'practiceSessions'",
        ],
        "lib/core/models/attempt_result.g.dart": ["'passageId'", "'at'", "'overall'"],
        "lib/core/models/practice_session.g.dart": ["'start'"],
    }
    for file, keys in generated.items():
        text = (REPO / file).read_text(encoding="utf-8")
        for key in keys:
            assert key in text, f"{key} missing from {file}"
    assert report.SUPPORTED_SCHEMA == 1
