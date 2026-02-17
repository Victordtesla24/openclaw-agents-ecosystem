# OpenClaw Production Implementation & End-to-End Testing Plan

## 1. Executive Summary
This document defines the strict operational protocols for deploying and verifying the OpenClaw Multi-Agent Ecosystem. It adheres 100% to the Source of Truth defined in `@.env` and the `Agency Skills Matrix`.

## 2. Environment & Pre-Flight Checks
**Objective:** Ensure the execution environment is pristine and fully authenticated before Agent initialization.

### 2.1 Credential Verification
**Action:** Execute the following audit script (simulated or actual) to verify `.env` integrity.
```bash
# Verify .env exists and is readable
if [ -f .env ]; then echo "✅ .env found"; else echo "❌ .env MISSING"; exit 1; fi

# Check for Critical Keys (Zero-Knowledge Check - do not print keys)
grep -q "Gemini_API_KEY" .env && echo "✅ Gemini Key Present" || echo "❌ Gemini Key Missing"
grep -q "OPENROUTER_API_KEY" .env && echo "✅ OpenRouter Key Present" || echo "❌ OpenRouter Key Missing"
grep -q "HOSTINGER_API_TOKEN" .env && echo "✅ Hostinger Token Present" || echo "❌ Hostinger Token Missing"
```

### 2.2 Connectivity Check
**Action:** Verify VPS Access using `.env` variables.
```bash
source .env
ssh -q -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SSH_HOST -p $SSH_PORT "echo 2>&1" && echo "✅ VPS Connectivity Verified" || echo "❌ VPS Connection FAILED"
```

## 3. Workflow Logic & Test Cases

### Phase 1: Ingestion & Decomposition
**Actor:** `Claude Opus Thinking AI 4.6` (Architect)
**Test Scenario TC-001:** multi-modal Request Processing
*   **Input:** "Create a React landing page for a coffee shop with a generated logo and a pricing comparison table researched from the web."
*   **Expected Behavior:** Architect extracts three distinct tasks:
    1.  Frontend Code (React)
    2.  Visual Asset (Logo)
    3.  Deep Research (Pricing)
*   **Pass Criteria:** Output JSON/Markdown lists exactly these 3 tasks linked to correct agents.

### Phase 2: Intelligent Orchestration (Spawning)
**Test Scenario TC-002:** Token Economy / Zero-Waste
*   **Input:** "Calculate 2+2."
*   **Expected Behavior:** Agent spawns **ONLY** `Claude Opus` or `MiniMax` (Low Cost).
*   **Fail Condition:** Spawning `Nano Banana Pro` (Image) or `Gemini 3 Pro` (Deep Research).

**Test Scenario TC-003:** The "Deep Research" Trigger
*   **Input:** "Perform DEEP RESEARCH on 2026 Crypto Regulations."
*   **Expected Behavior:** Immediately spawn `Gemini 3 Pro Preview`.
*   **Pass Criteria:** logs show `Gemini 3 Pro` initialization.

### Phase 3: Task Delegation (Routing Matrix)
**Verify Routing Logic against `skills_matrix.md`:**

| Requirement | Assigned Agent | Protocol |
| :--- | :--- | :--- |
| "Refactor Legacy Code" | `GPT-5.2 Codex` | Legacy Systems |
| "Generate 4K Logo" | `Nano Banana Pro` | Image Generation |
| "Build React App" | `Kimi K2.5` | Agent Swarm |
| "Audit Security" | `Claude Sonnet 4.5` | Gatekeeper |

**Test Scenario TC-004:** Visual Asset Delegation
*   **Input:** "Generate a cyberpunk lobster wallpaper."
*   **Expected Behavior:** Route -> `Banana-Imager-Agent` (Nano Banana Pro).
*   **Pass Criteria:** Output is an Image URL/Binary, NOT a text description of an image.

### Phase 4: Autonomous QA Loop (The Gatekeeper)
**Actor:** `Claude Sonnet 4.5 Thinking`
**Test Scenario TC-005:** The Correction Loop
*   **Setup:** Inject a deliberate syntax error into `Kimi K2.5` output (e.g., missing closing brace in JS).
*   **Step A (Audit):** Claude Sonnet 4.5 scans code.
*   **Step B (Verdict):** Returns `Criteria_Met == FALSE`.
*   **Step C (Branch):** Issues specific patch instruction -> RE-DELEGATES to Kimi.
*   **Step D (Retry):** Kimi applies fix.
*   **Step E (Final Audit):** Claude Sonnet 4.5 Returns `Criteria_Met == TRUE`.
*   **Pass Criteria:** Final artifact is error-free; Logs show rejection and retry.

## 4. Final Presentation Template
**Actor:** `Claude Opus 4.6`

Upon successful completion of Phase 4, the Manager MUST start the final response with:

> **OpenClaw Mission Report**
>
> **Status:** ✅ VERIFIED & DEPLOYED
> **QA Audit:** Passed (Claude Sonnet 4.5)
>
> **Execution Log:**
> *   **Architect:** Decomposed request into [N] tasks.
> *   **Agents Deployed:** [List Agents Used - e.g., Kimi, Nano Banana].
> *   **Infrastructure:** Verified active on [VPS_HOST].
>
> **Deliverables:**
> 1.  [Artifact 1 Name]
> 2.  [Artifact 2 Name]
>
> *This result has been rigorously tested against your constraints. No placeholders were used.*

## 5. Rollback & Safety
*   **Emergency Stop:** If `LOG_LEVEL=error` spikes, execute `docker-compose down`.
*   **Data Integrity:** Workspace mounted at `$OPENCLAW_WORKSPACE` is persistent. Do not `rm -rf` this directory during tests.
