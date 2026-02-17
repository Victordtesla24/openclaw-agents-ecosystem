#!/usr/bin/env bash
# =============================================================================
# OpenClaw Pre-Flight Validation Script
# Phase 1: Infrastructure & Authentication (Implementation Plan §2)
#
# Validates environment integrity before any agent initialization:
#   1. .env file existence and readability
#   2. All 6 critical API keys present (zero-knowledge — never prints values)
#   3. SSH connectivity to VPS (timeout-protected)
#   4. Docker container health, workspace mount, NODE_ENV, LOG_LEVEL
#   5. Configuration file integrity
#
# Usage:
#   bash scripts/preflight.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

# --- Colour Helpers ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass()  { echo -e "${GREEN}✅ PASS${NC}  $*"; }
fail()  { echo -e "${RED}❌ FAIL${NC}  $*"; FAILURES=$((FAILURES + 1)); }
warn()  { echo -e "${YELLOW}⚠️  WARN${NC}  $*"; }
info()  { echo -e "${CYAN}ℹ️  INFO${NC}  $*"; }

FAILURES=0
CHECKS=0

check_start() { CHECKS=$((CHECKS + 1)); }

# =============================================================================
# §2.1 — Environment File Validation
# =============================================================================
preflight_env_file() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Phase 1.1: Environment File Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    check_start
    if [[ -f "${ENV_FILE}" ]]; then
        pass ".env file found at ${ENV_FILE}"
    else
        fail ".env file MISSING at ${ENV_FILE}"
        echo "  → Cannot proceed without .env. Aborting."
        exit 1
    fi

    check_start
    if [[ -r "${ENV_FILE}" ]]; then
        pass ".env file is readable"
    else
        fail ".env file exists but is NOT readable (check permissions)"
        exit 1
    fi
}

# =============================================================================
# §2.2 — API Key Presence Validation (Zero-Knowledge)
# =============================================================================
preflight_api_keys() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Phase 1.2: API Key Presence (Zero-Knowledge)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local REQUIRED_KEYS=(
        "GEMINI_API_KEY"
        "OPENROUTER_API_KEY"
        "OPENAI_API_KEY"
        "PERPLEXITY_API_KEY"
        "HOSTINGER_API_TOKEN"
        "GATEWAY_TOKEN"
    )

    for key in "${REQUIRED_KEYS[@]}"; do
        check_start
        if grep -q "^${key}=" "${ENV_FILE}" 2>/dev/null; then
            local value
            value=$(grep "^${key}=" "${ENV_FILE}" | head -1 | cut -d'=' -f2-)
            if [[ -n "${value}" && "${value}" != "__OPENCLAW_REDACTED__" ]]; then
                pass "${key} — Present (value redacted)"
            else
                fail "${key} — Key exists but value is EMPTY or REDACTED"
            fi
        else
            fail "${key} — MISSING from .env"
        fi
    done
}

# =============================================================================
# §2.3 — SSH Connectivity Check (Live)
# =============================================================================
preflight_ssh() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Phase 1.3: VPS SSH Connectivity"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Source .env to get SSH variables
    # shellcheck disable=SC1090
    source "${ENV_FILE}"

    local ssh_user="${SSH_USER:-root}"
    local ssh_host="${SSH_HOST:-}"
    local ssh_port="${SSH_PORT:-22}"
    local ssh_key="${SSH_KEY_PATH:-}"

    check_start
    if [[ -z "${ssh_host}" ]]; then
        fail "SSH_HOST is not defined in .env"
        return
    fi

    local ssh_opts="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no"
    if [[ -n "${ssh_key}" && -f "${ssh_key}" ]]; then
        ssh_opts="${ssh_opts} -i ${ssh_key}"
    fi

    # shellcheck disable=SC2086
    if ssh ${ssh_opts} -p "${ssh_port}" "${ssh_user}@${ssh_host}" "echo SSH_OK" 2>/dev/null | grep -q "SSH_OK"; then
        pass "VPS connectivity verified (${ssh_user}@${ssh_host}:${ssh_port})"

        # Verify Docker container is running on VPS
        check_start
        local vps_docker
        # shellcheck disable=SC2086
        vps_docker=$(ssh ${ssh_opts} -p "${ssh_port}" "${ssh_user}@${ssh_host}" "docker ps --format '{{.Names}} {{.Status}}'" 2>/dev/null || true)
        if echo "${vps_docker}" | grep -qi "openclaw"; then
            local container_line
            container_line=$(echo "${vps_docker}" | grep -i "openclaw" | head -1)
            pass "VPS container running: ${container_line}"
        else
            fail "No OpenClaw container detected on VPS"
        fi
    else
        fail "VPS connection FAILED (${ssh_user}@${ssh_host}:${ssh_port})"
    fi
}

