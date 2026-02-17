#!/usr/bin/env bash
# =============================================================================
# OpenClaw Task Router / Delegation Engine
# Phase 3: Intelligent Orchestration & Task Delegation (Implementation Plan §4)
#
# Implements the Routing Matrix from skills_matrix.md:
#   - Maps task types to optimal agents
#   - Enforces Zero-Waste Spawning Policy
#   - Applies Negative Constraints (Imager/Research gate)
#   - Resolves fallback agents on primary failure
#
# Compatible with bash 3.2+ (macOS default).
#
# Usage:
#   echo '{"tasks":[...]}' | bash scripts/router.sh
#   bash scripts/router.sh --route "Build React App"
#   bash scripts/router.sh --classify "Generate a cyberpunk logo"
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Colour Helpers ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# =============================================================================
# Agent Roster (bash 3.2-compatible — using functions instead of assoc arrays)
# =============================================================================
get_agent_model() {
    case "$1" in
        manager)    echo "anthropic/claude-opus-4.6" ;;
        architect)  echo "moonshotai/kimi-k2.5" ;;
        coder)      echo "minimax/minimax-m2.1" ;;
        legacy)     echo "openai/gpt-5.2-codex" ;;
        imager)     echo "google/nano-banana-pro" ;;
        gatekeeper) echo "anthropic/claude-sonnet-4.5" ;;
        research)   echo "google/gemini-3-pro-preview" ;;
        *)          echo "anthropic/claude-opus-4.6" ;;
    esac
}

get_agent_alias() {
    case "$1" in
        manager)    echo "Manager 🦞" ;;
        architect)  echo "Architect 📐" ;;
        coder)      echo "Coder 💻" ;;
        legacy)     echo "Legacy 📜" ;;
        imager)     echo "Imager 🍌" ;;
        gatekeeper) echo "Gatekeeper 🛡️" ;;
        research)   echo "Deep Research 🔬" ;;
        *)          echo "Manager 🦞" ;;
    esac
}

get_agent_fallback() {
    case "$1" in
        manager)    echo "openai/gpt-5.2-codex" ;;
        architect)  echo "google/gemini-3-pro-preview" ;;
        coder)      echo "moonshotai/kimi-k2.5" ;;
        legacy)     echo "openai/gpt-5.3-codex-spark" ;;
        imager)     echo "flux-2-pro" ;;
        gatekeeper) echo "google/gemini-3-pro-preview" ;;
        research)   echo "anthropic/claude-opus-4.6" ;;
        *)          echo "minimax/minimax-m2.1" ;;
    esac
}

# =============================================================================
# Task Classification Engine
# =============================================================================
classify_task() {
    local description="$1"
    local desc_lower
    desc_lower=$(echo "${description}" | tr '[:upper:]' '[:lower:]')

    # --- Image Generation (highest priority — exclusive routing) ---
    if echo "${desc_lower}" | grep -qE '(generate.*image|generate.*logo|generate.*wallpaper|generate.*visual|create.*image|create.*logo|create.*icon|create.*banner|visual asset|4k.*logo|image generation|photo|illustration|artwork|mockup|design.*graphic|cyberpunk.*wallpaper)'; then
        echo "image"
        return
    fi

    # --- Deep Research (keyword trigger) ---
    if echo "${desc_lower}" | grep -qE '(deep research|deep_research|deepresearch)'; then
        echo "research"
        return
    fi

    # --- Legacy Code (refactoring / architectural analysis) ---
    if echo "${desc_lower}" | grep -qE '(refactor.*legacy|legacy.*code|legacy.*refactor|legacy.*system|old.*codebase|technical debt|modernize|migrate.*from|upgrade.*from|deprecated)'; then
        echo "legacy"
        return
    fi

    # --- Security Audit ---
    if echo "${desc_lower}" | grep -qE '(audit.*security|security.*audit|penetration test|vulnerability|compliance check|code.*review.*security|gatekeeper)'; then
        echo "audit"
        return
    fi

    # --- Complex Code (Agent Swarm / parallel / full-stack / UI) ---
    if echo "${desc_lower}" | grep -qE '(build.*app|full.?stack|react|angular|vue|nextjs|frontend|backend|api.*server|microservice|agent.*swarm|parallel.*processing|ui.*ux|complex.*architecture|architect|design.*system|swarm)'; then
        echo "code_complex"
        return
    fi

    # --- Routine Code (CLI, simple scripts, bulk generation) ---
    if echo "${desc_lower}" | grep -qE '(write.*function|write.*script|calculate|compute|parse|convert|translate.*code|cli.*command|routine|bulk.*code|simple.*script|error.*handling|fix.*bug|debug)'; then
        echo "code_routine"
        return
    fi

    # --- Simple/Default (Manager handles directly) ---
    echo "simple"
}

# =============================================================================
# Route Resolution
# =============================================================================
resolve_agent() {
    local task_type="$1"

    case "${task_type}" in
        code_complex)   echo "architect" ;;
        code_routine)   echo "coder" ;;
        image)          echo "imager" ;;
        research)       echo "research" ;;
        legacy)         echo "legacy" ;;
        audit)          echo "gatekeeper" ;;
        simple)         echo "manager" ;;
        *)              echo "manager" ;;
    esac
}

