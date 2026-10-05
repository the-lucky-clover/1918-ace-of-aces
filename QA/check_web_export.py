#!/usr/bin/env python3
"""v18: web export readiness — export_presets.cfg must carry a valid Web preset,
and the Godot 4.7.2 export templates (incl. a web template) must be installed.
Static only; the real export is a manual staged step (see PUBLISH-CHECKLIST.md).
Exit 0 on pass, non-zero with a message on fail."""
import os
import re
import sys

HOME = os.path.expanduser("~")
PRESETS = os.path.join(HOME, "workspace/1918-godot/export_presets.cfg")
TPL_DIR = os.path.join(HOME, ".local/share/godot/export_templates/4.7.2.stable")

if not os.path.isfile(PRESETS):
    sys.exit("export_presets.cfg missing from 1918-godot/")

src = open(PRESETS).read()
if 'platform="Web"' not in src:
    sys.exit("no Web platform preset in export_presets.cfg")
if "runnable=true" not in src:
    sys.exit("Web preset is not runnable")
m = re.search(r'export_path="([^"]+)"', src)
if not m or not m.group(1).endswith("web-export/index.html"):
    sys.exit("Web preset export_path must target web-export/index.html, got: %s"
             % (m.group(1) if m else "none"))
if "variant/thread_support=true" in src:
    sys.exit("thread_support must stay false (artifact hosting lacks COOP/COEP headers)")

if not os.path.isdir(TPL_DIR):
    sys.exit("export templates not installed: %s" % TPL_DIR)
web_tpls = [f for f in os.listdir(TPL_DIR) if f.startswith("web_") and f.endswith(".zip")]
if not web_tpls:
    sys.exit("no web_*.zip template in %s" % TPL_DIR)

print("web export preset OK; templates installed (%s)" % ", ".join(sorted(web_tpls)))
