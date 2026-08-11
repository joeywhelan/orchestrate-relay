# Demo Plan: IBM Watson Orchestrate → Elastic → ServiceNow (via MCP)

## Overview

Elastic indexes ServiceNow PDI data via the self-managed connector; a semantic query runs
directly against the index; the same query is then routed through IBM Watson Orchestrate,
which reaches the Elastic Agent Builder MCP server over basic auth.

**Format:** Jupyter notebook run-through (`demo.ipynb`) — not a live demo. Rendered outputs
become source material for a written article.

## Architecture

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
        (stock Incidents, Knowledge Articles, Change Requests, Requested Items)
```

**Key constraints:**
- ServiceNow connector is **self-managed only**
- All connector connections are **outbound-only** from AWS
- EC2 connector host has no inbound rules — unreachable from outside; ASG self-heals on instance failure

---

## Section 1: Provisioning

Four modules under `terraform/`, applied in dependency order:

| Module | Creates |
|---|---|
| `elastic_serverless` | Elasticsearch serverless project |
| `aws_network` | Egress-only security group (TCP 443 out); default VPC/subnets via data sources |
| `servicenow_connector` | Connector registration, configuration, index (`search-servicenow-demo`) with `semantic_text` mappings, scoped API key |
| `connector_agent` | EC2 launch template (t3.small, encrypted EBS) + singleton ASG; user_data runs the Docker connector image |

**Required `terraform.tfvars` keys:** `elastic_cloud_api_key`, `division`, `org`, `team`,
`servicenow_url`, `servicenow_username`, `servicenow_password`,
`orchestrate_url`, `orchestrate_api_key`.

Notebook §1 runs `terraform init -upgrade && terraform apply -auto-approve`, then writes
`.env` from `terraform output -raw` values.

### Index and semantic mappings

`servicenow_connector/main.tf` creates `search-servicenow-demo` with `semantic_text` fields
on `short_description`, `description`, and `text`, backed by `.jina-embeddings-v5-text-small`.
The index has `depends_on = [null_resource.connector_registration]` to guarantee mappings exist
before the connector writes documents.

---

## Section 2: Setup & Preflight

`run_preflight()` in `src/orchestrate_relay/preflight.py` runs checks in sequence:

1. ServiceNow PDI reachable (wakes the instance if hibernating)
2. Connector heartbeat status is **Connected**
3. Heartbeat freshness — last check-in within expected window
4. Inference endpoint live — `.jina-embeddings-v5-text-small` responds
5. Orchestrate auth valid — API key exchanged for MCSP token successfully

Verdicts are **PASS** or **FAIL**. Any FAIL blocks the run.

---

## Section 3: Sync

`docker.elastic.co/integrations/elastic-connectors:9.4.3` (pinned). `user_data.sh.tpl`
installs Docker on Amazon Linux 2023, writes `config.yml`, and starts the connector as a
systemd service.

Connector configuration is pushed from Terraform via a 40 × 15 s retry loop — the connector
service registers its schema on first check-in and rejects config values until then.

Config values: `url`, `username`, `password`, `services: "*"`. DLS off. No sync schedule.

Notebook §3 triggers a full sync on demand, polls until `status == completed`, then checks `_count`.

---

## Section 4: Semantic Query: Direct to Elasticsearch

ES|QL query via the Python client (`es.esql.query()`), using `MATCH(short_description, ?query)`
on the `semantic_text` field. Result rendered as a raw markdown table (printed to cell output for copy/paste into article).

**Demo query:** `"people cannot log in to company systems"` — no lexical overlap with the
indexed text. BM25 would miss; semantic search hits identity/auth records. This establishes the
baseline before the MCP hop in Section 7.

---

## Section 5: Create & Verify ES|QL Search Tool

Tool definition: `orchestrate/tools/search_servicenow.json` (committed to repo). The notebook
cell reads it, deletes any existing tool with the same id (idempotent), POSTs to
`/api/agent_builder/tools`, then calls `POST /api/agent_builder/tools/_execute` to verify
results before MCP is involved.

Auth: `ELASTIC_USERNAME` / `ELASTIC_PASSWORD` basic-auth + `kbn-xsrf: true` header.

The `_execute` output is the ground-truth result set — Section 7 must reproduce the same records
via the MCP path to demonstrate equivalence. Result rendered as a raw markdown table (printed to cell output for copy/paste into article).

---

## Section 6: Wire Orchestrate

```bash
echo Y | orchestrate env add --name orchestrate-relay --url "$ORCHESTRATE_URL"
orchestrate env activate orchestrate-relay --api-key "$ORCHESTRATE_API_KEY"

orchestrate connections add -a elastic_mcp >/dev/null 2>&1 || true
orchestrate connections configure -a elastic_mcp \
  --env draft -t team -k basic -u "$MCP_SERVER_URL"
orchestrate connections set-credentials -a elastic_mcp --env draft \
  --username "$ELASTIC_USERNAME" \
  --password "$ELASTIC_PASSWORD"

orchestrate toolkits remove -n elastic-agent-builder >/dev/null 2>&1 || true
orchestrate toolkits add -k mcp -n elastic-agent-builder \
  --description 'ServiceNow semantic search via Elastic Agent Builder' \
  -u "$MCP_SERVER_URL" --transport streamable_http -t '*' -a elastic_mcp