# =============================================================================
# Negative Constraint Enforcement
# =============================================================================
validate_assignment() {
    local agent_id="$1"
    local task_type="$2"

    # Constraint: Nano Banana Pro MUST NOT receive code/text/math/error tasks
    if [ "${agent_id}" = "imager" ]; then
        case "${task_type}" in
            code_complex|code_routine|simple|legacy|audit|research)
                echo -e "${RED}CONSTRAINT VIOLATION:${NC} Nano Banana Pro cannot handle '${task_type}' tasks"
                return 1
                ;;
        esac
    fi

    # Constraint: Gemini 3 Pro MUST NOT be spawned unless DEEP RESEARCH is required
    if [ "${agent_id}" = "research" ] && [ "${task_type}" != "research" ]; then
        echo -e "${RED}CONSTRAINT VIOLATION:${NC} Gemini 3 Pro must only be spawned for 'research' tasks"
        return 1
    fi

    return 0
}

# =============================================================================
# Route a Single Task Description
# =============================================================================
route_single() {
    local description="$1"
    local task_type agent_id model alias fallback

    task_type=$(classify_task "${description}")
    agent_id=$(resolve_agent "${task_type}")
    model=$(get_agent_model "${agent_id}")
    alias=$(get_agent_alias "${agent_id}")
    fallback=$(get_agent_fallback "${agent_id}")

    # Validate assignment against negative constraints
    if ! validate_assignment "${agent_id}" "${task_type}" 2>/dev/null; then
        echo -e "${RED}ROUTING ERROR:${NC} Cannot route '${description}' to ${alias}"
        return 1
    fi

    # Output routing decision as JSON
    cat <<EOF
{
    "task_description": "${description}",
    "task_type": "${task_type}",
    "agent_id": "${agent_id}",
    "agent_alias": "${alias}",
    "model": "${model}",
    "fallback_model": "${fallback}",
    "status": "routed"
}
EOF
}

# =============================================================================
# Route Multiple Tasks from JSON Manifest
# =============================================================================
route_manifest() {
    local manifest="$1"
    local task_count
    local spawned_agents=""

    # Parse task count
    if command -v python3 &>/dev/null; then
        task_count=$(echo "${manifest}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('tasks',[])))" 2>/dev/null || echo "0")
    elif command -v jq &>/dev/null; then
        task_count=$(echo "${manifest}" | jq '.tasks | length' 2>/dev/null || echo "0")
    else
        echo "ERROR: python3 or jq required for JSON parsing" >&2
        return 1
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  🦞 OpenClaw Task Router — ${task_count} task(s)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local i=0
    while [ ${i} -lt ${task_count} ]; do
        local task_desc task_type_hint

        if command -v python3 &>/dev/null; then
            task_desc=$(echo "${manifest}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['tasks'][${i}].get('description',''))" 2>/dev/null)
            task_type_hint=$(echo "${manifest}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['tasks'][${i}].get('type',''))" 2>/dev/null)
        else
            task_desc=$(echo "${manifest}" | jq -r ".tasks[${i}].description // \"\"" 2>/dev/null)
            task_type_hint=$(echo "${manifest}" | jq -r ".tasks[${i}].type // \"\"" 2>/dev/null)
        fi

        local task_type
        if [ -n "${task_type_hint}" ]; then
            task_type="${task_type_hint}"
        else
            task_type=$(classify_task "${task_desc}")
        fi

        local agent_id model alias
        agent_id=$(resolve_agent "${task_type}")
        model=$(get_agent_model "${agent_id}")
        alias=$(get_agent_alias "${agent_id}")

        # Validate
        if validate_assignment "${agent_id}" "${task_type}" 2>/dev/null; then
            echo -e "  ${GREEN}→${NC} Task $((i + 1)): ${task_desc}"
            echo -e "    Type: ${MAGENTA}${task_type}${NC} → Agent: ${CYAN}${alias}${NC} (${model})"

            # Track unique agents
            if ! echo "${spawned_agents}" | grep -q "${agent_id}"; then
                spawned_agents="${spawned_agents} ${agent_id}"
            fi
        else
            echo -e "  ${RED}✗${NC} Task $((i + 1)): ${task_desc} — ROUTING BLOCKED"
        fi

        i=$((i + 1))
    done

    echo ""

    # Zero-Waste summary
    local agent_count=0
    for a in ${spawned_agents}; do
        agent_count=$((agent_count + 1))
    done

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Zero-Waste Spawning Report${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Agents to spawn: ${GREEN}${agent_count}${NC}"
    for a in ${spawned_agents}; do
        local a_alias a_model
        a_alias=$(get_agent_alias "${a}")
        a_model=$(get_agent_model "${a}")
        echo -e "    • ${a_alias} → ${a_model}"
    done
    echo ""
}

# =============================================================================
# Main
# =============================================================================
main() {
    case "${1:-}" in
        --route)
            shift
            route_single "$*"
            ;;
        --classify)
            shift
            local task_type agent_id
            task_type=$(classify_task "$*")
            agent_id=$(resolve_agent "${task_type}")
            local alias model
            alias=$(get_agent_alias "${agent_id}")
            model=$(get_agent_model "${agent_id}")
            echo -e "Classification: ${MAGENTA}${task_type}${NC}"
            echo -e "Assigned Agent: ${CYAN}${alias}${NC} (${model})"
            ;;
        --help|-h)
            echo "Usage:"
            echo "  echo '{\"tasks\":[...]}' | bash scripts/router.sh"
            echo "  bash scripts/router.sh --route \"Build React App\""
            echo "  bash scripts/router.sh --classify \"Generate a cyberpunk logo\""
            exit 0
            ;;
        *)
            # Read JSON manifest from stdin
            if [ -t 0 ]; then
                echo "ERROR: No task manifest provided. Pipe JSON via stdin or use --route/--classify." >&2
                exit 1
            fi
            local manifest
            manifest=$(cat)
            route_manifest "${manifest}"
            ;;
    esac
}

main "$@"
