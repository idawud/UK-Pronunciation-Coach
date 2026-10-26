"""Beta metrics from exported progress files (R1-release).

Beta testers send their progress file by choice (Settings > Send feedback >
"Save file and email", or Export progress). This script reads those files, one per
learner, and reports the two SPEC success metrics that depend on behaviour:

  * Users practising 3+ days a week: target 40% of learners.
    A practice day is a calendar day with a practice session or a scored reading.
    A learner meets it when their average number of practice days per week, over the
    weeks of their beta window, is 3 or more.
  * Average score gain on repeated passages over 4 weeks: target +10 points.
    For each passage a learner read at least twice inside their window, the gain is
    the last overall score minus the first. A learner's gain is the mean over those
    passages; the reported figure is the mean over learners with any repeated passage.

A learner's window starts at their first practice (or --start) and lasts --weeks
weeks (default 4), cut short at the file's export date. Files hold no audio and no
names; the learner label is the file name.

    python -m tools.beta.report progress/*.json
    python -m tools.beta.report --start 2026-11-02 --json out.json progress/*.json
    python -m tools.beta.report --strict progress/*.json   # exit 1 if a target is missed
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import defaultdict
from dataclasses import asdict, dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path

SUPPORTED_SCHEMA = 1
TARGET_SHARE_3_DAYS = 0.40
TARGET_DAYS_PER_WEEK = 3.0
TARGET_GAIN = 10.0


@dataclass(frozen=True)
class Attempt:
    """One scored reading."""

    passage_id: str
    at: datetime
    overall: int


@dataclass(frozen=True)
class Learner:
    """What the report needs from one progress file."""

    label: str
    exported_at: datetime
    attempts: tuple[Attempt, ...]
    sessions: tuple[datetime, ...]


@dataclass
class LearnerReport:
    """Per-learner results."""

    label: str
    window_start: str | None
    window_end: str | None
    weeks: float
    practice_days: int
    days_per_week: float
    meets_3_days: bool
    repeated_passages: int
    mean_gain: float | None
    gains: dict[str, int] = field(default_factory=dict)


@dataclass
class Summary:
    """The beta's totals against the SPEC targets."""

    learners: int
    active_learners: int
    share_3_days: float | None
    meets_share_target: bool | None
    learners_with_repeats: int
    mean_gain: float | None
    meets_gain_target: bool | None
    per_learner: list[LearnerReport]


def _parse_time(value: str) -> datetime:
    # Dart writes ISO 8601, local time without an offset (or with "Z" for UTC).
    # Times are compared per learner, so any offset is dropped consistently.
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return dt.replace(tzinfo=None)


