#!/usr/bin/env bash
# =============================================================================
# OpenClaw Gatekeeper QA Module
# Phase 5: The Gatekeeper Loop (Implementation Plan §6)
#
# Autonomous verification loop that audits all artifacts BEFORE final delivery:
#   - Step A: Ingest artifacts from execution agents
#   - Step B: Audit against Success Criteria Register
#     Check 1: Code Integrity (syntax validation)
#     Check 2: Visual Integrity (image vs text detection)
#     Check 3: Security (API key leak scan — Zero-Tolerance)
#     Check 4: Requirement Coverage (criteria checklist)
#   - Branch: PASS → package; FAIL → correction loop (max 3 retries)
#
# Usage:
#   bash scripts/gatekeeper.sh <artifacts_dir> <criteria_file>
#   bash scripts/gatekeeper.sh --test-mode tests/fixtures/sample_artifact.json
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

MAX_RETRIES=3
TEST_MODE=false

# --- Colour Helpers ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ PASS${NC}  $*"; }
fail() { echo -e "${RED}❌ FAIL${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠️  WARN${NC}  $*"; }
info() { echo -e "${CYAN}ℹ️  INFO${NC}  $*"; }

# =============================================================================
# Check 1: Code Integrity
# =============================================================================
# Validates syntax of code artifacts based on file extension.
# Returns 0 if all files pass, 1 if any fail.
audit_code_integrity() {
    local artifacts_dir="$1"
    local failures=0

    echo -e "\n${MAGENTA}  Check 1: Code Integrity${NC}"
    echo "  ─────────────────────────"

    # JavaScript / TypeScript syntax check
    for f in $(find "${artifacts_dir}" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) 2>/dev/null); do
        local basename_f
        basename_f=$(basename "${f}")
        if command -v node &>/dev/null; then
            if node --check "${f}" 2>/dev/null; then
                pass "  ${basename_f} — Syntax OK"
            else
                fail "  ${basename_f} — Syntax ERROR"
                failures=$((failures + 1))
            fi
        else
            # Fallback: basic brace/bracket balance check
            local open_braces close_braces
            open_braces=$(grep -o '{' "${f}" 2>/dev/null | wc -l | tr -d ' ')
            close_braces=$(grep -o '}' "${f}" 2>/dev/null | wc -l | tr -d ' ')
            if [[ "${open_braces}" -eq "${close_braces}" ]]; then
                pass "  ${basename_f} — Bracket balance OK (${open_braces} pairs)"
            else
                fail "  ${basename_f} — Bracket MISMATCH ({: ${open_braces}, }: ${close_braces})"
                failures=$((failures + 1))
            fi
        fi
    done

    # Python syntax check
    for f in $(find "${artifacts_dir}" -type f -name "*.py" 2>/dev/null); do
        local basename_f
        basename_f=$(basename "${f}")
        if command -v python3 &>/dev/null; then
            if python3 -m py_compile "${f}" 2>/dev/null; then
                pass "  ${basename_f} — Syntax OK"
            else
                fail "  ${basename_f} — Syntax ERROR"
                failures=$((failures + 1))
            fi
        fi
    done

    # Go syntax check
    for f in $(find "${artifacts_dir}" -type f -name "*.go" 2>/dev/null); do
        local basename_f
        basename_f=$(basename "${f}")
        if command -v gofmt &>/dev/null; then
            if gofmt -e "${f}" >/dev/null 2>&1; then
                pass "  ${basename_f} — Syntax OK"
            else
                fail "  ${basename_f} — Syntax ERROR"
                failures=$((failures + 1))
            fi
        fi
    done

    # JSON syntax check
    for f in $(find "${artifacts_dir}" -type f -name "*.json" 2>/dev/null); do
        local basename_f
        basename_f=$(basename "${f}")
        if command -v python3 &>/dev/null; then
            if python3 -c "import json; json.load(open('${f}'))" 2>/dev/null; then
                pass "  ${basename_f} — Valid JSON"
            else
                fail "  ${basename_f} — Invalid JSON"
                failures=$((failures + 1))
            fi
        fi
    done

    # Shell script syntax check
    for f in $(find "${artifacts_dir}" -type f -name "*.sh" 2>/dev/null); do
        local basename_f
        basename_f=$(basename "${f}")
        if bash -n "${f}" 2>/dev/null; then
            pass "  ${basename_f} — Syntax OK"
        else
            fail "  ${basename_f} — Syntax ERROR"
            failures=$((failures + 1))
        fi
    done

    local file_count
    file_count=$(find "${artifacts_dir}" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "${file_count}" -eq 0 ]]; then
        warn "  No code artifacts found in ${artifacts_dir}"
    fi

    return ${failures}
}

