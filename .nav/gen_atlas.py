#!/usr/bin/env python3
"""ATLAS generator — scans the OpsHub repo and emits a machine-readable index
plus per-feature mechanical inventory cards. Judgment sections are hand-authored
elsewhere; this only emits what is *derivable from the code* so it never fabricates."""
import os, re, json, subprocess, pathlib, collections

# Resolve from this script's own location, never a hardcoded absolute path: the
# repo is worked in through git worktrees under `.claude/worktrees/`, and an
# absolute ROOT made every run from a worktree silently regenerate the MAIN
# checkout's cards from the MAIN checkout's code — dirtying a tree nobody was
# editing while leaving the worktree's own cards stale.
ROOT = pathlib.Path(__file__).resolve().parent.parent
NAV = ROOT / ".nav"
(NAV / "features").mkdir(parents=True, exist_ok=True)

FEATURES_DIR = ROOT / "lib" / "features"
features = sorted([p.name for p in FEATURES_DIR.iterdir() if p.is_dir()])

def dart_files(base):
    return sorted(str(p.relative_to(ROOT)) for p in base.rglob("*.dart"))

def layer_of(rel):
    if "/data/datasources/" in rel: return "data:datasource"
    if "/data/models/" in rel: return "data:model"
    if "/data/repositories/" in rel: return "data:repository-impl"
    if "/data/" in rel: return "data:other"
    if "/domain/entities/" in rel: return "domain:entity"
    if "/domain/repositories/" in rel: return "domain:repository-contract"
    if "/domain/usecases/" in rel: return "domain:usecase"
    if "/domain/" in rel: return "domain:other"
    if "/presentation/cubit/" in rel: return "presentation:cubit"
    if "/presentation/pages/" in rel: return "presentation:page"
    if "/presentation/widgets/" in rel: return "presentation:widget"
    if "/presentation/" in rel: return "presentation:other"
    return "other"

# ---- Firestore collections from rules ----
rules = (ROOT / "firestore.rules").read_text()
collections = re.findall(r"match /([a-zA-Z_]+)/\{", rules)
collections = [c for c in collections if c not in ("databases",)]
subcols = re.findall(r"match /([a-zA-Z_]+)/\{[^}]+\}\s*\{[^m]*?match /([a-zA-Z_]+)/\{", rules)

# ---- Cloud Functions ----
fn_src = (ROOT / "functions" / "index.js").read_text()
extra_fns = ""
for f in ("attendance_auto_close.js","automation_run.js","recurring_task_deadline.js"):
    p = ROOT / "functions" / f
    if p.exists(): extra_fns += p.read_text()
functions = sorted(set(re.findall(r"exports\.([a-zA-Z0-9_]+)\s*=", fn_src + extra_fns)))

# ---- Routes ----
route_src = (ROOT / "lib" / "core" / "routes" / "route_names.dart").read_text()
route_consts = dict(re.findall(r"static const String (\w+)\s*=\s*'([^']+)'", route_src))

# ---- Tests ----
test_files = sorted(str(p.relative_to(ROOT)) for p in (ROOT/"test").rglob("*_test.dart"))

# ---- Docs specs / ADRs ----
specs = sorted(p.name for p in (ROOT/"docs"/"design").glob("*.md")) if (ROOT/"docs"/"design").exists() else []
adrs = sorted(p.name for p in (ROOT/"docs"/"decisions").glob("ADR-*.md")) if (ROOT/"docs"/"decisions").exists() else []

# Keyword map: feature -> tokens used to associate routes/collections/functions/tests/specs
KW = {
 "admin": ["admin","createUserAccount","adminReset","user_admin"],
 "attendance": ["attendance","autoCloseAttendance","geofence","clock"],
 "audit": ["audit_log","audit"],
 "auth": ["auth","login","password","profileCompletion","splash","welcome","force","createUserAccount","claimFcmToken","user"],
 "branch": ["branch","branches"],
 "cases": ["case","cases","onCase"],
 "chat": ["chat","conversation"],
 "communications": ["broadcast","communications","sendBroadcast","runBroadcast"],
 "employee": ["employee","home","my-tasks","mySchedule"],
 "manager": ["manager"],
 "notifications": ["notification","sendNotification","onNotification","runTaskReminders","reminder","fcm"],
 "operations": ["operations","automationRuns","automation","generateShiftTask","autoEndRecurring","onRecurringTemplate"],
 "profile": ["profile"],
 "requests": ["request","requests","onRequest"],
 "schedule": ["schedule","shift","swap","weekly","approveSwap"],
 "settings": ["settings"],
 "statistics": ["statistic","analytics","usageStats"],
 "task": ["task","tasks","recurringTask","taskHousekeeping","taskReminder","generateShiftTask"],
}

def match(tokens, hay):
    h = hay.lower()
    return any(t.lower() in h for t in tokens)

index = {
  "generated_by": ".nav/gen (regenerate: python3 .nav/gen_atlas.py)",
  "layer_model": ["presentation (page/cubit/widget)","domain (entity/usecase/repository-contract)","data (model/repository-impl/datasource)"],
  "di_locator": "lib/core/di/injection.dart  (AppDependencies — hand-rolled static locator, NOT GetIt)",
  "router": "lib/core/routes/app_router.dart  (guards: _isAdminArea/_isManagerArea/_isCommunicationsArea/_isAttendanceReviewArea + _redirect)",
  "route_names": "lib/core/routes/route_names.dart",
  "firestore_rules": "firestore.rules",
  "storage_rules": "storage.rules",
  "functions": "functions/index.js (+ attendance_auto_close.js, automation_run.js, recurring_task_deadline.js)",
  "collections": collections,
  "cloud_functions": functions,
  "adrs": adrs,
  "design_specs": specs,
  "features": {},
}

