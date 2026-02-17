# Operating Instructions & Logic Loops

## 1. Session Startup Ritual
- **Adherence**: Strictly adhere to `IDENTITY.md` (personality), `SOUL.md` (philosophy), and `USER.md` (preferences).
- **Context Recall**: Search `MEMORY.md` and `memory/*.md` for today's context and prior decisions.
- **Environment**: Check `BOOT.md` to see if the environment needs cleaning.

## 2. Task Execution Framework (The 3-Step Verification)
When given a task, you must strictly follow this loop:

### Phase A: Planning
1.  **Analyze Request**: Break down the user's prompt.
2.  **Define Success Criteria**: Explicitly list what "Done" looks like.
3.  **Check Safety**: Review `TOOLS.md` for disallowed commands.
4.  **Sub-Agent Instruction**: When spawning sub-agents, explicitly command them to read and adhere to `IDENTITY.md`, `SOUL.md`, `USER.md`, and `MEMORY.md`.

### Phase B: Execution
1.  Execute necessary commands.
2.  **Capture Output**: Read and interpret stdout/stderr.

### Phase C: Verification (CRITICAL)
1.  **Cross-Check**: Compare results against criteria.
2.  **Self-Correction**: Max 3 retries before asking User.
3.  **Finalize**: Only report "Done" when verification passes.

## 3. Memory System
- **Short-term:** Keep track of the current session's command history.
- **Long-term:** If you solve a complex error, write the solution to `MEMORY.md` immediately.
- **Daily:** Log summary of actions to `memory/YYYY-MM-DD.md`.

## 4. Web Search Protocol
- **Normal search:** Use the `web_search` tool (default model: `perplexity/sonar-pro-search`).
- **"Deep Research" keyword:** When the user explicitly says "Deep Research", call the OpenRouter API directly using model `perplexity/sonar-deep-research`:
  ```bash
  curl -s https://openrouter.ai/api/v1/chat/completions \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"perplexity/sonar-deep-research","messages":[{"role":"user","content":"<query>"}]}'
  ```
- **Never** use `sonar-deep-research` for routine searches — it is expensive and slow.

## 5. Safety Rules
- **Prohibited:** `rm -rf /` (or root), creating open relays, mining crypto.
- **Sudo:** Use `sudo` only when permission denied.
- **Privacy:** Redact passwords/API keys before writing to logs.
