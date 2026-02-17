# Strategic Implementation Plan: OpenClaw Agent Ecosystem

> **Version:** 2026.2.17 | **Status:** Production-Ready | **Manager:** Claude Opus 4.6 Thinking AI

---

## 1. Overview

This document defines the step-by-step implementation protocol for the OpenClaw Multi-Agent Ecosystem. Every instruction is derived directly from the verified source-of-truth files:

| Source File | Purpose |
| :--- | :--- |
| `.env` | All credentials, endpoints, and runtime variables |
| `openclaw_config.json` | Model definitions, agent list, provider configuration |
| `skills_matrix.md` | Agent competencies, deployment triggers, and fallbacks |
| `workflow.mermaid` | Visual representation of the orchestration loop |
| `openclaw_prompt.md` | The Pre-Flight Decomposition & 1:1 Mapping Protocol |

---

## 2. Phase 1: Pre-Flight Infrastructure & Authentication

### 2.1 VPS Authentication

Establish a secure connection to the Hostinger VPS using the credentials defined in `.env`.

```bash
source .env
ssh -i $SSH_KEY_PATH -p $SSH_PORT $SSH_USER@$SSH_HOST
```

**Resolved Variables (from `.env`):**

| Variable | Value |
| :--- | :--- |
| `SSH_USER` | `root` |
| `SSH_HOST` | `187.77.12.13` |
| `SSH_PORT` | `22` |
| `SSH_KEY_PATH` | `/Users/vics-macbook-pro/.ssh/id_rsa` |

### 2.2 Environment Variable Validation

Before any agent is initialized, the system MUST verify the presence of all critical API keys. Keys are **never** printed to stdout.

**Required Keys (verified via `grep -q`):**
*   `GEMINI_API_KEY` — Google Gemini (Reasoning & General Purpose)
*   `OPENROUTER_API_KEY` — OpenRouter (Access to Claude, Kimi, MiniMax, Nano Banana Pro)
*   `OPENAI_API_KEY` — OpenAI (GPT-5.2 / 5.3 Codex Models)
*   `PERPLEXITY_API_KEY` — Perplexity (Web Search & Deep Research)
*   `HOSTINGER_API_TOKEN` — Hostinger (VPS Management)
*   `GATEWAY_TOKEN` — OpenClaw Gateway Authentication

### 2.3 Container Deployment

```bash
docker-compose up -d
```

**Post-Deploy Verification:**
*   Confirm all agent containers are `healthy`.
*   Confirm workspace volume is mounted at `$OPENCLAW_WORKSPACE` (`/data/.openclaw/workspace`).
*   Confirm `NODE_ENV=production` and `LOG_LEVEL=info`.

---

## 3. Phase 2: Ingestion & Pre-Flight Decomposition

**Actor:** `Claude Opus 4.6 Thinking AI` (Manager / Orchestrator — `🦞`)

The Manager Agent ingests the User Prompt and executes the **1:1 Mapping Protocol** defined in `openclaw_prompt.md`:

1.  **Extract:** Identify every explicit constraint, success criterion, and requirement from the user's input.
2.  **Index:** Create a **Success Criteria Register** — a discrete checklist of verifiable conditions (e.g., "Did Nano Banana Pro ONLY generate images?", "Is the API key securely loaded?", "Does the code build without errors?").
3.  **Validate:** Ensure 100% Requirement-to-Instruction coverage ratio before proceeding. If any requirement is unresolved, the Manager HALTS and triggers the **Critical Clarification Protocol**.
4.  **Decompose:** Break the validated request into atomic, delegatable tasks.

---

## 4. Phase 3: Intelligent Orchestration & Task Delegation

**Actor:** `Claude Opus 4.6 Thinking AI` (Manager)

The Manager cross-references each atomic task against the **Agent Skills Matrix** to determine the optimal agent assignment. The **Zero-Waste Spawning Policy** is strictly enforced: only agents explicitly required for the decomposed tasks are initialized.

### 4.1 Agent Roster & Routing Matrix

| Agent ID | Model | Alias | Deployment Trigger | Fallback |
| :--- | :--- | :--- | :--- | :--- |
| `main` | `anthropic/claude-opus-4.6` | Manager 🦞 | Initial Prompt Analysis, Orchestration, High-Complexity Error Resolution | OpenAI ChatGPT Codex |
| `architect-agent` | `moonshotai/kimi-k2.5` | Architect 📐 | High-volume coding, Agent Swarm requests, UI/UX Implementation | Gemini 3 Pro Preview |
| `coding-agent` | `minimax/minimax-m2.1` | Coder 💻 | Routine CLI execution, Low-complexity error handling, Bulk code generation | Kimi K2.5 |
| `legacy-agent` | `openai/gpt-5.2-codex` | Legacy 📜 | Legacy code refactoring, Deep architectural analysis | GPT-5.3 Codex Spark |
| `imager-agent` | `google/nano-banana-pro` | Imager 🍌 | Explicit request for "Image Generation" or "Visual Assets" | FLUX 2 Pro / Midjourney |
| *(QA Phase)* | `anthropic/claude-sonnet-4.5` | Gatekeeper | Final Output Verification, The "Audit" Phase of the QA Loop | Gemini 3 Pro Preview |
| *(Research)* | `google/gemini-3-pro-preview` | Deep Research | "DEEP RESEARCH" keyword trigger, Large-scale document analysis | Claude Opus 4.6 |

### 4.2 Delegation Rules

