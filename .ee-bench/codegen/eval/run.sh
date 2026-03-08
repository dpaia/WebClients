#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${EE_BENCH_PROJECT_ROOT:-/app}"
EVAL_DIR="/ee-bench/eval"
SUBMISSION_DIR="/ee-bench/submission"

# --- Environment from Dockerfile (rendered from dockerfile_env_vars) ---
export DEBIAN_FRONTEND="noninteractive"
export PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"
export UV_HTTP_TIMEOUT="60"

# --- Reset to base commit ---
cd "$PROJECT_ROOT"
git reset --hard "9b35b414f77c6165550550fdda8b25bbc74aac7b" 2>/dev/null
git checkout "9b35b414f77c6165550550fdda8b25bbc74aac7b" 2>/dev/null
git clean -fd 2>/dev/null

# --- Fetch commits referenced by before_repo_set_cmd ---

git fetch origin 1501eb765873b2884b6f1944fd242ecfc9d6b103 2>/dev/null || true

# --- before_repo_set_cmd (from HF metadata, may be empty) ---
git reset --hard 9b35b414f77c6165550550fdda8b25bbc74aac7b
git clean -fd 
git checkout 9b35b414f77c6165550550fdda8b25bbc74aac7b 
git checkout 1501eb765873b2884b6f1944fd242ecfc9d6b103 -- packages/components/components/smartBanner/SmartBanner.test.tsx

# --- Apply evaluation data (test patch) ---
if [ -f "$EVAL_DIR/test_patch.diff" ]; then
  git apply -v "$EVAL_DIR/test_patch.diff" 2>/dev/null || true
fi

# --- Apply candidate submission ---
if [ -f "$SUBMISSION_DIR/patch.diff" ]; then
  git apply -v "$SUBMISSION_DIR/patch.diff" 2>/dev/null || true
fi

# --- Run tests via SWE-bench Pro run script ---

bash "$EVAL_DIR/scripts/run_script.sh" "components/smartBanner/SmartBanner.test.ts,packages/components/components/smartBanner/SmartBanner.test.tsx" \
  > /tmp/stdout.log 2> /tmp/stderr.log || true


# --- Parse results ---
python3 "$EVAL_DIR/scripts/parser.py" /tmp/stdout.log /tmp/stderr.log /tmp/output.json

# --- Convert parser output to EE-bench JSON v2.0 format ---
python3 -c "
import json, sys, datetime
with open('/tmp/output.json') as f:
    data = json.load(f)
stdout = open('/tmp/stdout.log').read()
stderr = open('/tmp/stderr.log').read()

passed = [t for t in data.get('tests', []) if t['status'] == 'PASSED']
failed = [t for t in data.get('tests', []) if t['status'] in ('FAILED', 'ERROR')]
skipped = [t for t in data.get('tests', []) if t['status'] == 'SKIPPED']

summary = {
    'total': len(data.get('tests', [])),
    'passed': len(passed),
    'failed': len(failed),
    'errors': 0,
    'skipped': len(skipped),
}
passed_tests = [{'name': t['name']} for t in passed]
failed_tests = [{'name': t['name']} for t in failed]

result = {
    'schema_version': '2.0',
    'command': 'run',
    'status': 'success',
    'timestamp': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'criteria': [
        {
            'criterion': 'patch_applied',
            'status': 'pass',
        },
        {
            'criterion': 'compilation',
            'status': 'pass',
        },
        {
            'criterion': 'tests',
            'status': 'pass' if not failed else 'fail',
            'summary': summary,
            'passed_tests': passed_tests,
            'failed_tests': failed_tests,
        },
    ],
    'stdout': stdout,
    'stderr': stderr,
    # Deprecated v1.0 fields for backward compat
    'patch_applied': True,
    'compile_success': True,
    'summary': summary,
    'passed_tests': passed_tests,
    'failed_tests': failed_tests,
}
print(json.dumps(result))
"