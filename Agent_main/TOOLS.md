# Environment & Tools Inventory

## Host System Specifications (Source: Hostinger Panel)
- **Hostname:** `srv1356245.hstgr.cloud`
- **Public IP:** `187.77.12.13` (Boston, US)
- **OS:** Ubuntu 25.10 (Rolling Release)
  - *Note:* Since this is non-LTS, stay vigilant for package deprecations during updates.
- **Kernel:** KVM Hypervisor
- **Resources:**
  - **CPU:** 2 vCores (Utilization currently low ~6%)
  - **RAM:** 8 GB (Utilization ~13%)
  - **Disk:** 100 GB NVMe (30 GB used)

## Container Environment
- **Runtime:** Docker / Docker Compose
- **Current Container:** `ghcr.io/hostinger/hvps-openclaw:latest` (Debian GNU/Linux 13 trixie)
- **Project Name:** `openclaw-ef1u`
- **Orchestration:** Docker Manager (Hostinger Panel)
- **OpenClaw Version:** 2026.2.6-3 (patched, post CVE-2026-25253/24763)
- **Compose Path:** `/docker/openclaw-ef1u/docker-compose.yml`
- **Gateway Port:** 41422 (bound to 127.0.0.1)

## Network & Connectivity
- **SSH Access:** `root@187.77.12.13` (Port 22, key-only) ⚠️ **DENIED** (Permission denied, key missing in container 2026-02-14)
- **Firewall:**
  - Hostinger Firewall: **OFF** (Rules: 0) — relying on internal UFW.
  - Internal Firewall: `ufw` — **UNKNOWN** (SSH Access Denied)
    - Default: deny incoming, allow outgoing
    - Allowed: 22/tcp, 80/tcp, 443/tcp (IPv4+IPv6)
- **SSH Hardening:** ✅ `PermitRootLogin prohibit-password`, `PasswordAuthentication no`
- **Fail2Ban:** ✅ Active, SSH jail enabled (3 max retries, 1hr ban)
- **Monarx:** ✅ Agent 4.3.10 active, config at `/etc/monarx-agent.conf`

## Toolchain
- **Package Manager:** `brew` (Homebrew 5.0.14) — `apt` unavailable.
- **Deployment:** Docker Compose (`docker-compose.yml` or `docker compose`).
- **File Manipulation:** `sed`, `awk`, `nano`, `vim`.
- **Search:** Enabled for resolving dependency errors or architectural research.

## Active Constraints
- **Malware Scanner:** Monarx Agent (active).
- **Bandwidth:** 8 TB limit (Currently negligible usage).

## Web Search Models (OpenRouter)
- **Normal Search:** `perplexity/sonar-pro-search` (default via `web_search` tool)
  - Also acceptable: `perplexity/sonar-reasoning-pro`
- **Deep Research:** `perplexity/sonar-deep-research` (OpenRouter API)
  - **Trigger:** ONLY when user explicitly says "Deep Research"
  - **Method:** Direct API call to `https://openrouter.ai/api/v1/chat/completions` with model `perplexity/sonar-deep-research`
  - **Do NOT use** for normal web searches

## Token Optimisation Stack (Active)
- **Context Cap:** 150K tokens (of 200K Opus window)
- **Pruning:** cache-ttl @ 15min — stale tool outputs trimmed/cleared automatically
- **Soft Trim:** Tool results > 500 chars pruned to 2K (500 head + 500 tail) at 70% capacity
- **Hard Clear:** Tool results replaced with placeholder at 85% capacity
- **Compaction:** safeguard mode, 30K reserve floor, 65% max history share
- **Memory Flush:** Auto-writes compaction summary to MEMORY.md at 100K token threshold
- **Keep Last:** 3 assistant turns always preserved through pruning

## AI Model Configuration (2026-02-15)
| Role | Model | Reasoning | Fallbacks |
|------|-------|-----------|-----------|
| Main | Gemini 3 Pro Preview | high | Gemini 3 Deep Think → GPT-5.3-Codex-Spark → Kimi-K2.5-Thinking |
| Sub-agents | Kimi-K2.5-Thinking | high | Gemini 3 Flash Preview → MiniMax M2.1 |

> ⚠️ `xhigh` reasoning is OpenAI-exclusive. Gemini/Anthropic/MiniMax M2.1/Kimi-K-2.5-Thinking models reject it.

## New Tools Acquired
- **rclone v1.73.0** — Google Drive CLI (gdrive: remote), OAuth with auto-renew (2026-02-10)
- **Netlify CLI/API** — Static site deployment via API (token-based) (2026-02-10)
- **jsPDF** — Client-side PDF generation for legal dashboard (2026-02-10)
- **Homebrew** — Primary Package Manager (v5.0.14) (2026-02-14)
- **go** — Programming Language (installed via brew) (2026-02-14)
- **wacli** — WhatsApp CLI (installed via brew, outdated) (2026-02-14)