# =============================================================================
# Check 2: Visual Integrity
# =============================================================================
# Verifies that image artifacts are actual image files, not text descriptions.
audit_visual_integrity() {
    local artifacts_dir="$1"
    local failures=0

    echo -e "\n${MAGENTA}  Check 2: Visual Integrity${NC}"
    echo "  ─────────────────────────"

    local image_files
    image_files=$(find "${artifacts_dir}" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" -o -name "*.gif" -o -name "*.svg" -o -name "*.bmp" \) 2>/dev/null)

    if [[ -z "${image_files}" ]]; then
        info "  No image artifacts to verify"
        return 0
    fi

    while IFS= read -r f; do
        local basename_f
        basename_f=$(basename "${f}")
        local file_type

        if command -v file &>/dev/null; then
            file_type=$(file --mime-type -b "${f}" 2>/dev/null || echo "unknown")
            if echo "${file_type}" | grep -qE '^image/'; then
                pass "  ${basename_f} — Valid image (${file_type})"
            elif echo "${file_type}" | grep -qE '^text/'; then
                fail "  ${basename_f} — TEXT file masquerading as image (${file_type})"
                fail "  → Nano Banana Pro may have generated a text description instead of an image"
                failures=$((failures + 1))
            else
                warn "  ${basename_f} — Unknown type: ${file_type}"
            fi
        else
            # Fallback: check file size (images are typically > 1KB)
            local file_size
            file_size=$(wc -c < "${f}" 2>/dev/null | tr -d ' ')
            if [[ ${file_size} -gt 1024 ]]; then
                pass "  ${basename_f} — Size check OK (${file_size} bytes)"
            else
                warn "  ${basename_f} — Suspiciously small (${file_size} bytes)"
            fi
        fi
    done <<< "${image_files}"

    return ${failures}
}

# =============================================================================
# Check 3: Security — API Key Leak Detection (ZERO-TOLERANCE)
# =============================================================================
# Scans ALL artifacts for any leaked API keys from .env.
# This check has ZERO tolerance — a single leak fails the entire audit.
audit_security() {
    local artifacts_dir="$1"
    local failures=0

    echo -e "\n${MAGENTA}  Check 3: Security (API Key Leak Scan)${NC}"
    echo "  ─────────────────────────"

    if [[ ! -f "${ENV_FILE}" ]]; then
        warn "  Cannot perform security audit — .env not found"
        return 0
    fi

    # Extract actual key values from .env (skip comments, empty lines, redacted values)
    local key_patterns=()
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ -z "${key}" || "${key}" == \#* ]] && continue
        # Strip leading/trailing whitespace
        value=$(echo "${value}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Skip empty or redacted values
        [[ -z "${value}" || "${value}" == "__OPENCLAW_REDACTED__" ]] && continue
        # Only check actual secret keys (minimum 16 chars to avoid false positives)
        if [[ ${#value} -ge 16 ]]; then
            key_patterns+=("${value}")
        fi
    done < <(grep -E '^[A-Z_]+=.' "${ENV_FILE}" 2>/dev/null)

    if [[ ${#key_patterns[@]} -eq 0 ]]; then
        warn "  No extractable key patterns found in .env"
        return 0
    fi

    # Scan every file in the artifacts directory
    local scanned=0
    for f in $(find "${artifacts_dir}" -type f 2>/dev/null); do
        # Skip binary files
        if command -v file &>/dev/null; then
            local mime
            mime=$(file --mime-type -b "${f}" 2>/dev/null || echo "")
            if echo "${mime}" | grep -qE '^(image/|audio/|video/|application/octet)'; then
                continue
            fi
        fi

        scanned=$((scanned + 1))
        local basename_f
        basename_f=$(basename "${f}")

        for pattern in "${key_patterns[@]}"; do
            # Use first 20 chars of key as search pattern (sufficient and avoids regex issues)
            local search_pattern="${pattern:0:20}"
            if grep -qF "${search_pattern}" "${f}" 2>/dev/null; then
                fail "  🚨 CRITICAL: API key LEAKED in ${basename_f}"
                fail "  → Zero-Tolerance Policy: This artifact MUST be regenerated"
                failures=$((failures + 1))
                break  # One leak per file is enough to flag it
            fi
        done
    done

    if [[ ${failures} -eq 0 ]]; then
        pass "  ${scanned} file(s) scanned — No API key leaks detected"
    fi

    return ${failures}
}

# =============================================================================
# Check 4: Requirement Coverage
# =============================================================================
# Validates that all items in the Success Criteria Register are addressed.
audit_requirement_coverage() {
    local artifacts_dir="$1"
    local criteria_file="${2:-}"
    local failures=0

    echo -e "\n${MAGENTA}  Check 4: Requirement Coverage${NC}"
    echo "  ─────────────────────────"

    if [[ -z "${criteria_file}" || ! -f "${criteria_file}" ]]; then
        warn "  No criteria file provided — skipping coverage check"
        info "  (Provide a JSON criteria file for full validation)"
        return 0
    fi

    # Parse criteria from JSON file
    local criteria_count=0
    local met_count=0

    if command -v python3 &>/dev/null; then
        criteria_count=$(python3 -c "
import json, sys
with open('${criteria_file}') as f:
    d = json.load(f)
criteria = d.get('criteria', [])
print(len(criteria))
" 2>/dev/null || echo "0")

        # Check each criterion against artifact contents
        local criteria_list
        criteria_list=$(python3 -c "
import json
with open('${criteria_file}') as f:
    d = json.load(f)
for c in d.get('criteria', []):
    print(c.get('description', ''))
" 2>/dev/null)

        while IFS= read -r criterion; do
            [[ -z "${criterion}" ]] && continue
            # Search for evidence of this criterion in artifacts
            if grep -rqli "$(echo "${criterion}" | head -c 30)" "${artifacts_dir}" 2>/dev/null; then
                pass "  ✓ ${criterion}"
                met_count=$((met_count + 1))
            else
                fail "  ✗ ${criterion} — NOT FOUND in artifacts"
                failures=$((failures + 1))
            fi
        done <<< "${criteria_list}"
    fi

    if [[ ${criteria_count} -gt 0 ]]; then
        local coverage_pct=$((met_count * 100 / criteria_count))
        if [[ ${coverage_pct} -eq 100 ]]; then
            pass "  Coverage: ${coverage_pct}% (${met_count}/${criteria_count} criteria met)"
        else
            fail "  Coverage: ${coverage_pct}% (${met_count}/${criteria_count} criteria met) — 100% REQUIRED"
        fi
    fi

    return ${failures}
}

# =============================================================================
# Correction Loop
# =============================================================================
# If any audit fails, generates correction instructions and returns them.
generate_corrections() {
    local check_name="$1"
    local details="$2"
    local agent_id="$3"

    cat <<EOF
{
    "correction_type": "${check_name}",
    "details": "${details}",
    "re_delegate_to": "${agent_id}",
    "instruction": "Fix the identified ${check_name} issue and resubmit the artifact.",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# =============================================================================
# Full Audit Pipeline
# =============================================================================
run_full_audit() {
    local artifacts_dir="$1"
    local criteria_file="${2:-}"
    local retry_count="${3:-0}"

    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║     🛡️  OpenClaw Gatekeeper — Audit Phase              ║"
    echo "║     Actor: Claude Sonnet 4.5 Thinking                   ║"
    echo "║     Attempt: $((retry_count + 1)) / ${MAX_RETRIES}                                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"

    local total_failures=0

    echo -e "\n${CYAN}Step A: Ingesting artifacts from ${artifacts_dir}${NC}"
    local artifact_count
    artifact_count=$(find "${artifacts_dir}" -type f 2>/dev/null | wc -l | tr -d ' ')
    info "  Found ${artifact_count} artifact(s)"

    echo -e "\n${CYAN}Step B: Line-by-line Audit${NC}"

    # Run all 4 audit checks
    local code_failures=0
    audit_code_integrity "${artifacts_dir}" || code_failures=$?
    total_failures=$((total_failures + code_failures))

    local visual_failures=0
    audit_visual_integrity "${artifacts_dir}" || visual_failures=$?
    total_failures=$((total_failures + visual_failures))

    local security_failures=0
    audit_security "${artifacts_dir}" || security_failures=$?
    total_failures=$((total_failures + security_failures))

    local coverage_failures=0
    audit_requirement_coverage "${artifacts_dir}" "${criteria_file}" || coverage_failures=$?
    total_failures=$((total_failures + coverage_failures))

    # Branch Logic
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Gatekeeper Verdict"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ ${total_failures} -eq 0 ]]; then
        echo ""
        echo -e "  ${GREEN}Criteria_Met == TRUE${NC}"
        echo -e "  ${GREEN}✅ ALL AUDITS PASSED — Proceeding to Package & Release${NC}"
        echo ""
        echo "GATEKEEPER_RESULT=PASS"
        return 0
    else
        echo ""
        echo -e "  ${RED}Criteria_Met == FALSE${NC}"
        echo -e "  ${RED}❌ ${total_failures} audit failure(s) detected${NC}"

        if [[ ${retry_count} -lt ${MAX_RETRIES} ]]; then
            echo ""
            echo -e "  ${YELLOW}→ Entering Correction Loop (attempt $((retry_count + 2)))${NC}"

            # Generate correction instructions
            if [[ ${security_failures} -gt 0 ]]; then
                generate_corrections "security" "API key leak detected in generated artifacts" "coder"
            fi
            if [[ ${code_failures} -gt 0 ]]; then
                generate_corrections "code_integrity" "Syntax errors in generated code" "architect"
            fi
            if [[ ${visual_failures} -gt 0 ]]; then
                generate_corrections "visual_integrity" "Image artifacts are text, not images" "imager"
            fi
            if [[ ${coverage_failures} -gt 0 ]]; then
                generate_corrections "requirement_coverage" "Not all success criteria met" "manager"
            fi

            echo ""
            echo "GATEKEEPER_RESULT=RETRY"
        else
            echo ""
            echo -e "  ${RED}🛑 MAX RETRIES (${MAX_RETRIES}) EXCEEDED — Escalating to Manager${NC}"
            echo "GATEKEEPER_RESULT=ESCALATE"
        fi
        return 1
    fi
}

# =============================================================================
# Test Mode
# =============================================================================
run_test_mode() {
    local fixture_file="$1"
    info "Running in TEST MODE with fixture: ${fixture_file}"

    # Create a temporary artifacts directory from the fixture
    local tmp_dir="/tmp/openclaw_gatekeeper_test_$$"
    mkdir -p "${tmp_dir}"
    trap "rm -rf '${tmp_dir}'" EXIT

    if [[ -f "${fixture_file}" ]]; then
        cp "${fixture_file}" "${tmp_dir}/"
    fi

    run_full_audit "${tmp_dir}" "" 0
}

# =============================================================================
# Main
# =============================================================================
main() {
    if [[ "${1:-}" == "--test-mode" ]]; then
        TEST_MODE=true
        shift
        run_test_mode "${1:-}"
    elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        echo "Usage:"
        echo "  bash scripts/gatekeeper.sh <artifacts_dir> [criteria_file]"
        echo "  bash scripts/gatekeeper.sh --test-mode <fixture_file>"
        exit 0
    else
        local artifacts_dir="${1:-}"
        local criteria_file="${2:-}"

        if [[ -z "${artifacts_dir}" ]]; then
            echo "ERROR: artifacts_dir is required" >&2
            exit 1
        fi

        if [[ ! -d "${artifacts_dir}" ]]; then
            echo "ERROR: ${artifacts_dir} is not a directory" >&2
            exit 1
        fi

        run_full_audit "${artifacts_dir}" "${criteria_file}" 0
    fi
}

main "$@"
