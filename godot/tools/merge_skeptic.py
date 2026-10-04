#!/usr/bin/env python3
"""tools/merge_skeptic.py — v13: merge bot-pilot JSONL fragments into the
skepticism report.

Reads QA/reports/skepticism-<date>-s<N>.jsonl (written incrementally by
scripts/skeptic.gd, one JSON object per line), and writes
QA/reports/skepticism-<date>.md with:
  - per-sortie stat table (kills, deaths, score, kills/min, dmg/min)
  - anomaly table with severity + evidence
  - a 1942-grounded ideas section (suggestions only, never auto-applied)

Seedfault runs (--seedfault=stall) are reported as detector proof but
excluded from the fail gate.

Exit 0 when no CRITICAL anomaly was found in real runs, 1 otherwise.
Usage: merge_skeptic.py <reports-dir> <date>
"""
import glob
import json
import os
import statistics
import sys

reports_dir, date = sys.argv[1], sys.argv[2]
frag_paths = sorted(glob.glob(os.path.join(
    reports_dir, "skepticism-%s-s*.jsonl" % date)))

runs = {}       # sortie_idx -> {"meta":..., "anomalies": [...], "snaps": [...], "events": [...]}
for fp in frag_paths:
    run = {"meta": None, "anomalies": [], "snaps": [], "events": [],
           "run_end": None}
    with open(fp) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            t = obj.get("type")
            if t == "meta":
                run["meta"] = obj
            elif t == "anomaly":
                run["anomalies"].append(obj)
            elif t == "snapshot":
                run["snaps"].append(obj)
            elif t == "run_end":
                run["run_end"] = obj
            else:
                run["events"].append(obj)
    if run["meta"] is None:
        continue
    runs[run["meta"]["sortie"]] = run

real = {s: r for s, r in runs.items() if not r["meta"].get("seedfault")}
seed = {s: r for s, r in runs.items() if r["meta"].get("seedfault")}

crit = sum(1 for r in real.values() for a in r["anomalies"] if a["sev"] == "CRITICAL")
high = sum(1 for r in real.values() for a in r["anomalies"] if a["sev"] == "HIGH")
med = sum(1 for r in real.values() for a in r["anomalies"] if a["sev"] == "MED")

# per-sortie final stats (run_end wins; last snapshot otherwise)
stats = {}
for s, r in real.items():
    if r["run_end"] is not None:
        e = r["run_end"]
        run_s = max(float(e.get("run_s", 50.0)), 1.0)
        snaps = r["snaps"]
        stats[s] = {
            "kills": e["kills"], "deaths": e["deaths"], "score": e["score"],
            "kpm": e["kills"] / (run_s / 60.0),
            "dmg_per_min": e["dmg"] / (run_s / 60.0),
            "boss_spawned": snaps[-1]["boss_spawned"] if snaps else False,
            "sortie_name": r["meta"]["sortie_name"],
        }
    elif r["snaps"]:
        stats[s] = r["snaps"][-1]
    else:
        stats[s] = {"kills": 0, "deaths": 0, "score": 0, "kpm": 0.0,
                    "dmg_per_min": 0.0, "boss_spawned": False,
                    "touch_path": False,
                    "sortie_name": r["meta"]["sortie_name"]}

# difficulty spikes: dmg/min vs campaign median
dmg_rates = [v["dmg_per_min"] for v in stats.values()]
dmg_median = statistics.median(dmg_rates) if dmg_rates else 0.0
kpm_rates = [v["kpm"] for v in stats.values() if v["kpm"] > 0]
kpm_median = statistics.median(kpm_rates) if kpm_rates else 0.0

ideas = []
for s in sorted(stats):
    v = stats[s]
    name = v.get("sortie_name", "S%d" % (s + 1))
    mythic = "duel" in name.lower()  # the Thunderhead Duel is a boss arena
    if kpm_median > 0 and 0 < v["kpm"] < 0.6 * kpm_median and not mythic:
        ideas.append(
            "Sortie %d (%s): kill-rate %.1f/min is %d%% below the campaign "
            "median — consider a wiped-squadron bonus drop here (the "
            "POW-carrier homage queued in the v11 1942 research)." % (
                s + 1, name, v["kpm"],
                int(100 * (1 - v["kpm"] / kpm_median))))
    if dmg_median > 0 and v["dmg_per_min"] > 2.5 * dmg_median:
        ideas.append(
            "Sortie %d (%s): damage pressure %.0f/min is %.1fx the median — "
            "check telegraph fairness on its waves (1942 was built for "
            "accessibility, not punishment)." % (
                s + 1, name, v["dmg_per_min"],
                v["dmg_per_min"] / dmg_median))
    if v["kpm"] > 0 and v["kpm"] < 2.0 and not mythic:
        ideas.append(
            "Sortie %d (%s): %.1f kills/min reads barren — 1942 kept the sky "
            "busy; consider denser early waves." % (s + 1, name, v["kpm"]))
    if v["kpm"] > 25.0 and not mythic:
        ideas.append(
            "Sortie %d (%s): %.1f kills/min is a pinata — check it doesn't "
            "trivialize the squadron break-point." % (s + 1, name, v["kpm"]))
