#!/usr/bin/env bash
set -euo pipefail

# discover_openclaw_env.sh
# Usage:
#   sudo bash discover_openclaw_env.sh
#   sudo bash discover_openclaw_env.sh /path/to/output.env

OUT="${1:-openclaw.env.discovered}"

have() { command -v "$1" >/dev/null 2>&1; }

err() { echo "ERROR: $*" >&2; exit 1; }

need_root_notice() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "NOTE: Running as non-root may limit SSHD port detection (sshd process visibility)."
  fi
}

need_root_notice

# --------- Preconditions ----------
have docker || err "docker not found. Install Docker Engine on the VPS."
docker ps >/dev/null 2>&1 || err "docker is not accessible for this user. Run as root or add user to docker group."

# --------- VPS host identity ----------
HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
HOSTNAME_SHORT="$(hostname 2>/dev/null || echo unknown)"

DEFAULT_IFACE="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}' || true)"
if [[ -z "${DEFAULT_IFACE}" ]]; then
  DEFAULT_IFACE="$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}' || true)"
fi

PRIMARY_IPV4=""
if [[ -n "${DEFAULT_IFACE}" ]]; then
  PRIMARY_IPV4="$(ip -4 addr show dev "${DEFAULT_IFACE}" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1 || true)"
fi

# Fallback if above fails
if [[ -z "${PRIMARY_IPV4}" ]]; then
  PRIMARY_IPV4="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi

# --------- SSHD port detection (host SSH daemon, not container ports) ----------
# Best-effort: parse sshd_config + includes; fallback 22.
SSHD_PORTS_RAW="$( (grep -RhsE '^[[:space:]]*Port[[:space:]]+[0-9]+' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true) | awk '{print $2}' | tr '\n' ' ' )"
SSHD_PORT="22"
if [[ -n "${SSHD_PORTS_RAW// }" ]]; then
  # take the last configured Port as effective (best-effort)
  SSHD_PORT="$(echo "${SSHD_PORTS_RAW}" | awk '{print $NF}')"
fi

# --------- Identify the OpenClaw container ----------
# Prefer an existing "openclaw" container name; otherwise match by image.
OPENCLAW_CONTAINER=""
if docker inspect openclaw >/dev/null 2>&1; then
  OPENCLAW_CONTAINER="openclaw"
else
  OPENCLAW_CONTAINER="$(docker ps --format '{{.Names}} {{.Image}}' | awk '$2 ~ /hvps-openclaw/ {print $1; exit}' || true)"
fi
[[ -n "${OPENCLAW_CONTAINER}" ]] || err "Could not find an OpenClaw container. Expected name 'openclaw' or image matching 'hvps-openclaw'."

CONTAINER_IMAGE="$(docker inspect -f '{{.Config.Image}}' "${OPENCLAW_CONTAINER}" 2>/dev/null || echo unknown)"
CONTAINER_ID="$(docker inspect -f '{{.Id}}' "${OPENCLAW_CONTAINER}" 2>/dev/null || echo unknown)"

# --------- Volumes (host->container mounts) ----------
VOLUME_LINES="$(docker inspect -f '{{range .Mounts}}{{println .Source "=>" .Destination}}{{end}}' "${OPENCLAW_CONTAINER}" 2>/dev/null || true)"
# Try to capture the common linuxbrew mount if present.
LINUXBREW_HOST_SRC="$(echo "${VOLUME_LINES}" | awk -F' => ' '$2=="/home/linuxbrew"{print $1; exit}' || true)"
DATA_HOST_SRC="$(echo "${VOLUME_LINES}" | awk -F' => ' '$2=="/data"{print $1; exit}' || true)"

# --------- Networking ----------
NETWORKS="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{printf "%s " $k}}{{end}}' "${OPENCLAW_CONTAINER}" 2>/dev/null | sed 's/[[:space:]]*$//' || true)"

# --------- OpenClaw config reads (NO secrets) ----------
# openclaw config get <path> is a supported CLI helper. :contentReference[oaicite:4]{index=4}
OC_HAVE_CLI="false"
if docker exec "${OPENCLAW_CONTAINER}" sh -lc 'command -v openclaw >/dev/null 2>&1'; then
  OC_HAVE_CLI="true"
fi

oc_get() {
  local key="$1"
  if [[ "${OC_HAVE_CLI}" == "true" ]]; then
    docker exec "${OPENCLAW_CONTAINER}" sh -lc "openclaw config get ${key} 2>/dev/null | tail -n 1" || true
  else
    echo ""
  fi
}

GATEWAY_MODE="$(oc_get gateway.mode)"
GATEWAY_AUTH_MODE="$(oc_get gateway.auth.mode)"
# DO NOT read gateway.auth.token (secret).

