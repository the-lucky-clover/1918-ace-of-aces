#!/usr/bin/env python3
"""tools/merge_skeptic.py — v23: merge bot-pilot JSONL fragments into the
skepticism report.

Reads QA/reports/skepticism-<date>-s<N>[-seed-<fault>].jsonl (written
incrementally by scripts/skeptic.gd, one JSON object per line), and writes
QA/reports/skepticism-<date>.md with:
  - per-sortie, per-archetype stat table
  - anomaly table with severity + evidence
  - per-fault detector-proof table (every detector must catch its fault)
  - difficulty-curve verdicts (merge-time, cross-archetype)
  - trends (pass rate / deaths per archetype over recent days)
  - auto-filed bug reports for HIGH/CRITICAL hits (QA/bugs/, deduplicated)
  - a 1942-grounded ideas section (suggestions only, never auto-applied)

Seedfault runs are reported as detector proof but excluded from the fail gate.

Exit 0 when no CRITICAL anomaly was found in real runs AND every seeded
fault proved its detector, 1 otherwise.
Usage: merge_skeptic.py <reports-dir> <date>
"""
import glob
import json
import os
import re
import statistics
import sys

reports_dir, date = sys.argv[1], sys.argv[2]
bugs_dir = os.path.join(os.path.dirname(reports_dir), "bugs")
template_path = os.path.join(os.path.dirname(reports_dir),
                             "BUG-REPORT-TEMPLATE.md")
trends_path = os.path.join(reports_dir, "skepticism-trends.jsonl")

# v23: fault -> (proof record type, expected kind). "sfx" proves the v21
# mixer cap via a positive event (the cap makes sfx_spam unhittable through
# SFX.play by design); sfx_cap_broken would be the CRITICAL instead.
FAULT_PROOF = {
    "stall": ("anomaly", "pass_stall"),
    "unfair": ("anomaly", "death_no_visible_cause"),
    "spawncamp": ("anomaly", "spawn_camp"),
    "glow": ("anomaly", "enemy_glow"),
    "edge": ("anomaly", "edge_linger"),
    "sfx": ("event", "mixer_cap_held"),
    "rumble": ("anomaly", "rumble_storm"),
    "earlydeath": ("anomaly", "unfair_death_early"),
}

# suspected cause per detector, for auto-filed bug reports
DETECTOR_CAUSE = {
    "pass_stall": "godot/scripts/enemy.gd — v10 1942 pass state machine (state timer / turn logic)",
    "pass_overlife": "godot/scripts/enemy.gd — exit/despawn path (v20: exits must climb out the top)",
    "pass_no_turn": "godot/scripts/enemy.gd — 180-degree bank at the turn line",
    "edge_linger": "godot/scripts/enemy.gd — exit climb rate / side-edge despawn (v20 conga-line fix)",
    "enemy_glow": "godot/scripts/enemy.gd — firing telegraph (v20: small amber nose glint, not full-body)",
    "unfair_death_early": "sortie wave tables / spawn pacing — spawn protection vs opening wave",
    "death_no_visible_cause": "damage routing — something deals damage with no visible source",
    "unfair_kill": "wave spawn tables / enemy.gd — telegraph fairness under the one-hit model",
    "spawn_camp": "main.gd wave spawner — spawn position vs player position",
    "softlock": "godot/scripts/main.gd — sortie schedule / objective progression",
    "wave_stall": "godot/scripts/main.gd — wave schedule stalled",
    "bot_zero_progress": "game boot / bot control path — is the game even running?",
    "dead_air": "sortie wave tables — pacing gap with nothing to shoot",
    "threat_saturation": "sortie wave tables — too many simultaneous attackers",
    "kette_broken": "godot/scripts/enemy.gd — Kette shared weave phase / formation cohesion",
    "sfx_spam": "godot/scripts/sfx.gd — mixer cap (v21: 4 same-name plays/rolling second)",
    "sfx_cap_broken": "godot/scripts/sfx.gd — v21 mixer cap regressed",
    "rumble_storm": "haptic call sites — rumble storm (mobile jackhammer)",
    "iframes_broken": "godot/scripts/player.gd — post-hit invulnerability",
    "hitch": "frame workload — physics frame over budget",
    "hitch_storm": "frame workload — sustained slow frames",
    "perf_sag": "frame workload — physics fps sag headless",
    "node_leak": "despawn paths — node count grows without sortie change",
    "difficulty_curve": "sortie wave tables / 1942 damage tuning — too hot for average hands",
    "expert_early_heat": "early sortie wave tables — experts should not die on sorties 1-8",
    "survivalist_paradox": "damage routing — the cautious bot dies more than average: unavoidable damage?",
}