# =============================================================================
# §2.4 — Docker Container Health Checks (Local)
# =============================================================================
preflight_docker() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Phase 1.4: Docker Container Health"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Source .env for runtime variables
    # shellcheck disable=SC1090
    source "${ENV_FILE}"

    # Check docker is available
    check_start
    if ! command -v docker &>/dev/null; then
        warn "Docker CLI not found on local machine — VPS checks run via SSH"
        return
    fi

    # Check if OpenClaw container is running locally
    check_start
    local container_name
    container_name=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -i "openclaw" | head -1 || true)
    if [[ -n "${container_name}" ]]; then
        pass "OpenClaw container '${container_name}' is running"

        # Check container health status
        check_start
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "no-healthcheck")
        if [[ "${health_status}" == "healthy" ]]; then
            pass "Container health status: healthy"
        elif [[ "${health_status}" == "no-healthcheck" ]]; then
            warn "Container has no health check configured"
        else
            fail "Container health status: ${health_status}"
        fi

        # Check workspace volume mount
        check_start
        local mount_check
        mount_check=$(docker inspect -f '{{range .Mounts}}{{.Destination}} {{end}}' "${container_name}" 2>/dev/null || true)
        if echo "${mount_check}" | grep -q "/data"; then
            pass "Workspace volume mounted (/data detected in mounts)"
        else
            fail "Workspace volume NOT detected in container mounts"
        fi

        # Check NODE_ENV
        check_start
        local node_env
        node_env=$(docker exec "${container_name}" sh -c 'echo $NODE_ENV' 2>/dev/null || true)
        if [[ "${node_env}" == "production" ]]; then
            pass "NODE_ENV=production"
        elif [[ -n "${node_env}" ]]; then
            warn "NODE_ENV=${node_env} (expected: production)"
        else
            warn "NODE_ENV is not set in the container"
        fi

        # Check LOG_LEVEL
        check_start
        local log_level
        log_level=$(docker exec "${container_name}" sh -c 'echo $LOG_LEVEL' 2>/dev/null || true)
        if [[ "${log_level}" == "info" ]]; then
            pass "LOG_LEVEL=info"
        elif [[ -n "${log_level}" ]]; then
            warn "LOG_LEVEL=${log_level} (expected: info)"
        else
            warn "LOG_LEVEL is not set in the container"
        fi
    else
        info "No local OpenClaw container found — VPS container checks run via SSH"
    fi
}

# =============================================================================
# §2.5 — Configuration File Integrity
# =============================================================================
preflight_config() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Phase 1.5: Configuration File Integrity"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local CONFIG_FILE="${PROJECT_ROOT}/openclaw_config.json"
    local SKILLS_FILE="${PROJECT_ROOT}/docs/skills_matrix.md"
    local WORKFLOW_FILE="${PROJECT_ROOT}/docs/workflow.mermaid"
    local PROMPT_FILE="${PROJECT_ROOT}/docs/openclaw_prompt.md"

    # Check openclaw_config.json
    check_start
    if [[ -f "${CONFIG_FILE}" ]]; then
        if command -v python3 &>/dev/null; then
            if python3 -c "import json; json.load(open('${CONFIG_FILE}'))" 2>/dev/null; then
                pass "openclaw_config.json — Valid JSON"
            else
                fail "openclaw_config.json — INVALID JSON syntax"
            fi
        elif command -v jq &>/dev/null; then
            if jq empty "${CONFIG_FILE}" 2>/dev/null; then
                pass "openclaw_config.json — Valid JSON"
            else
                fail "openclaw_config.json — INVALID JSON syntax"
            fi
        else
            warn "openclaw_config.json — Cannot validate (no jq or python3)"
        fi
    else
        fail "openclaw_config.json — MISSING"
    fi

    # Check primary model is Claude Opus 4.6
    check_start
    if grep -q '"anthropic/claude-opus-4.6"' "${CONFIG_FILE}" 2>/dev/null; then
        pass "Primary model confirmed: anthropic/claude-opus-4.6"
    else
        fail "Primary model 'anthropic/claude-opus-4.6' NOT found in config"
    fi

    # Check skills_matrix.md
    check_start
    if [[ -f "${SKILLS_FILE}" ]]; then
        pass "skills_matrix.md — Present"
    else
        fail "skills_matrix.md — MISSING"
    fi

    # Check workflow.mermaid
    check_start
    if [[ -f "${WORKFLOW_FILE}" ]]; then
        pass "workflow.mermaid — Present"
    else
        fail "workflow.mermaid — MISSING"
    fi

    # Check openclaw_prompt.md
    check_start
    if [[ -f "${PROMPT_FILE}" ]]; then
        pass "openclaw_prompt.md — Present"
    else
        fail "openclaw_prompt.md — MISSING"
    fi

    # Check all 4 subagent configs
    local SUBAGENT_DIR="${PROJECT_ROOT}/Agent_main/subagents"
    local EXPECTED_AGENTS=("agent_architect.json" "agent_coding.json" "agent_imager.json" "agent_legacy.json")
    for agent_file in "${EXPECTED_AGENTS[@]}"; do
        check_start
        if [[ -f "${SUBAGENT_DIR}/${agent_file}" ]]; then
            if command -v python3 &>/dev/null && python3 -c "import json; json.load(open('${SUBAGENT_DIR}/${agent_file}'))" 2>/dev/null; then
                pass "Subagent config ${agent_file} — Valid JSON"
            else
                pass "Subagent config ${agent_file} — Present"
            fi
        else
            fail "Subagent config ${agent_file} — MISSING"
        fi
    done
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║   🦞 OpenClaw Pre-Flight Validation 🦞     ║"
    echo "║   Version: 2026.2.17 | Mode: PRODUCTION    ║"
    echo "╚══════════════════════════════════════════════╝"

    preflight_env_file
    preflight_api_keys
    preflight_ssh
    preflight_docker
    preflight_config

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Pre-Flight Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Total Checks: ${CHECKS}"
    echo "  Failures:     ${FAILURES}"

    if [[ ${FAILURES} -eq 0 ]]; then
        echo ""
        pass "ALL PRE-FLIGHT CHECKS PASSED — System is GO ✈️"
        echo ""
        return 0
    else
        echo ""
        fail "${FAILURES} check(s) failed — Resolve issues before proceeding"
        echo ""
        return 1
    fi
}

main "$@"