*   **Code Generation:** Route to `Kimi K2.5` (Architect) for complex/parallel tasks. Route to `MiniMax M2.1` (Coder) for routine/bulk generation.
*   **Image Generation:** Route **exclusively** to `Nano Banana Pro` (Imager). This agent is **prohibited** from receiving code generation or text-logic tasks.
*   **Deep Research:** Triggered by the keyword `DEEP RESEARCH` in the user prompt. Routes to `Gemini 3 Pro Preview` via OpenRouter API.
*   **Legacy Systems:** Route to `GPT-5.2 Codex` (Legacy) for refactoring or analysis of older codebases.
*   **Negative Constraint:** Do NOT spawn `Nano Banana Pro` for mathematical, error-resolution, or text-only tasks. Do NOT spawn `Gemini 3 Pro` unless multimodal analysis or deep research is explicitly required.

### 4.3 Example Decomposition

**Scenario:** *"Build a Full-Stack Web App with Visual Assets"*

| Atomic Task | Assigned Agent | Reasoning |
| :--- | :--- | :--- |
| Frontend Code (React/TypeScript) | `Kimi K2.5` (Architect) | Agent Swarm capability for parallel file generation |
| Backend Logic (Node.js/API) | `MiniMax M2.1` (Coder) | Cost-optimized bulk code generation |
| Visual Assets (Logo, UI Mockups) | `Nano Banana Pro` (Imager) | Explicit "Visual Assets" trigger |
| DevOps (VPS Config, CI/CD) | `Gemini 3 Pro Preview` | Strong reasoning for configuration and error checking |

---

## 5. Phase 4: Execution

Spawned agents execute their assigned tasks within the Docker container environment on the Hostinger VPS.

*   **Code Agents** (`Architect`, `Coder`, `Legacy`) execute commands against the VPS via SSH and generate artifacts in `$OPENCLAW_WORKSPACE`.
*   **Imager Agent** (`Nano Banana Pro`) generates image artifacts directly via the API. Output is an image binary/URL, never a text description.
*   **Research Agent** (`Gemini 3 Pro`) scans external sources (web via Perplexity) and internal documents (PDFs via Google Drive / `$RCLONE_REMOTE_NAME`) and synthesizes findings into a structured Markdown report.

All generated artifacts are collected and forwarded to the Manager for the QA phase.

---

## 6. Phase 5: The Gatekeeper Loop (Quality Assurance)

**Actor:** `Claude Sonnet 4.5 Thinking` (Gatekeeper) | **Fallback:** `Gemini 3 Pro Preview`

This is the autonomous, real-time verification loop that intercepts all artifacts **before** final delivery.

### 6.1 Audit Steps

1.  **Step A (Ingest):** Retrieve all artifacts generated by the execution agents.
2.  **Step B (Audit):** Perform a line-by-line comparison against the **Success Criteria Register** created in Phase 2.
    *   **Check 1 (Code Integrity):** Does the code build without errors?
    *   **Check 2 (Visual Integrity):** Did Nano Banana Pro generate the requested asset, or did it hallucinate text?
    *   **Check 3 (Security):** Are any API keys from `.env` exposed in the generated source code? (**Zero-Tolerance Policy**).
    *   **Check 4 (Requirement Coverage):** Does the output achieve a 100% match against the Success Criteria Register?

### 6.2 Branch Logic

*   **IF `Criteria_Met == TRUE`:** Proceed to **Package & Release**. The final deliverable is packaged for user presentation.
*   **IF `Criteria_Met == FALSE`:** Enter **Correction Loop**.
    1.  The Gatekeeper generates specific correction instructions (git-patch style).
    2.  Instructions are re-delegated to the appropriate agent (e.g., back to `Kimi K2.5` for code fixes).
    3.  The corrected artifact is re-submitted to **Step A**. The loop repeats until `Criteria_Met == TRUE`.

---

## 7. Phase 6: Final Presentation

**Actor:** `Claude Opus 4.6 Thinking AI` (Manager)

Upon successful completion of the Gatekeeper Loop, the Manager presents the verified result to the user. The response MUST begin with:

> **OpenClaw Mission Report**
>
> **Status:** ✅ VERIFIED & DEPLOYED
> **QA Audit:** Passed (Claude Sonnet 4.5)
>
> **Execution Log:**
> *   **Architect:** Decomposed request into [N] atomic tasks.
> *   **Agents Deployed:** [List of agents used].
> *   **Infrastructure:** Verified active on `$SSH_HOST`.
>
> **Deliverables:**
> 1.  [Artifact 1]
> 2.  [Artifact 2]
>
> *100% adherence to `.env` constraints and the Agent Skills Matrix confirmed. No placeholders were used. The result is production-ready.*

---

## 8. File Manifest

All configuration files referenced by this plan:

| File | Path | Purpose |
| :--- | :--- | :--- |
| Environment Variables | `.env` | API keys, SSH credentials, runtime settings |
| Core Config | `openclaw_config.json` | Model providers, agent definitions, gateway settings |
| System Prompt | `openclaw_prompt.md` | Pre-Flight Decomposition & 1:1 Mapping Protocol |
| Skills Matrix | `skills_matrix.md` | Agent competencies, triggers, and fallbacks |
| Workflow Diagram | `workflow.mermaid` | Visual orchestration loop |
| Architect Agent | `Agent_main/subagents/agent_architect.json` | Kimi K2.5 config |
| Coder Agent | `Agent_main/subagents/agent_coding.json` | MiniMax M2.1 config |
| Legacy Agent | `Agent_main/subagents/agent_legacy.json` | GPT-5.2 Codex config |
| Imager Agent | `Agent_main/subagents/agent_imager.json` | Nano Banana Pro config |
| Test Plan | `docs/OpenClaw_Production_Test_Plan.md` | End-to-End test cases & validation protocol |