FRAG_RE = re.compile(
    r"skepticism-\d{4}-\d{2}-\d{2}-s(\d+)"
    r"(?:-(novice|average|expert|survivalist))?"
    r"(?:-seed(?:-([a-z]+))?)?\.jsonl")

runs = {}  # (sortie, archetype, fault) -> parsed run
for fp in sorted(glob.glob(os.path.join(
        reports_dir, "skepticism-%s-s*.jsonl" % date))):
    m = FRAG_RE.search(os.path.basename(fp))
    if not m:
        continue
    sortie = int(m.group(1))
    frag_arch = m.group(2)  # v23: non-average archetypes in the filename
    fault = m.group(3) or ""  # v21 legacy "-seed" (no name) was always stall
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
    # the v21 "-seed" fragment (no fault name) was always the stall fault
    if fault == "" and run["meta"].get("seedfault"):
        fault = "stall"
    # archetype: filename wins (it disambiguates shared sorties); meta is
    # the fallback for legacy fragments without the suffix.
    arch = frag_arch or str(run["meta"].get("archetype", "average"))
    # v21 lesson kept: keyed (sortie, archetype, fault) — seeded runs can
    # never collide with real sorties, nor with each other.
    runs[(sortie, arch, fault)] = run

real = {k: r for k, r in runs.items() if k[2] == ""}
seed = {k: r for k, r in runs.items() if k[2] != ""}

crit = sum(1 for r in real.values() for a in r["anomalies"]
           if a["sev"] == "CRITICAL")
high = sum(1 for r in real.values() for a in r["anomalies"]
           if a["sev"] == "HIGH")
med = sum(1 for r in real.values() for a in r["anomalies"]
          if a["sev"] == "MED")


def run_stats(r):
    if r["run_end"] is not None:
        e = r["run_end"]
        run_s = max(float(e.get("run_s", 50.0)), 1.0)
        snaps = r["snaps"]
        return {
            "kills": e["kills"], "deaths": e["deaths"], "score": e["score"],
            "kpm": e["kills"] / (run_s / 60.0),
            "dmg_per_min": e["dmg"] / (run_s / 60.0),
            "boss_spawned": snaps[-1]["boss_spawned"] if snaps else False,
            "sortie_name": r["meta"]["sortie_name"],
        }
    if r["snaps"]:
        return r["snaps"][-1]
    return {"kills": 0, "deaths": 0, "score": 0, "kpm": 0.0,
            "dmg_per_min": 0.0, "boss_spawned": False, "touch_path": False,
            "sortie_name": r["meta"]["sortie_name"]}


stats = {k: run_stats(r) for k, r in real.items()}

# ---- v23: difficulty-curve verdicts (merge-time, cross-archetype) ----
curve_anoms = []


def synth(kind, sev, detail, sortie):
    return {"type": "anomaly", "t": 0.0, "kind": kind, "sev": sev,
            "detail": detail, "sortie": sortie, "seedfault": False,
            "synthetic": True}


by_sortie = {}
for (s, a, _f), v in stats.items():
    by_sortie.setdefault(s, {})[a] = v
for s, av in sorted(by_sortie.items()):
    v = av.get("average")
    if v is not None and v["deaths"] > 8:  # SkepticConfig.CURVE_AVG_DEATH_LIMIT
        curve_anoms.append(synth(
            "difficulty_curve", "HIGH",
            "average archetype died %d times in %.0fs — too hot for average "
            "hands (limit 8); 1942 was built for accessibility, not "
            "punishment" % (v["deaths"], 40), s))
    v = av.get("expert")
    if v is not None and s < 8 and v["deaths"] > 2:
        curve_anoms.append(synth(
            "expert_early_heat", "MED",
            "expert died %d times on sortie %d — sorties 1-8 should not "
            "kill near-optimal play" % (v["deaths"], s + 1), s))
    va, vs = av.get("average"), av.get("survivalist")
    if va is not None and vs is not None \
            and vs["deaths"] > va["deaths"] + 4:
        curve_anoms.append(synth(
            "survivalist_paradox", "MED",
            "survivalist died %d vs average %d — the cautious bot dies "
            "MORE: some damage is unavoidable, not dodgeable" % (
                vs["deaths"], va["deaths"]), s))