def load(path: Path) -> Learner:
    """Reads one exported progress file. Raises ValueError if it is not one."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as e:
        raise ValueError(f"{path}: not a readable JSON file ({e})") from e
    if not isinstance(data, dict) or "exportedAt" not in data:
        raise ValueError(f"{path}: not a progress backup from the app")
    schema = data.get("schemaVersion", 1)
    if not isinstance(schema, int) or schema > SUPPORTED_SCHEMA or schema < 1:
        raise ValueError(f"{path}: unsupported schemaVersion {schema!r}")
    try:
        attempts = tuple(
            Attempt(str(a["passageId"]), _parse_time(a["at"]), int(a["overall"]))
            for a in data.get("attempts", [])
        )
        sessions = tuple(_parse_time(s["start"]) for s in data.get("practiceSessions", []))
        exported = _parse_time(data["exportedAt"])
    except (KeyError, TypeError, ValueError) as e:
        raise ValueError(f"{path}: malformed progress file ({e})") from e
    return Learner(path.stem, exported, attempts, sessions)


def analyse(learner: Learner, *, start: date | None = None, weeks: int = 4) -> LearnerReport:
    """Practice days and score gains for one learner."""
    activity = [a.at for a in learner.attempts] + list(learner.sessions)
    if not activity:
        return LearnerReport(learner.label, None, None, 0.0, 0, 0.0, False, 0, None)
    first = start or min(activity).date()
    last_allowed = first + timedelta(weeks=weeks)  # exclusive
    end = min(last_allowed, learner.exported_at.date() + timedelta(days=1))
    if end <= first:
        end = first + timedelta(days=1)
    span_days = (end - first).days
    # A window shorter than a week still counts as one week: 3 days in 5 meets it.
    window_weeks = max(span_days / 7, 1.0)

    def inside(t: datetime) -> bool:
        return first <= t.date() < end

    days = {t.date() for t in activity if inside(t)}
    per_week = len(days) / window_weeks

    by_passage: dict[str, list[Attempt]] = defaultdict(list)
    for a in sorted(learner.attempts, key=lambda a: a.at):
        if inside(a.at):
            by_passage[a.passage_id].append(a)
    gains = {
        pid: tries[-1].overall - tries[0].overall
        for pid, tries in by_passage.items()
        if len(tries) >= 2
    }
    mean_gain = statistics.fmean(gains.values()) if gains else None
    return LearnerReport(
        label=learner.label,
        window_start=first.isoformat(),
        window_end=(end - timedelta(days=1)).isoformat(),
        weeks=round(window_weeks, 2),
        practice_days=len(days),
        days_per_week=round(per_week, 2),
        meets_3_days=per_week >= TARGET_DAYS_PER_WEEK,
        repeated_passages=len(gains),
        mean_gain=None if mean_gain is None else round(mean_gain, 2),
        gains=dict(sorted(gains.items())),
    )


def summarise(reports: list[LearnerReport]) -> Summary:
    """Totals against the SPEC targets. Learners with no activity count as not
    practising (they joined the beta), but not towards the score gain."""
    n = len(reports)
    active = sum(1 for r in reports if r.practice_days)
    share = sum(r.meets_3_days for r in reports) / n if n else None
    with_gain = [r.mean_gain for r in reports if r.mean_gain is not None]
    gain = statistics.fmean(with_gain) if with_gain else None
    return Summary(
        learners=n,
        active_learners=active,
        share_3_days=None if share is None else round(share, 4),
        meets_share_target=None if share is None else share >= TARGET_SHARE_3_DAYS,
        learners_with_repeats=len(with_gain),
        mean_gain=None if gain is None else round(gain, 2),
        meets_gain_target=None if gain is None else gain >= TARGET_GAIN,
        per_learner=reports,
    )


def _verdict(ok: bool | None) -> str:
    return "n/a" if ok is None else ("MET" if ok else "not met")


def format_text(summary: Summary) -> str:
    """Human-readable report."""
    lines = [
        f"Learners: {summary.learners} ({summary.active_learners} with any practice)",
        "",
        f"{'learner':<24} {'window':<23} {'days':>4} {'days/wk':>7} {'3+/wk':>5} "
        f"{'repeats':>7} {'gain':>6}",
    ]
    for r in summary.per_learner:
        window = f"{r.window_start} - {r.window_end}" if r.window_start else "no practice"
        gain = "" if r.mean_gain is None else f"{r.mean_gain:+.1f}"
        lines.append(
            f"{r.label[:24]:<24} {window:<23} {r.practice_days:>4} {r.days_per_week:>7.2f} "
            f"{'yes' if r.meets_3_days else 'no':>5} {r.repeated_passages:>7} {gain:>6}"
        )
    share = "n/a" if summary.share_3_days is None else f"{summary.share_3_days:.0%}"
    gain = "n/a" if summary.mean_gain is None else f"{summary.mean_gain:+.1f}"
    lines += [
        "",
        f"Practising 3+ days a week: {share} of learners "
        f"(target {TARGET_SHARE_3_DAYS:.0%}): {_verdict(summary.meets_share_target)}",
        f"Average score gain on repeated passages: {gain} points over "
        f"{summary.learners_with_repeats} learner(s) (target +{TARGET_GAIN:.0f}): "
        f"{_verdict(summary.meets_gain_target)}",
    ]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Beta metrics from exported progress files.")
    parser.add_argument("files", nargs="+", type=Path, help="exported progress .json files")
    parser.add_argument("--start", type=date.fromisoformat, help="beta start date (YYYY-MM-DD)")
    parser.add_argument("--weeks", type=int, default=4, help="window length (default 4)")
    parser.add_argument("--json", type=Path, help="also write the report as JSON here")
    parser.add_argument("--strict", action="store_true", help="exit 1 if a target is missed")
    args = parser.parse_args(argv)
    if args.weeks < 1:
        parser.error("--weeks must be at least 1")

    reports, errors = [], []
    for path in args.files:
        try:
            reports.append(analyse(load(path), start=args.start, weeks=args.weeks))
        except ValueError as e:
            errors.append(str(e))
    for e in errors:
        print(f"skipped: {e}", file=sys.stderr)
    if not reports:
        print("No readable progress files.", file=sys.stderr)
        return 2
    summary = summarise(reports)
    print(format_text(summary))
    if args.json:
        args.json.write_text(json.dumps(asdict(summary), indent=2) + "\n", encoding="utf-8")
    if args.strict and not (summary.meets_share_target and summary.meets_gain_target):
        return 1
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
