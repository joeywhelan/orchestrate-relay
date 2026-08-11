# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

End-to-end agentic search demo: IBM Watson Orchestrate (MCP host) connects to the **Elastic Agent Builder MCP server** via MCP, with Elastic indexing ServiceNow data through a self-managed connector running in Docker on AWS EC2.

```
[IBM Watson Orchestrate]  ← MCP host
        | basic auth (MCP)
        v
[Elastic Agent Builder MCP Server]
        | Elasticsearch queries
        v
[Elastic Serverless (aws-eu-west-2)]
        ^
        | API key
[Elastic Connector Service — Docker on EC2 singleton ASG]
        | HTTPS basic auth
        v
[ServiceNow PDI]
```

The output is a Jupyter notebook run-through whose rendered results feed a written technical article — **not a live demo**. Notebook output should be article-ready (legible tables, timing summaries, pass/fail verdicts).

## Development Environment

Python toolchain is **`uv` exclusively** — no pip, no manual venv activation.

```sh
uv sync                                           # install deps, create .venv (Python 3.12 pinned)
uv run jupyter lab demo.ipynb                    # run the demo notebook
uv run orchestrate ...                           # IBM Watson Orchestrate ADK CLI
```

## Key Design Decisions

| Decision | Value |
|---|---|
| AWS region | `eu-west-2` (Elastic Serverless pairing: `aws-eu-west-2`) |
| Connector deployment | Docker on EC2, singleton Auto Scaling Group (min/max/desired=1, spans the default subnets for self-healing) |
| Python tooling | `uv` exclusively |
| DLS | Out of scope |
| Incremental sync | Out of scope — on-demand full sync only |
| Agent Builder tool | ES\|QL type; `MATCH` on `semantic_text` field performs semantic search |
| Orchestrate ADK | `ibm-watsonx-orchestrate>=2.13.0`; MCP transport `streamable_http` |
| `agent.yaml` format | Flat top-level fields (no `spec:` nesting); `style: experimental_customer_care` required for MCP toolkit support; `toolkits:` is a list of plain name strings |
| MCP auth (runtime) | Basic auth — Elastic username/password against the MCP server URL |
| Terraform layout | All files under `terraform/` (root configs, modules, rendered templates) |
| Repo | Public GitHub — no credentials, tokens, or customer data |
| Execution mode | Notebook run-through; outputs feed a written article |

## Architecture Constraints (from Elastic docs)

- The ServiceNow connector is **self-managed only** — no Elastic-managed option
- Docker is the recommended connector deployment path
- Connector configuration schema is registered by the connector service on first check-in; values can only be pushed after that — hence the 40 × 15 s retry loop in `servicenow_connector`
- All connector connections are **outbound-only** from AWS

## Terraform Modules (under `terraform/`)

- `elastic_serverless` — Elastic Cloud serverless project
- `aws_network` — default VPC + subnets via data sources, egress-only security group. AWS organization policy requires specific resource tags — supplied via provider `default_tags` in root `main.tf` and `local.org_tags` in `connector_agent`, with values from gitignored `terraform.tfvars`
- `connector_agent` — EC2 launch template (encrypted EBS, org tags on instance + volume) + singleton ASG; secrets reach the instance via `templatefile()` into user_data — no Secrets Manager, no IAM roles
- `servicenow_connector` — connector registration, configuration (curl via `null_resource`), index with `semantic_text` mappings, scoped API key. No sync schedule — on-demand only.

## Secrets & Configuration

- `.env` holds credentials and is gitignored — never commit it
- `*.tfvars` and `*.tfstate*` are gitignored
- Secrets flow: `terraform.tfvars` → Terraform variables → rendered into connector user_data at apply time
- `.env` is fully auto-populated by notebook §1 (from `terraform output -raw` + derivation). No manual steps required before §6:
  - From Terraform: `ELASTIC_*`, `KIBANA_URL`, `CONNECTOR_ID`, `INDEX_NAME`, `SERVICENOW_*`, `ORCHESTRATE_URL`, `ORCHESTRATE_API_KEY`
  - Hardcoded in §1: `ORCHESTRATE_AGENT_NAME=servicenow_search`
  - Derived in §1: `MCP_SERVER_URL` = `KIBANA_URL/api/agent_builder/mcp`
- A **failed** `local-exec` provisioner echoes its full command — including credentials — to notebook stderr; always clear failed-run cell outputs before committing `demo.ipynb`
- Tag values in `default_tags` must be known at plan time — use `plantimestamp()`, never `timestamp()`

## Coding Philosophy

**Simplicity is the primary tenet.** Always favor the simplest solution. Prefer `%%bash` cell magic over Python subprocess, shell one-liners over helper functions, and direct calls over abstractions. If a simpler tool exists, use it.

## Notebook Structure (`demo.ipynb`)

Eight sections: Provisioning → Setup/Preflight → Sync → Semantic Query (direct to ES) → Create & Verify ES|QL Tool → Wire Orchestrate → Ask via Orchestrate → Teardown. Section narratives double as article prose scaffolding.

| § | Title |
|---|---|
| 1 | Provisioning |
| 2 | Setup & Preflight |
| 3 | Sync |
| 4 | Semantic Query: Direct to Elasticsearch |
| 5 | Create & Verify ES\|QL Search Tool |
| 6 | Wire Orchestrate |
| 7 | Ask via Orchestrate |
| 8 | Teardown |

## Article & Assets

The project is fully complete. The written article lives at `assets/article.md` (LinkedIn-ready). Supporting files:

- `assets/images/` — all generated images; `_original.png` variants are unresized backups
  - `cover.png` (1200×627), `arch.png` (820×547), `section*.png` (900×300 each)
  - `resize.sh` — ImageMagick wrapper: `./resize.sh cover|section <input> <output>`
- `assets/prompts/` — image generation prompts: `prompt_cover.txt`, `prompt_arch.txt`, `prompt_section{1,4,5,6,7}.txt`

## Section 6 Idempotency Notes

- `echo Y |` pre-confirms the "update existing env?" prompt from `orchestrate env add`
- `connections add` and `toolkits remove` use `>/dev/null 2>&1` — ADK logs to stdout, so `2>/dev/null` alone does not suppress `[ERROR]` lines
- `env activate` emits `[WARNING] Using 'mcsp' Auth Type` — benign, no `--type` flag exists

## Implementation Reference

`assets/plan.md` is the master implementation blueprint. Consult it for phase-by-phase details and decision rationale before implementing any phase.