for a in curve_anoms:
    if a["sev"] == "CRITICAL":
        crit += 1
    elif a["sev"] == "HIGH":
        high += 1
    else:
        med += 1

# ---- v23: detector proof table ----
proof = {}
for fault, (ptype, kind) in FAULT_PROOF.items():
    runs_f = [r for (s, a, f), r in seed.items() if f == fault]
    if not runs_f:
        proof[fault] = "MISSING — no --seedfault=%s run found" % fault
        continue
    if ptype == "anomaly":
        hit = any(any(x["kind"] == kind for x in r["anomalies"])
                  for r in runs_f)
        broken = [x for r in runs_f for x in r["anomalies"]
                  if x["kind"] in ("sfx_cap_broken",)]
        if broken:
            proof[fault] = "BROKEN — %s" % broken[0]["detail"]
        else:
            proof[fault] = "PASS" if hit else \
                "MISSING — `%s` not flagged in the %s run" % (kind, fault)
    else:
        hit = any(any(e.get("kind") == kind for e in r["events"])
                  for r in runs_f)
        proof[fault] = "PASS" if hit else \
            "MISSING — event `%s` not found in the %s run" % (kind, fault)
proof_ok = sum(1 for v in proof.values() if v == "PASS")

# ---- v23: trends ----
trend_rows = []
for (s, a, f), r in runs.items():
    v = run_stats(r)
    trend_rows.append({
        "date": date, "sortie": s, "archetype": a, "fault": f,
        "kills": v["kills"], "deaths": v["deaths"],
        "kpm": round(v["kpm"], 2),
        "dmg_per_min": round(v["dmg_per_min"], 1),
        "crit": sum(1 for x in r["anomalies"] if x["sev"] == "CRITICAL"),
        "high": sum(1 for x in r["anomalies"] if x["sev"] == "HIGH"),
        "med": sum(1 for x in r["anomalies"] if x["sev"] == "MED"),
    })
with open(trends_path, "a") as f:
    for row in trend_rows:
        f.write(json.dumps(row) + "\n")

