#!/usr/bin/env bash
# MAD.Council sandbox — bash wrapper (macOS / Linux / Git Bash on Windows)
# See MAD/operations/sandbox-testing.md for design.
# Mirror of run-sandbox.ps1 — same semantics.

set -euo pipefail

cleanup=0
skip_build=0
skip_category=''

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cleanup)       cleanup=1; shift ;;
        --skip-build)    skip_build=1; shift ;;
        --skip-category) skip_category="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--cleanup] [--skip-build] [--skip-category cat,cat,...]"
            exit 0 ;;
        *) echo "Unknown argument: $1"; exit 2 ;;
    esac
done

docker_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mad_root="$(cd "$docker_dir/.." && pwd)"
report_dir="$docker_dir/reports"

mkdir -p "$report_dir"

timestamp="$(date -u +%Y%m%d-%H%M%S)"
session_id="$(uuidgen 2>/dev/null | tr -d '-' | head -c 8 || \
              od -An -N4 -x /dev/urandom | tr -d ' \n')"
report_file="smoke-${timestamp}-${session_id}.json"

echo "=========================================================="
echo " MAD.Council sandbox — run ${session_id}"
echo "=========================================================="
echo "  Docker dir : $docker_dir"
echo "  MAD root   : $mad_root"
echo "  Report dir : $report_dir"
echo "  Session    : $session_id"
echo

# 1. Docker availability
if ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
    echo "ERROR: docker not available. Install Docker Desktop / Docker Engine." >&2
    exit 2
fi

# 2. Build
if [[ "$skip_build" -eq 0 ]]; then
    echo "-> Building image..."
    docker build -t mad-sandbox:latest -f "${docker_dir}/Dockerfile" "$docker_dir"
else
    echo "-> Skipping build (--skip-build)"
fi

# 3. Run
echo "-> Running sandbox..."
set +e
docker run --rm \
    --name "mad-sandbox-${session_id}" \
    --read-only \
    --tmpfs /tmp:size=64m \
    -v "${mad_root}:/mad:ro" \
    -v "${report_dir}:/mad-report" \
    -e "SANDBOX_SESSION_ID=${session_id}" \
    -e "SANDBOX_SKIP_CATEGORY=${skip_category}" \
    mad-sandbox:latest \
    -ReportPath "/mad-report/${report_file}" \
    -MadRoot /mad
run_exit=$?
set -e

# 4. Report summary
echo
echo "=========================================================="
report_path="${report_dir}/${report_file}"
if [[ -f "$report_path" ]]; then
    pass=$(jq -r '.summary.pass // 0'  "$report_path")
    fail=$(jq -r '.summary.fail // 0'  "$report_path")
    warn=$(jq -r '.summary.warn // 0'  "$report_path")
    skip=$(jq -r '.summary.skip // 0'  "$report_path")
    echo " Results: ${pass} pass / ${fail} fail / ${warn} warn / ${skip} skip"
    echo " Report : ${report_path}"
else
    echo "WARN: no report file produced at ${report_path}" >&2
fi

# 5. Cleanup
if [[ "$cleanup" -eq 1 ]]; then
    echo "-> Cleanup: removing image + build cache..."
    docker image rm mad-sandbox:latest >/dev/null 2>&1 || true
    docker builder prune -f >/dev/null 2>&1 || true
    echo "   Image + cache removed."
fi

echo "=========================================================="
exit "$run_exit"