for f in features:
    base = FEATURES_DIR / f
    files = dart_files(base)
    by_layer = collections_ = collections
    layers = collections.__class__  # noop
    grouped = collections_dict = {}
    grouped = {}
    for rel in files:
        grouped.setdefault(layer_of(rel), []).append(rel)
    toks = KW.get(f, [f])
    froutes = {k:v for k,v in route_consts.items() if match(toks, k) or match(toks, v)}
    fcols = [c for c in collections if match(toks, c)]
    ffns = [fn for fn in functions if match(toks, fn)]
    ftests = [t for t in test_files if match(toks, os.path.basename(t))]
    fspecs = [s for s in specs if match(toks, s)]
    index["features"][f] = {
        "path": f"lib/features/{f}/",
        "file_count": len(files),
        "layers": grouped,
        "routes": froutes,
        "collections": fcols,
        "cloud_functions": ffns,
        "tests": ftests,
        "design_specs": fspecs,
    }

(NAV / "atlas.index.json").write_text(json.dumps(index, indent=2))
print("wrote atlas.index.json:", len(features), "features,", sum(len(dart_files(FEATURES_DIR/f)) for f in features), "feature files")
print("collections:", len(collections), "functions:", len(functions), "tests:", len(test_files))

# ------- emit per-feature mechanical cards -------
LAYER_ORDER = ["presentation:page","presentation:cubit","presentation:widget","presentation:other",
               "domain:entity","domain:usecase","domain:repository-contract","domain:other",
               "data:repository-impl","data:datasource","data:model","data:other","other"]

def card(f):
    d = index["features"][f]
    L = []
    A = L.append
    A(f"<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py")
    A(f"     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->")
    A(f"# 📍 FEATURE CARD — `{f}`")
    A("")
    A(f"> `lib/features/{f}/` · **{d['file_count']} files** · layer-complete clean-architecture slice")
    A("")
    A("## Entry points (route → screen)")
    if d["routes"]:
        A("| Route const | Path | Guard/notes |")
        A("|---|---|---|")
        for k,v in sorted(d["routes"].items(), key=lambda x:x[1]):
            A(f"| `RouteNames.{k}` | `{v}` |  |")
    else:
        A("_No direct routes — reached via shared widgets or another feature._")
    A("")
    A("## Owner files (by layer)")
    for layer in LAYER_ORDER:
        fs = d["layers"].get(layer)
        if not fs: continue
        A(f"**{layer}**")
        for rel in fs:
            A(f"- `{rel}`")
        A("")
    A("## Backend surface")
    A(f"- **Firestore collections:** {', '.join('`'+c+'`' for c in d['collections']) or '—'}")
    A(f"- **Cloud Functions:** {', '.join('`'+c+'`' for c in d['cloud_functions']) or '—'}")
    A(f"- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media")
    A(f"- **Design spec(s):** {', '.join('`docs/design/'+s+'`' for s in d['design_specs']) or '—'}")
    A("")
    A("## Tests")
    if d["tests"]:
        for t in d["tests"]:
            A(f"- `{t}`")
    else:
        A("_None matched by name — verify before assuming uncovered._")
    A("")
    A("## Standard data flow (this feature follows the universal pattern)")
    A("```")
    A("UI (page/widget)")
    A("  → Cubit.method()            presentation/cubit/")
    A("    → UseCase.call()          domain/usecases/")
    A("      → Repository (contract) domain/repositories/")
    A("        → RepositoryImpl      data/repositories/")
    A("          → RemoteDatasource  data/datasources/   → Firestore/Functions/API")
    A("  ← Model.fromJson → Entity ← Stream/Future ← Cubit emits state → UI rebuilds")
    A("```")
    A("")
    A("<!-- ═══════════════ HAND-AUTHORED INTELLIGENCE (edit freely) ═══════════════ -->")
    A("")
    A("## Purpose")
    A("_TODO: one-paragraph what & why. See `docs/design/` spec above if present._")
    A("")
    A("## ⚠️ Dangerous areas / invariants")
    A("_TODO: what breaks if you touch this. Cross-check `.nav/05_DANGER.md`._")
    A("")
    A("## 🧩 Extension points")
    A("_TODO: where to plug in new behavior without forking._")
    A("")
    A("## 🔗 Related")
    A("_TODO: sibling features, shared core widgets, ADRs._")
    return "\n".join(L)

HAND_MARKER = "<!-- ═══════════════ HAND-AUTHORED INTELLIGENCE (edit freely) ═══════════════ -->"

def write_card(path, fresh):
    """Rewrite the mechanical half, **keep whatever a human wrote below the
    marker**. The header has always promised this ("Do not delete that section")
    but the generator used to emit the TODO placeholders unconditionally, so
    every regeneration silently erased the judgment the ATLAS protocol tells
    agents to read first — which is why the cards were a field of TODOs."""
    if path.exists():
        old = path.read_text()
        if HAND_MARKER in old:
            kept = old.split(HAND_MARKER, 1)[1]
            # Only carry it over when it holds more than the seeded TODOs.
            if kept.replace("_TODO", "").count("##") and "_TODO:" not in kept:
                fresh = fresh.split(HAND_MARKER, 1)[0] + HAND_MARKER + kept
    path.write_text(fresh)

for f in features:
    write_card(NAV / "features" / f"{f}.md", card(f))
print("wrote", len(features), "feature cards")
