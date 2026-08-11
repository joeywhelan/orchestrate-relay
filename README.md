# Agentic ServiceNow Search: IBM Orchestrate via MCP + Elastic

## Contents
1. [Summary](#summary)
2. [Presentation](#presentation)
3. [Architecture](#architecture)
4. [Features](#features)
5. [Prerequisites](#prerequisites)
6. [Installation](#installation)
7. [Usage](#usage)

## Summary <a name="summary"></a>
End-to-end demonstration of agentic semantic search over ServiceNow data. IBM Watson Orchestrate connects to the Elastic Agent Builder MCP server via Streamable HTTP, exposing an ES|QL search tool backed by a ServiceNow index in Elastic Serverless. A natural-language query — with zero lexical overlap with the indexed text — is routed through Orchestrate → MCP → Elastic, returning the correct incidents purely on semantic understanding.

The notebook runs the same query twice: directly against Elasticsearch (§4) and via Orchestrate (§7), so the two paths can be compared side-by-side.

## Presentation <a name="presentation"></a>
[Slide deck](https://joeywhelan.github.io/orchestrate-relay/)

## Architecture <a name="architecture"></a>
![architecture](assets/images/arch.png)

## Features <a name="features"></a>
- Jupyter notebook with linear, top-to-bottom execution
- Provisions a full stack via Terraform: Elastic Serverless project, AWS EC2 connector host, ServiceNow connector, ES|QL search tool, and Orchestrate agent
- Demonstrates semantic search over ServiceNow incidents via two paths: direct ES|QL query (§4) and IBM Watson Orchestrate via MCP (§7)
- Tears down the entire deployment via Terraform (§8)

## Prerequisites <a name="prerequisites"></a>
- [`uv`](https://docs.astral.sh/uv/) — Python toolchain (manages Python 3.12)
- [`terraform`](https://developer.hashicorp.com/terraform)
- AWS CLI with credentials configured
- Elastic Cloud API key (Serverless)
- ServiceNow developer instance credentials
- IBM Watson Orchestrate Standard credentials

## Installation <a name="installation"></a>
- Install dependencies: `uv sync`

## Usage <a name="usage"></a>
- Launch the notebook: `uv run jupyter lab demo.ipynb`
- Run cells top-to-bottom — linear execution is required; each section depends on the one before it
