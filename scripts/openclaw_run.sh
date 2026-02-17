#!/usr/bin/env bash
# =============================================================================
# OpenClaw Entrypoint
# Top-level launcher that sources .env and invokes the Orchestrator Engine.
#
# Usage:
#   bash scripts/openclaw_run.sh "Build a React landing page with a logo"
#   bash scripts/openclaw_run.sh --dry-run "Calculate 2+2"
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

# --- Banner ---
echo ""
echo "  ╔═══════════════════════════════════════╗"
echo "  ║   🦞  O P E N C L A W   🦞           ║"
echo "  ║   Multi-Agent Ecosystem v2026.2.17    ║"
echo "  ╚═══════════════════════════════════════╝"
echo ""

# --- Source Environment ---
if [[ -f "${ENV_FILE}" ]]; then
    echo "  Loading environment from .env..."
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
    echo "  ✅ Environment loaded (NODE_ENV=${NODE_ENV:-unset}, LOG_LEVEL=${LOG_LEVEL:-unset})"
else
    echo "  ❌ .env file not found at ${ENV_FILE}"
    echo "  → Please create .env with required API keys before running."
    exit 1
fi

echo ""

# --- Launch Orchestrator ---
exec bash "${SCRIPT_DIR}/orchestrator.sh" "$@"
