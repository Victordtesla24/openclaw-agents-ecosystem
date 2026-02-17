# 🦞 OpenClaw Ecosystem

> **Autonomous AI Agent Orchestration for High-Value Production Workflows**

OpenClaw is a production-grade multi-agent system designed to decompose complex requests into atomic tasks, delegate them to specialized AI agents (Architect, Coder, Imager, Researcher), and execute them on a secure VPS infrastructure.

## 🚀 Features

- **Intelligent Orchestration**: Claude Opus 4.6 (Manager) decomposes prompts into executable tasks.
- **Specialized Agent Swarm**:
  - **Architect**: Kimi K2.5 (Reasoning & Structure)
  - **Coder**: MiniMax M2.1 + GPT-5.2 Codex (Implementation)
  - **Imager**: Nano Banana Pro (Visual Assets)
  - **Researcher**: Gemini 3 Pro (Deep Research)
- **Production-First**: Live API integration with OpenRouter, Gemini, and OpenAI.
- **Gatekeeper QA**: Automated audit loop (Claude Sonnet 4.5) ensuring code integrity, security compliance, and criteria satisfaction.
- **Secure Infrastructure**: Dockerized deployment on Hostinger VPS with SSH tunneling and localhost-bound gateways.

## 📂 Repository Structure

```
├── Agent_main/           # Agent configuration definitions
│   └── subagents/        # Individual agent profiles (JSON)
├── docs/                 # System documentation & diagrams
│   ├── skills_matrix.md  # Agent capabilities mapping
│   ├── workflow.mermaid  # Orchestration flow diagram
│   └── openclaw_prompt.md # Core system prompt
├── scripts/              # Production execution scripts
│   ├── orchestrator.sh   # Main entry point (decomposition & dispatch)
│   ├── router.sh         # Intelligent task routing logic
│   ├── gatekeeper.sh     # QA & audit pipeline
│   └── preflight.sh      # Environment validation
├── tests/                # E2E Test Suite
│   └── run_tests.sh      # Live API & Logic verification
├── docker-compose.yml    # Production container orchestration
└── openclaw_config.json  # Core system configuration
```

## 🛠️ Usage

### Prerequisites
- Docker & Docker Compose
- `bash` 3.2+
- Valid `.env` file with API keys (OpenRouter, Gemini, OpenAI, Hostinger)

### Quick Start (Local to VPS)

1. **Clone & Configure**:
   ```bash
   git clone https://github.com/Victordtesla24/openclaw-agents-ecosystem.git
   cd openclaw-agents-ecosystem
   cp .env.example .env  # Add your API keys
   ```

2. **Run a Task**:
   Execute a complex request. The system will handle decomposition, routing, and execution on the VPS.
   ```bash
   bash scripts/orchestrator.sh "Build a React landing page for a coffee shop with a logo"
   ```

3. **Verify System Health**:
   Run the production test suite.
   ```bash
   bash tests/run_tests.sh
   ```

## 🛡️ Architecture

The system follows a strict **Decomposition → Delegation → Execution → Audit** pipeline:

1. **Ingestion**: User prompt is analyzed for intent (Code, Image, Research).
2. **Decomposition**: Broken down into atomic tasks in a JSON manifest.
3. **Routing**: Each task is routed to the most cost-effective and capable model.
4. **Execution**: Agents generate artifacts via live API calls.
5. **Gatekeeper**: Artifacts are audited for syntax, security leaks, and requirements.
   - *Pass*: Delivered to user.
   - *Fail*: Sent back to agent for correction (max 3 retries).

##  License

MIT