WORKSPACE_PATH="$(oc_get agents.defaults.workspace)"
if [[ -z "${WORKSPACE_PATH}" ]]; then
  # fallback to the known path from your config
  WORKSPACE_PATH="/data/.openclaw/workspace"
fi

# Gateway port/bind: if unset, OpenClaw commonly defaults loopback and 18789. :contentReference[oaicite:5]{index=5}
GATEWAY_PORT="$(oc_get gateway.port)"
if [[ -z "${GATEWAY_PORT}" ]]; then
  GATEWAY_PORT="18789"
fi
GATEWAY_BIND_RAW="$(oc_get gateway.bind)"

# --------- Determine actual listen addresses inside container ----------
LISTEN_ADDRS=""
if docker exec "${OPENCLAW_CONTAINER}" sh -lc 'command -v ss >/dev/null 2>&1'; then
  LISTEN_ADDRS="$(docker exec "${OPENCLAW_CONTAINER}" sh -lc "ss -ltnH 2>/dev/null | awk '\$4 ~ /:${GATEWAY_PORT}\$/ {print \$4}' | sed 's/:.*//' | sort -u" || true)"
else
  # netstat fallback (format differs)
  LISTEN_ADDRS="$(docker exec "${OPENCLAW_CONTAINER}" sh -lc "netstat -ltn 2>/dev/null | awk '\$4 ~ /:${GATEWAY_PORT}\$/ {print \$4}' | sed 's/:.*//' | sort -u" || true)"
fi

# Normalize bind to a practical IP
GATEWAY_BIND_IP="unknown"
if echo "${LISTEN_ADDRS}" | grep -qE '^(127\.0\.0\.1|::1)$'; then
  GATEWAY_BIND_IP="127.0.0.1"
elif echo "${LISTEN_ADDRS}" | grep -qE '^(0\.0\.0\.0|::)$'; then
  GATEWAY_BIND_IP="0.0.0.0"
fi

# --------- Is the gateway port published to the host? ----------
# docker port shows mapped ports. :contentReference[oaicite:6]{index=6}
GATEWAY_PUBLISHED_LINE="$(docker port "${OPENCLAW_CONTAINER}" "${GATEWAY_PORT}/tcp" 2>/dev/null | head -n1 || true)"
GATEWAY_PUBLISHED="false"
GATEWAY_HOST_IP=""
GATEWAY_HOST_PORT=""
if [[ -n "${GATEWAY_PUBLISHED_LINE}" ]]; then
  GATEWAY_PUBLISHED="true"
  # Examples: "0.0.0.0:18789" or "127.0.0.1:18789"
  GATEWAY_HOST_IP="$(echo "${GATEWAY_PUBLISHED_LINE}" | awk -F: '{print $1}')"
  GATEWAY_HOST_PORT="$(echo "${GATEWAY_PUBLISHED_LINE}" | awk -F: '{print $2}')"
fi

# --------- Detect whether 41422 is published (commonly seen in your screenshots) ----------
OPENCLAW_SSH_HOST_LINE="$(docker port "${OPENCLAW_CONTAINER}" "41422/tcp" 2>/dev/null | head -n1 || true)"
OPENCLAW_SSH_PUBLISHED="false"
OPENCLAW_SSH_HOST_PORT=""
if [[ -n "${OPENCLAW_SSH_HOST_LINE}" ]]; then
  OPENCLAW_SSH_PUBLISHED="true"
  OPENCLAW_SSH_HOST_PORT="$(echo "${OPENCLAW_SSH_HOST_LINE}" | awk -F: '{print $2}')"
fi

# --------- Suggest how Codex should reach the gateway ----------
# If published on 0.0.0.0 -> can be reached via VPS IP (subject to firewall).
# If not published or published to 127.0.0.1 -> use SSH tunnel from Mac.
# Docker’s default port publishing binds to all host addresses unless specified. :contentReference[oaicite:7]{index=7}
GATEWAY_ACCESS_MODE="ssh_tunnel_recommended"
GATEWAY_HOST_FOR_CODEX="127.0.0.1"
GATEWAY_PORT_FOR_CODEX="${GATEWAY_PORT}"

if [[ "${GATEWAY_PUBLISHED}" == "true" ]]; then
  if [[ "${GATEWAY_HOST_IP}" == "0.0.0.0" ]]; then
    # Publicly bound on host (still should be protected by token auth)
    GATEWAY_ACCESS_MODE="public_http_possible"
    GATEWAY_HOST_FOR_CODEX="${PRIMARY_IPV4:-${HOSTNAME_FQDN}}"
    GATEWAY_PORT_FOR_CODEX="${GATEWAY_HOST_PORT:-${GATEWAY_PORT}}"
  else
    # Published but loopback-only on host
    GATEWAY_ACCESS_MODE="ssh_tunnel_required"
    GATEWAY_HOST_FOR_CODEX="127.0.0.1"
    GATEWAY_PORT_FOR_CODEX="${GATEWAY_HOST_PORT:-${GATEWAY_PORT}}"
  fi
