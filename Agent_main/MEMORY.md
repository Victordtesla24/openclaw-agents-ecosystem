# Long-Term Knowledge & Lessons Learned

## Infrastructure Rules
- Always run `apt-get update` before installing new packages.
- Docker containers must use restart policies (unless one-off).

## User Preferences History
- **Web Search:** Normal search uses `perplexity/sonar-pro-search` via OpenRouter. When user says "Deep Research", use `perplexity/sonar-deep-research` via direct OpenRouter API call. Never mix the two.
- [Dynamic: The agent will write here when you correct it. E.g., "User prefers python3 over python2."]

## Troubleshooting Archive
- **Monarx repo:** `repos.monarx.com/setup.sh` returns marketing HTML. Use `repository.monarx.com` for actual packages.
- **Ubuntu 25.10 (questing):** Not in most vendor repos. Use noble (24.04) repos as fallback.
- **Docker-compose recreation:** Can disrupt SSH connectivity. Always verify SSH BEFORE and AFTER container changes.
- **Gateway port 41422:** Was bound to 0.0.0.0 by default (Hostinger template). Changed to 127.0.0.1 in docker-compose.yml.
- **Maintenance Failures (2026-02-14):** Host SSH key missing/denied. `docker` CLI missing in container. Host maintenance impossible until remedied.

## Active Cron Jobs
- Workspace Backup: hourly rsync (silent)
- Daily Integrity Check: 08:00 Melbourne
- Sunday Maintenance: 10:00 Melbourne
- Weekly AI Model Intel: 09:00 Mondays Melbourne → email to sarkar.vikram@gmail.com

## Google Drive Integration
- **Tool:** rclone v1.73.0
- **Remote name:** `gdrive`
- **Config:** `~/.config/rclone/rclone.conf`
- **Auth:** OAuth token (refresh token enabled, auto-renews)
- **Access:** Full drive scope (read/write/delete)
- **Usage:** `rclone ls gdrive:`, `rclone copy`, `rclone sync`, etc.
- **Setup date:** 2026-02-10

## Token Optimisation Configuration (2026-02-10)
- **Context Token Cap:** 150,000 (of 200K Opus window) — leaves 50K headroom for system prompt + response
- **Context Pruning:** `cache-ttl` mode, TTL=15 min
  - `keepLastAssistants`: 3 (always preserve last 3 assistant turns)
  - `softTrimRatio`: 0.7 (trim tool outputs when context hits 70% capacity)
  - `hardClearRatio`: 0.85 (replace tool outputs entirely at 85% capacity)
  - `minPrunableToolChars`: 500 (skip small tool results)
  - `softTrim`: maxChars=2000, headChars=500, tailChars=500
  - `hardClear`: enabled, placeholder="[tool output cleared — stale context]"
- **Compaction:** `safeguard` mode
  - `reserveTokensFloor`: 30,000 (always keep 30K tokens free for response)
  - `maxHistoryShare`: 0.65 (history can use max 65% of context)
  - `memoryFlush`: enabled, soft threshold at 100K tokens — auto-writes summary to MEMORY.md before compacting
- **Rationale:** This session showed heavy tool use (config schema dumps 50K+ chars, Netlify deploys, file reads). These values prevent context overflow while preserving recent critical context.

## Continuous Learning Protocol
- After each major config change: update this file with rationale and values
- After each error resolution: log to Troubleshooting Archive
- After each new tool/integration: log setup details
- On compaction events: review if thresholds need adjustment based on session patterns
- Weekly: review token usage patterns and tune softTrim/hardClear values if needed

## Model Configuration (2026-02-15)
- **Main Agent:** Gemini 3 Pro Preview (Primary). Added Gemini 3 Deep Think (Reasoning Specialist) and GPT-5.3-Codex-Spark (Fast Coding) to fallbacks.
- **Sub-Agents:** Kimi-K2.5-Thinking (Primary) + MiniMax M2.1 (Fallback) + Gemini 3 Flash Preview (Fallback).
- **Recent Discoveries:**
  - Gemini 3 Deep Think (Feb 12): Promising for complex reasoning (better "pelican").
  - GPT-5.3-Codex-Spark (Feb 12): Ultra-fast coding model (1000 t/s).
  - Claude Opus 4.6 Fast Mode (Feb 7): Expensive but 2.5x faster.
- **Max Concurrent:** 4 main sessions, 8 sub-agents

## Pending Tasks
- [Agent/Sub-Agent: to dynamically populate pending tasks here]