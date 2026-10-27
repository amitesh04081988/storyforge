#!/usr/bin/env bash
# Catch test-file and out-of-scope changes however they were made (Edit tool, shell redirect, sed -i,
# a script, a formatter). The edit-guard hook only sees the Edit and Write tools; this compares files.
#   guard.sh snapshot   record a hash of every tracked and untracked file, and a copy of each test file
#   guard.sh check      exit 0 when nothing locked changed since the snapshot; exit 1 and list violations
#   guard.sh restore    put test files back from the snapshot (and delete new ones); never touches production code
# Run from the project root. Take a snapshot at the start of `develop` and at the start of every `fix` cycle.
# Not treated as changes: generated output and logs (node_modules, dist, build, coverage, *.log, __pycache__,
# test-results, ...) plus anything in config `guard.ignore`; and snapshot files a test run creates for the
# first time (__snapshots__, *.snap, *-snapshots). Changing or deleting an EXISTING snapshot is still a
# test-lock violation, because that is how a failing snapshot test gets "fixed".
# Overrides: .storyforge/allow-test-edit, .storyforge/allow-scope-edit (then snapshot again).
set -uo pipefail
. "$(dirname "$0")/../hooks/lib.sh"
MODE="${1:-}"
case "$MODE" in snapshot|check|restore) ;; *) echo "usage: $0 snapshot|check|restore"; exit 1;; esac
git -C "$SF_PROJECT" rev-parse --git-dir >/dev/null 2>&1 || { echo "guard: not a git repo, nothing to compare"; exit 0; }
if sf_state_tracked; then echo "$SF_UNTRUSTED_MSG"; exit 1; fi
sf_find_python
if [ -z "$SF_PY" ]; then
  sf_allow_no_python && exit 0
  echo "$SF_NO_PY_MSG"; exit 1
fi
STORY=$(cat "$SF_STATE/story" 2>/dev/null || true)
TEST_GLOBS=$(sf_cfg test_globs $'**/*.test.*\n**/*.spec.*\ntests/**\ntest/**')
SCOPE_LOCK=$(sf_cfg scope_lock true)
GUARD_IGNORE=$(sf_cfg guard.ignore "")
ALLOW_TEST=$([ -f "$SF_STATE/allow-test-edit" ] && echo 1 || echo "")
ALLOW_SCOPE=$([ -f "$SF_STATE/allow-scope-edit" ] && echo 1 || echo "")
mkdir -p "$SF_STATE"
# shellcheck disable=SC2086
$SF_PY - "$MODE" "$SF_PROJECT" "$SF_STATE" "$STORY" "$TEST_GLOBS" "$SCOPE_LOCK" "$ALLOW_TEST" "$ALLOW_SCOPE" "$GUARD_IGNORE" <<'PY'
import os, sys, json, fnmatch, shutil, subprocess
mode, root, state, story, tglobs, scope_lock, allow_test, allow_scope, extra_ignore = sys.argv[1:10]
os.chdir(root)
base_file = os.path.join(state, "baseline.json")
copies = os.path.join(state, "baseline")

IGNORE = ["**/node_modules/**", "**/__pycache__/**", "*.pyc", "*.log", "*.tmp", "**/.DS_Store",
          "**/dist/**", "**/build/**", "**/coverage/**", "**/.next/**", "**/target/**",
          "**/test-results/**", "**/playwright-report/**", "**/.pytest_cache/**", ".claude/**"] + extra_ignore.splitlines()
SNAPSHOTS = ["**/__snapshots__/**", "*.snap", "**/*-snapshots/**"]

def m(p, g):
    g = g.strip()
    if not g or g.startswith("#"): return False
    if g.endswith("/"): g += "**"
    return fnmatch.fnmatch(p, g) or (g.startswith("**/") and fnmatch.fnmatch(p, g[3:]))
def is_test(p): return any(m(p, g) for g in tglobs.splitlines())
def is_ignored(p): return any(m(p, g) for g in IGNORE)
def is_snapshot(p): return any(m(p, g) for g in SNAPSHOTS)

def files():
    out = subprocess.run(["git", "ls-files", "-co", "--exclude-standard", "-z"], capture_output=True).stdout
    return sorted(x for x in out.decode("utf-8", "replace").split("\0")
                  if x and not x.startswith(".storyforge/") and not is_ignored(x) and os.path.isfile(x))

def hashes(paths):
    if not paths: return {}
    out = subprocess.run(["git", "hash-object", "--stdin-paths"], input="\n".join(paths).encode(), capture_output=True).stdout
    return dict(zip(paths, out.decode().split()))

if mode == "snapshot":
    cur = hashes(files())
    tests = [p for p in cur if is_test(p)]
    shutil.rmtree(copies, ignore_errors=True)
    for p in tests:
        dst = os.path.join(copies, p); os.makedirs(os.path.dirname(dst), exist_ok=True); shutil.copy2(p, dst)
    json.dump({"files": cur, "tests": tests}, open(base_file, "w"))
    print(f"guard: snapshot of {len(cur)} files, {len(tests)} test files")
    sys.exit(0)

if not os.path.isfile(base_file):
    print("guard: no snapshot. Run: guard.sh snapshot (at the start of develop and of each fix cycle)")
    sys.exit(2)
base = json.load(open(base_file))["files"]
cur = hashes(files())
changed = sorted({p for p in cur if base.get(p) != cur[p]} | {p for p in base if p not in cur})
# A snapshot file that did not exist at the snapshot is what a first test run writes: allowed.
new_snapshots = {p for p in changed if is_snapshot(p) and p not in base}
test_changed = [p for p in changed if is_test(p) and p not in new_snapshots]

if mode == "restore":
    for p in test_changed:
        if p in base:
            src = os.path.join(copies, p)
            if os.path.isfile(src):
                os.makedirs(os.path.dirname(p) or ".", exist_ok=True); shutil.copy2(src, p); print(f"restored {p}")
            else: print(f"cannot restore {p}: no copy in the snapshot")
        else:
            os.remove(p); print(f"removed new test file {p}")
    sys.exit(0)

# check
problems = []
if not allow_test:
    for p in test_changed:
        problems.append(f"TEST-LOCK  {p} was {'removed' if p not in cur else 'added' if p not in base else 'modified'} since the snapshot. Test files are locked; run guard.sh restore, then fix the production code.")
tolerated = ("package-lock.json", "yarn.lock", "pnpm-lock.yaml", "poetry.lock", "Cargo.lock", "Gemfile.lock", "composer.lock", "go.sum")
scope_file = f"docs/stories/{story}/scope.txt"
if scope_lock == "true" and not allow_scope and story and os.path.isfile(scope_file):
    globs = open(scope_file).read().splitlines() + [f"docs/stories/{story}/**", "docs/memory/**"]
    for p in changed:
        if p in new_snapshots or (is_test(p) and not allow_test): continue   # snapshots are allowed; tests are reported above
        if os.path.basename(p) in tolerated: continue
        if not any(m(p, g) for g in globs):
            problems.append(f"SCOPE      {p} changed but is outside scope.txt. Revert it, or record the reason in plan.md under Deviations so the orchestrator widens the scope.")
if problems:
    print("guard: locked files changed outside the allowed path")
    print("\n".join(problems))
    sys.exit(1)
print(f"guard: clean ({len(changed)} files changed since the snapshot, all allowed)")
PY