else
  # Container-only: tunnel or docker exec proxying
  GATEWAY_ACCESS_MODE="ssh_tunnel_required"
  GATEWAY_HOST_FOR_CODEX="127.0.0.1"
  GATEWAY_PORT_FOR_CODEX="${GATEWAY_PORT}"
fi

# --------- Output env file (NO secrets) ----------
cat > "${OUT}" <<EOF
# Generated by discover_openclaw_env.sh
# Contains NO API keys/tokens/credentials.

# VPS identity
VPS_HOSTNAME=${HOSTNAME_FQDN}
VPS_HOST_IP=${PRIMARY_IPV4:-unknown}
VPS_DEFAULT_IFACE=${DEFAULT_IFACE:-unknown}

# Host SSH daemon (for SSH into the VPS host)
SSHD_PORT=${SSHD_PORT}

# OpenClaw container targeting
OPENCLAW_CONTAINER=${OPENCLAW_CONTAINER}
OPENCLAW_CONTAINER_ID=${CONTAINER_ID}
OPENCLAW_CONTAINER_IMAGE=${CONTAINER_IMAGE}
OPENCLAW_NETWORKS=${NETWORKS:-unknown}

# Workspace (per OpenClaw config; expected /data/.openclaw/workspace)
OPENCLAW_WORKSPACE=${WORKSPACE_PATH}

# Volumes (host => container)
# Full list (multi-line; keep for reference):
# ${VOLUME_LINES//$'\n'/$'\n# '}
OPENCLAW_VOLUME_DATA_HOST=${DATA_HOST_SRC:-unknown}
OPENCLAW_VOLUME_LINUXBREW_HOST=${LINUXBREW_HOST_SRC:-unknown}

# Gateway (NO token included)
GATEWAY_MODE=${GATEWAY_MODE:-unknown}
GATEWAY_AUTH_MODE=${GATEWAY_AUTH_MODE:-unknown}
GATEWAY_PROTOCOL=http
GATEWAY_PORT=${GATEWAY_PORT}
GATEWAY_BIND_IP=${GATEWAY_BIND_IP}

# Gateway exposure status
GATEWAY_PUBLISHED=${GATEWAY_PUBLISHED}
GATEWAY_PUBLISHED_BIND=${GATEWAY_HOST_IP:-none}
GATEWAY_PUBLISHED_HOST_PORT=${GATEWAY_HOST_PORT:-none}

# How Codex should access the Gateway from Mac
GATEWAY_ACCESS_MODE=${GATEWAY_ACCESS_MODE}
GATEWAY_HOST_FOR_CODEX=${GATEWAY_HOST_FOR_CODEX}
GATEWAY_PORT_FOR_CODEX=${GATEWAY_PORT_FOR_CODEX}

# Published 41422 mapping (if present)
OPENCLAW_41422_PUBLISHED=${OPENCLAW_SSH_PUBLISHED}
OPENCLAW_41422_HOST_PORT=${OPENCLAW_SSH_HOST_PORT:-none}

# --- Secrets (fill manually; intentionally blank placeholders) ---
# OPENCLAW_GATEWAY_TOKEN=__SET_ME__
# HOSTINGER_API_TOKEN=__SET_ME__
# SSH_USER=root
# SSH_KEY_PATH=/ABS/PATH/ON/MAC/id_rsa
EOF

echo "Wrote: ${OUT}"
echo ""
echo "Summary:"
echo "  VPS_HOSTNAME=${HOSTNAME_FQDN}"
echo "  VPS_HOST_IP=${PRIMARY_IPV4:-unknown}"
echo "  SSHD_PORT=${SSHD_PORT}"
echo "  OPENCLAW_CONTAINER=${OPENCLAW_CONTAINER}"
echo "  GATEWAY_PORT=${GATEWAY_PORT} (bind inside container: ${GATEWAY_BIND_IP})"
echo "  GATEWAY_PUBLISHED=${GATEWAY_PUBLISHED} (${GATEWAY_PUBLISHED_LINE:-not published})"
echo "  GATEWAY_ACCESS_MODE=${GATEWAY_ACCESS_MODE}"
echo "  Suggested for Codex: ${GATEWAY_HOST_FOR_CODEX}:${GATEWAY_PORT_FOR_CODEX}"