# OpenClaw AI Skills Matrix

Agent / Model	Primary Competency (The "Hard Skills")	Secondary Competency (The "Soft Skills")	Deployment Trigger	Fail-Safe / Fallback
Claude Opus 4.6 Thinking	Architectural Reasoning, System Orchestration, Complex Logic	"Pre-flight Decomposition," Strategic Planning, Constraint Analysis	Initial Prompt Analysis, High-Complexity Error Resolution, Workflow Orchestration	OpenAI ChatGPT Codex
Kimi K2.5	Agent Swarm, Parallel Processing, Multimodal Analysis	"Long-Thinking," Visual Debugging, Frontend Code Generation	High-volume coding tasks, "Agent Swarm" requests, UI/UX Implementation	Gemini 3 Pro Preview
Gemini 3 Pro Preview	Complex Reasoning, Multimodal Analysis (Video/PDF), Long-Context	"Thinking Mode," Deep Research, Cross-verification	"DEEP RESEARCH" requests, Large-scale document analysis, Code Auditing	Claude Opus 4.6
Nano Banana Pro	High-Fidelity Image Generation, Visual Styling	Instruction Adherence, "Studio-quality" output generation	Explicit user request for "Image Generation" or "Visual Assets"	FLUX 2 Pro / Midjourney
MiniMax AI	Error Resolution, Rapid Inference	Cost-effective processing, Routine execution	Routine CLI command execution, Low-complexity error handling	Kimi K2.5
Claude Sonnet 4.5 Thinking	Quality Assurance, Code Auditing, "The Gatekeeper"	Line-by-line Audit, Logic Verification, Security Compliance	Final Output Verification, The "Audit" Phase of the QA Loop	Gemini 3 Pro Preview

## Role Allocation Strategy

*   **Manager / Orchestrator:** `Claude Opus 4.6` (Hard-coded requirement). Best for maintaining state, verifying outputs, and complex decision-making.
*   **Deep Reasoning / Context Heavy:** `Gemini 3 Pro Preview`. Use for ingesting massive documentation or multi-modal analysis.
*   **Coding & Execution (Cost-Optimized):** `MiniMax M2.1`. Use for bulk code generation, refactoring, and translation tasks.
*   **Creative / Narrative / "Thinking" Tasks:** `Kimi K2.5`. Use for content generation or breakdown of ambiguous tasks.