for s, r in real.items():
    for e in r["events"]:
        if e.get("kind") == "boss_killed" and e.get("duration", 0) > 90:
            ideas.append(
                "Sortie %d: the boss duel ran %.0fs — 1942's Mother Bomber "
                "was brisk; consider trimming HP or sharper telegraphs." % (
                    s + 1, e["duration"]))
early = sum(1 for r in real.values() for a in r["anomalies"]
            if a["kind"] == "unfair_death_early")
if early:
    ideas.append(
        "%d death(s) inside the spawn-fairness window — consider a gentler "
        "opening wave (1942 was designed for Western accessibility)." % early)
if not ideas:
    ideas.append(
        "No strong signals this run. The v11 borrow queue still stands: "
        "debrief kill-rating % would give the skeptic a sharper economy "
        "signal than kills/min alone.")

verdict = "SKEPTIC: %d anomalies (%d critical, %d high, %d med) across %d runs" % (
    crit + high + med, crit, high, med, len(real))

lines = []
lines.append("# Skepticism report — %s" % date)
lines.append("")
lines.append("Automated playtesting: a mid-skill bot pilot flew every sortie "
             "through the real control path (touch steering, real fire/loop/ "
             "bomb inputs); the skeptic watched for anything that feels "
             "wrong. Evidence, not vibes.")
lines.append("")
lines.append("**%s**" % verdict)
lines.append("")
lines.append("## Per-sortie stats")
lines.append("")
lines.append("| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |")
lines.append("|---|---|---|---|---|---|---|")
for s in sorted(stats):
    v = stats[s]
    name = v.get("sortie_name", "S%d" % (s + 1))
    lines.append("| %d %s | %d | %d | %d | %.1f | %.0f | %s |" % (
        s + 1, name, v["kills"], v["deaths"], v["score"], v["kpm"],
        v["dmg_per_min"], "yes" if v["boss_spawned"] else "no"))
lines.append("")
lines.append("## Anomalies")
lines.append("")
if crit + high + med == 0:
    lines.append("None. The sky felt right.")
else:
    lines.append("| t | Sortie | Severity | Kind | Evidence |")
    lines.append("|---|---|---|---|---|")
    rows = []
    for s, r in real.items():
        for a in r["anomalies"]:
            rows.append((a["t"], s, a))
    for t, s, a in sorted(rows, key=lambda r: (r[0], r[1])):
        extra = " ".join("%s=%s" % (k, v) for k, v in a.items()
                         if k not in ("type", "t", "kind", "sev", "detail",
                                      "sortie", "seedfault"))
        lines.append("| %.1fs | %d | **%s** | `%s` | %s %s |" % (
            t, s + 1, a["sev"], a["kind"], a["detail"], extra))
lines.append("")
lines.append("## Ideas (1942-grounded, suggestions only)")
lines.append("")
for i, idea in enumerate(ideas, 1):
    lines.append("%d. %s" % (i, idea))
lines.append("")
lines.append("## Detector proof")
lines.append("")
proofed = any(
    any(a["kind"] == "pass_stall" for a in r["anomalies"])
    for r in seed.values())
if proofed:
    lines.append("The `--seedfault=stall` run wedged a pass aircraft and the "
                 "skeptic flagged `pass_stall` as designed — the detector "
                 "fires on real faults, not just theory.")
else:
    lines.append("WARNING: no seedfault run with a `pass_stall` flag was "
                 "found — detector proof is missing this run.")
lines.append("")
lines.append("_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._")

out = os.path.join(reports_dir, "skepticism-%s.md" % date)
with open(out, "w") as f:
    f.write("\n".join(lines) + "\n")

print("Report: QA/reports/skepticism-%s.md — %s" % (date, verdict))
print("Seedfault detector proof: %s" % ("PASS" if proofed else "MISSING"))
sys.exit(1 if crit > 0 else 0)
