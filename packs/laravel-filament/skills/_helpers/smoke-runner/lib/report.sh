#!/usr/bin/env bash
# shellcheck shell=bash
# Markdown report generator. Sourced; do not execute directly.

REPORT_FILE=""
REPORT_SCENARIO=""
REPORT_START_TS=0
REPORT_STAGES=()
REPORT_RESULT="UNKNOWN"

report_init() {
    REPORT_SCENARIO="$1"
    REPORT_FILE="$2"
    REPORT_START_TS=$SECONDS
    REPORT_STAGES=()
    REPORT_RESULT="UNKNOWN"
    {
        echo "# Smoke report: ${REPORT_SCENARIO}"
        echo
        echo "- started: $(date -Iseconds)"
        echo "- host: $(uname -srm)"
        echo "- docker: $(docker --version 2>/dev/null || echo n/a)"
        echo "- php: $(php -r 'echo PHP_VERSION;' 2>/dev/null || echo n/a)"
        echo "- node: $(node --version 2>/dev/null || echo n/a)"
        echo
        echo "## Stages"
        echo
        echo "| # | Stage | Result | Duration |"
        echo "|---|-------|--------|----------|"
    } > "$REPORT_FILE"
}

report_stage() {
    local stage="$1"; local result="$2"; local duration="$3"
    local n=$((${#REPORT_STAGES[@]} + 1))
    REPORT_STAGES+=("$stage|$result|$duration")
    echo "| $n | $stage | $result | $duration |" >> "$REPORT_FILE"
    echo "[stage $n] $stage -> $result ($duration)"
}

report_note() {
    local msg="$1"
    {
        echo
        echo "> $msg"
    } >> "$REPORT_FILE"
}

report_finalize() {
    local total_s=$((SECONDS - REPORT_START_TS))
    local total_fail=0
    for entry in "${REPORT_STAGES[@]}"; do
        local r="${entry#*|}"; r="${r%%|*}"
        [[ "$r" == "PASS" ]] || total_fail=$((total_fail + 1))
    done
    if [[ "$total_fail" -eq 0 ]]; then
        REPORT_RESULT="PASS"
    else
        REPORT_RESULT="FAIL"
    fi
    {
        echo
        echo "## Summary"
        echo
        echo "- result: **${REPORT_RESULT}**"
        echo "- stages: ${#REPORT_STAGES[@]}"
        echo "- failures: ${total_fail}"
        echo "- total wall-clock: ${total_s}s"
        echo "- finished: $(date -Iseconds)"
    } >> "$REPORT_FILE"
    echo "==> Report finalized: $REPORT_FILE (result=$REPORT_RESULT, ${total_s}s)"
}
