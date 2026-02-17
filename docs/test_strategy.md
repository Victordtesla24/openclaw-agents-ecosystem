# OpenClaw End-to-End Test Strategy

## 1. Objective
Verify the integrity of the OpenClaw Orchestration Engine, ensuring all agents, tools, and external integrations function with zero-loss fidelity.

## 2. Test Scope
*   **Core Orchestration:** Manager (Claude Opus) -> Sub-Agent delegation.
*   **Model Integration:** Connectivity to OpenRouter (Kimi, MiniMax, Gemini, Claude).
*   **Toolchain:** Execution of `rclone`, `brew`, `go`.
*   **FileSystem:** Persistent storage in `/data/.openclaw/workspace`.

## 3. Test Cases

### TC-01: Identity & Configuration Verification
*   **Action:** Execute `cat openclaw_config.json | jq .models.providers.openrouter.models[0].id`
*   **Expected Result:** Output contains `anthropic/claude-opus-4.6`.
*   **Pass Criteria:** JSON is valid; correct model is primary.

### TC-02: Sub-Agent Delegation (Simulation)
*   **Action:** Manager simulates a "Thinking" task to `Kimi-Creative`.
*   **Input:** "Generate a haiku about a lobster."
*   **Expected Result:** Sub-agent `creative-agent` receives request, processes via `moonshotai/kimi-k2.5`, returns valid text.
*   **Pass Criteria:** Response received < 10s (network dependent), content matches persona.

### TC-03: Coding Capability (MiniMax)
*   **Action:** Manager delegates a code gen task to `MiniMax-Coder`.
*   **Input:** "Write a Golang function to reverse a string."
*   **Expected Result:** Valid Go code returned.
*   **Pass Criteria:** Code compiles (if `go build` run) or is syntactically correct.

### TC-04: Deep Reasoning (Gemini 3)
*   **Action:** Manager delegates complex query to `Gemini-Reasoning`.
*   **Input:** "Analyze the trade-offs between Monarx and ClamAV for this VPS."
*   **Expected Result:** Detailed, multi-paragraph analysis.
*   **Pass Criteria:** "Thinking" level evident (if visible) or depth of answer > 200 words.

### TC-05: Tool Execution (Rclone)
*   **Action:** `rclone version`
*   **Expected Result:** Version string `v1.73.0` (or greater).
*   **Pass Criteria:** Exit code 0.

### TC-06: Resource Limits
*   **Action:** Check RAM usage during multi-agent simulation.
*   **Expected Result:** Total usage < 8GB.
*   **Pass Criteria:** System does not OOM kill containers.

## 4. Execution Plan
1.  **Pre-Flight:** Run `discover_openclaw_update.sh` to confirm baseline.
2.  **Run:** Execute TCs sequentially via Manager.
3.  **Log:** Record outputs to `TEST_RESULTS.md`.