orchestrate agents import -f orchestrate/agent.yaml
```

**Idempotency notes:**
- `echo Y |` pre-confirms the "update existing env?" prompt from `env add`
- `connections add` and `toolkits remove` redirect all output (`>/dev/null 2>&1`) — the ADK logs to stdout, so `2>/dev/null` alone does not suppress `[ERROR]` lines
- `env activate` produces a `[WARNING] Using 'mcsp' Auth Type` on first run — benign, no `--type` flag exists to suppress it

Transport is `streamable_http` (MCP endpoint: `POST /api/agent_builder/mcp`). The `-a elastic_mcp`
binding is mandatory; omitting it sends unauthenticated requests.

### agent.yaml format requirements

`orchestrate/agent.yaml` must use **flat top-level fields** — the ADK's `Agent.from_spec()`
calls `Agent.model_validate(content)` directly against the parsed YAML dict; a `spec:` nesting
key is silently ignored by Pydantic.

- `style: experimental_customer_care` is **required** for MCP toolkit support; `react_core`
  (the default) raises `BadRequest: Toolkits are only supported for experimental_customer_care
  style agents` at import time.
- `toolkits:` takes a list of plain name strings (`- elastic-agent-builder`), not objects.
- `instructions:` must be at the top level, not under `spec:`.

Current `orchestrate/agent.yaml`:

```yaml
spec_version: v1
kind: native
name: servicenow_search
description: >
  Searches indexed ServiceNow data ...
instructions: >
  You are an IT support assistant. Always use the search_servicenow tool ...
style: experimental_customer_care
llm: groq/openai/gpt-oss-120b
toolkits:
  - elastic-agent-builder
```

---

## Section 7: Ask via Orchestrate

```bash
echo "exit" | orchestrate chat ask \
  --agent-name "$ORCHESTRATE_AGENT_NAME" \
  --include-reasoning \
  "people cannot log in to company systems"
```

`echo "exit" |` is required: `orchestrate chat ask` always enters an interactive loop after
printing the response and calls `input()` for a follow-up message; piping `exit` exits the loop
cleanly.

`--include-reasoning` output must show `search_servicenow` being called — that is the proof
the MCP hop happened and is the article's primary evidence. If the reasoning trace is absent,
the agent answered from LLM knowledge (tool not called).

---

## Section 8: Teardown

`terraform destroy -auto-approve` removes all AWS and Elastic infrastructure. `.env` is deleted.

Rebuild from zero is one run of Section 1 away.

---

## Notebook Structure

| § | Title | Notes |
|---|---|---|
| 1 | Provisioning | terraform apply + `.env` render; `MCP_SERVER_URL` derived from `KIBANA_URL` |
| 2 | Setup & Preflight | `run_preflight()` — 5 checks |
| 3 | Sync | trigger + poll + doc count |
| 4 | Semantic Query: Direct to Elasticsearch | ES\|QL `MATCH()` via Python client; markdown table printed to output |
| 5 | Create & Verify ES\|QL Search Tool | `POST /api/agent_builder/tools` + `_execute` verify; markdown table printed to output |
| 6 | Wire Orchestrate | ADK CLI: connection + toolkit + agent import |
| 7 | Ask via Orchestrate | `orchestrate chat ask` — MCP round-trip proof |
| 8 | Teardown | terraform destroy |

---

## Verification

Run notebook sections in order. Each gates the next.

1. §1: `.env` populated; contains `KIBANA_URL`.
2. §2: all preflight checks pass.
3. `GET /search-servicenow-demo/_mapping` — `semantic_text` on `short_description`, `description`, `text`.
4. §3: sync completes; doc count ≈ 46.
5. §4: semantically relevant hits for the demo query.
6. §5: `_execute` returns matching `INC` records — this is the ground-truth result set.
7. §6: `orchestrate toolkits list` shows `elastic-agent-builder`; export the agent and confirm `toolkits: [elastic-agent-builder]` and `instructions:` are non-empty.
8. §7: reasoning trace shows `search_servicenow` called; records match §5 output.
9. §8: `terraform destroy` → 0 resources.

**Before committing:** clear cell outputs. A failed `local-exec` in the connector configuration
retry loop echoes the ServiceNow password (40 iterations × full command).

---

## Folder Structure

```
orchestrate-relay/
├── demo.ipynb
├── pyproject.toml
├── README.md
├── CLAUDE.md
├── terraform/
│   ├── main.tf, variables.tf, outputs.tf
│   ├── terraform.tfvars             # gitignored
│   └── modules/
│       ├── elastic_serverless/
│       ├── aws_network/
│       ├── connector_agent/         # user_data.sh.tpl
│       └── servicenow_connector/
├── src/orchestrate_relay/
│   └── preflight.py                 # run_preflight()
├── assets/
│   ├── plan.md                      # this file
│   ├── article.md                   # written article (LinkedIn)
│   ├── images/
│   │   ├── arch.png                 # architecture diagram (820x547)
│   │   ├── cover.png                # LinkedIn article cover (1200x627)
│   │   ├── section1.png             # section image: Provisioning (900x300)
│   │   ├── section4.png             # section image: Semantic Query (900x300)
│   │   ├── section5.png             # section image: ES|QL Tool (900x300)
│   │   ├── section6.png             # section image: Wire Orchestrate (900x300)
│   │   ├── section7.png             # section image: Ask via Orchestrate (900x300)
│   │   └── resize.sh                # convert wrapper: cover (1200x627) and section (900x300) modes
│   └── prompts/
│       ├── prompt_arch.txt          # arch diagram generation prompt
│       ├── prompt_cover.txt         # cover image generation prompt
│       ├── prompt_section1.txt      # section image prompts
│       ├── prompt_section4.txt
│       ├── prompt_section5.txt
│       ├── prompt_section6.txt
│       └── prompt_section7.txt
└── orchestrate/
    ├── agent.yaml                   # flat format; experimental_customer_care style
    └── tools/
        └── search_servicenow.json   # ES|QL tool definition (read by §5)
```