history = {}  # (sortie, archetype) -> [rows sorted by date]
if os.path.isfile(trends_path):
    with open(trends_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("fault"):
                continue  # trends track real runs only
            history.setdefault(
                (row["sortie"], row["archetype"]), []).append(row)
for k in history:
    history[k] = sorted(history[k], key=lambda r: r["date"])[-5:]

# ---- ideas (1942-grounded, suggestions only) ----
dmg_rates = [v["dmg_per_min"] for v in stats.values()]
dmg_median = statistics.median(dmg_rates) if dmg_rates else 0.0
kpm_rates = [v["kpm"] for v in stats.values() if v["kpm"] > 0]
kpm_median = statistics.median(kpm_rates) if kpm_rates else 0.0

ideas = []
for (s, a, _f) in sorted(stats):
    v = stats[(s, a, _f)]
    name = v.get("sortie_name", "S%d" % (s + 1))
    mythic = "duel" in name.lower()
    if kpm_median > 0 and 0 < v["kpm"] < 0.6 * kpm_median and not mythic:
        ideas.append(
            "Sortie %d (%s) [%s]: kill-rate %.1f/min is %d%% below the "
            "campaign median — consider a wiped-squadron bonus drop here." % (
                s + 1, name, a, v["kpm"],
                int(100 * (1 - v["kpm"] / kpm_median))))
    if dmg_median > 0 and v["dmg_per_min"] > 2.5 * dmg_median:
        ideas.append(
            "Sortie %d (%s) [%s]: damage pressure %.0f/min is %.1fx the "
            "median — check telegraph fairness on its waves." % (
                s + 1, name, a, v["dmg_per_min"],
                v["dmg_per_min"] / dmg_median))
for (s, a, _f), r in real.items():
    for e in r["events"]:
        if e.get("kind") == "boss_killed" and e.get("duration", 0) > 90:
            ideas.append(
                "Sortie %d [%s]: the boss duel ran %.0fs — 1942's Mother "
                "Bomber was brisk; consider trimming hits or sharper "
                "telegraphs." % (s + 1, a, e["duration"]))
early = sum(1 for r in real.values() for a in r["anomalies"]
            if a["kind"] == "unfair_death_early")
if early:
    ideas.append(
        "%d death(s) inside the spawn-fairness window — consider a gentler "
        "opening wave (1942 was designed for Western accessibility)." % early)
if not ideas:
    ideas.append(
        "No strong signals this run. Kill-rating % on the debrief would give "
        "the skeptic a sharper economy signal than kills/min alone.")

# ---- v23: auto-file bugs for HIGH/CRITICAL hits ----
filed = []
existing_sigs = set()
existing_nums = [0]
if os.path.isdir(bugs_dir):
    for fn in os.listdir(bugs_dir):
        m = re.match(r"(\d+)-", fn)
        if m:
            existing_nums.append(int(m.group(1)))
        with open(os.path.join(bugs_dir, fn), errors="replace") as f:
            for line in f:
                if line.startswith("<!-- skeptic-sig:"):
                    existing_sigs.add(
                        line.split(":", 1)[1].split("-->")[0].strip())
filed_sigs = set()


def file_bug(anom, run):
    kind, sev = anom["kind"], anom["sev"]
    if sev not in ("CRITICAL", "HIGH"):
        return
    s = anom["sortie"]
    norm = re.sub(r"\d+", "#", anom["detail"][:60])
    sig = "%s|%d|%s" % (kind, s, norm)
    if sig in existing_sigs or sig in filed_sigs:
        return
    filed_sigs.add(sig)
    n = max(existing_nums) + 1
    existing_nums.append(n)
    slug = re.sub(r"[^a-z0-9]+", "-", kind.lower()).strip("-")
    fn = os.path.join(bugs_dir, "%03d-%s-s%d.md" % (n, slug, s + 1))
    version = str(run["meta"].get("version", "?"))
    arch = str(run["meta"].get("archetype", "average"))
    tmpl = open(template_path).read() if os.path.isfile(
        template_path) else "# Bug Report Template\n"
    body = tmpl
    body += "\n<!-- skeptic-sig: %s -->\n" % sig
    body += "<!-- auto-filed by the skeptic bot; human triage required -->\n"
    repl = {
        "<!-- one-line summary -->":
            "[skeptic] %s on sortie %d (%s)" % (kind, s + 1, sev),
        "<!-- holistic version from the VERSION file / in-game badge, e.g. v1 -->":
            version,
        "<!-- blocker | major | minor | cosmetic -->":
            "blocker" if sev == "CRITICAL" else "major",
        "<!-- web build (browser + device) or Godot build (version, OS); commit hash if known -->":
            "Godot headless bot run (archetype: %s)" % arch,
        "## Steps to reproduce\n1.\n2.\n3.":
            "## Steps to reproduce\n"
            "1. Run the nightly bot matrix "
            "(`--botpilot --botarchetype=%s --sortie=%d`).\n"
            "2. Observe the `%s` anomaly at t=%.1fs in "
            "QA/reports/skepticism-%s-s%d.jsonl.\n"
            "3. See the skepticism report for full evidence." % (
                arch, s, kind, float(anom.get("t", 0)), date, s),
        "<!-- what should happen -->":
            "No %s anomaly — the sortie should play fair under the "
            "one-hit model." % kind,
        "<!-- what actually happens -->":
            anom["detail"],
        "<!-- file / line / mechanism, if known -->":
            DETECTOR_CAUSE.get(kind, "see the skepticism report"),
        "<!-- what was changed, in which files; link the commit -->":
            "(unfixed)",
        "<!-- date + version, e.g. 2026-10-04 / v3 -->":
            "%s / v%s" % (date, version),
        "<!-- open | fixed-unverified | verified-fixed | wontfix -->":
            "open",
    }
    for k, v2 in repl.items():
        body = body.replace(k, v2)
    os.makedirs(bugs_dir, exist_ok=True)
    with open(fn, "w") as f:
        f.write(body)
    filed.append(os.path.basename(fn))


all_anoms = [(a, r) for r in real.values() for a in r["anomalies"]]
all_anoms += [(a, {"meta": {"version": "?", "archetype": "average"}})
              for a in curve_anoms]
for anom, run in all_anoms:
    file_bug(anom, run)

# ---- report ----
verdict = ("SKEPTIC: %d anomalies (%d critical, %d high, %d med) across %d "
           "runs | proof %d/%d | bugs filed: %d" % (
               crit + high + med, crit, high, med, len(real),
               proof_ok, len(FAULT_PROOF), len(filed)))

lines = []
lines.append("# Skepticism report — %s" % date)
lines.append("")
lines.append("Automated playtesting: bot pilots of four archetypes "
             "(novice / average / expert / survivalist) flew sampled sorties "
             "through the real control path (touch steering, real fire/loop/ "
             "bomb inputs); the skeptic watched for anything that feels "
             "wrong. Evidence, not vibes. One-hit model: the SPAD XIII dies "
             "in a single hit, so every death must be telegraphed.")
lines.append("")
lines.append("**%s**" % verdict)
lines.append("")
lines.append("## Per-sortie stats")
lines.append("")
lines.append("| Sortie | Archetype | Kills | Deaths | Score | Kills/min | "
             "Dmg/min | Boss? |")
lines.append("|---|---|---|---|---|---|---|---|")
for (s, a, _f) in sorted(stats):
    v = stats[(s, a, _f)]
    name = v.get("sortie_name", "S%d" % (s + 1))
    lines.append("| %d %s | %s | %d | %d | %d | %.1f | %.0f | %s |" % (
        s + 1, name, a, v["kills"], v["deaths"], v["score"], v["kpm"],
        v["dmg_per_min"], "yes" if v["boss_spawned"] else "no"))
lines.append("")
lines.append("## Anomalies")
lines.append("")
rows = []
for (s, a, _f), r in real.items():
    for x in r["anomalies"]:
        rows.append((x["t"], s, a, x))
for x in curve_anoms:
    rows.append((x["t"], x["sortie"], "curve", x))
if crit + high + med == 0:
    lines.append("None. The sky felt right.")
else:
    lines.append("| t | Sortie | Archetype | Severity | Kind | Evidence |")
    lines.append("|---|---|---|---|---|---|")
    for t, s, a, x in sorted(rows, key=lambda r: (r[0], r[1])):
        extra = " ".join("%s=%s" % (k, v) for k, v in x.items()
                         if k not in ("type", "t", "kind", "sev", "detail",
                                      "sortie", "seedfault", "synthetic"))
        lines.append("| %.1fs | %d | %s | **%s** | `%s` | %s %s |" % (
            t, s + 1, a, x["sev"], x["kind"], x["detail"], extra))
lines.append("")
lines.append("## Detector proof (seeded faults)")
lines.append("")
lines.append("Every detector must catch its seeded fault every nightly — "
             "a detector that cannot prove itself is not trusted.")
lines.append("")
lines.append("| Fault | Expected | Result |")
lines.append("|---|---|---|")
for fault, (_pt, kind) in FAULT_PROOF.items():
    ok = proof[fault] == "PASS"
    detail = "" if ok else " — " + proof[fault]
    lines.append("| `--seedfault=%s` | `%s` | **%s**%s |" % (
        fault, kind, "PASS" if ok else "FAIL", detail))
lines.append("")
if filed:
    lines.append("## Auto-filed bugs")
    lines.append("")
    lines.append("HIGH/CRITICAL hits filed to QA/bugs/ (deduplicated by "
                 "signature; human triage required):")
    lines.append("")
    for fn in filed:
        lines.append("- `%s`" % fn)
    lines.append("")
lines.append("## Trends (recent days, real runs)")
lines.append("")
if not history:
    lines.append("No history yet — trends begin with the second night.")
else:
    lines.append("| Sortie | Archetype | Deaths (recent) | CRITICAL runs |")
    lines.append("|---|---|---|---|")
    for (s, a) in sorted(history):
        rows_h = history[(s, a)]
        deaths = " → ".join(str(r["deaths"]) for r in rows_h)
        crit_runs = sum(1 for r in rows_h if r["crit"] > 0)
        lines.append("| %d | %s | %s | %d/%d |" % (
            s + 1, a, deaths, crit_runs, len(rows_h)))
lines.append("")
lines.append("## Ideas (1942-grounded, suggestions only)")
lines.append("")
for i, idea in enumerate(ideas, 1):
    lines.append("%d. %s" % (i, idea))
lines.append("")
lines.append("_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd. "
             "Archetypes: scripts/skeptic_archetypes.gd._")

out = os.path.join(reports_dir, "skepticism-%s.md" % date)
with open(out, "w") as f:
    f.write("\n".join(lines) + "\n")

print("Report: QA/reports/skepticism-%s.md — %s" % (date, verdict))
for fault, res in proof.items():
    print("  proof %-10s: %s" % (fault, res))
if filed:
    print("Filed %d bug(s): %s" % (len(filed), ", ".join(filed)))
sys.exit(1 if (crit > 0 or proof_ok < len(FAULT_PROOF)) else 0)
