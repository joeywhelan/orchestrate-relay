import os, re, requests, pandas as pd
from datetime import datetime, timezone
from IPython.display import display
from ibm_watsonx_orchestrate.client.credentials import Credentials
from ibm_watsonx_orchestrate.client.client import Client as OrchestrateClient


def run_preflight():
    ES           = os.environ["ELASTIC_ENDPOINT"]
    AUTH         = (os.environ["ELASTIC_USERNAME"], os.environ["ELASTIC_PASSWORD"])
    SN           = os.environ["SERVICENOW_URL"]
    SN_AUTH      = (os.environ["SERVICENOW_USERNAME"], os.environ["SERVICENOW_PASSWORD"])
    CONNECTOR_ID = os.environ["CONNECTOR_ID"]
    INFERENCE_ID = ".jina-embeddings-v5-text-small"
    WXO_URL      = os.environ["ORCHESTRATE_URL"]
    WXO_KEY      = os.environ["ORCHESTRATE_API_KEY"]

    checks = []

    # ServiceNow PDI — a hibernating instance returns an HTML wake page, not JSON,
    # so parseable JSON is the real liveness signal.
    try:
        r = requests.get(f"{SN}/api/now/table/sys_user",
                         params={"sysparm_limit": 1, "sysparm_fields": "user_name"},
                         auth=SN_AUTH, headers={"Accept": "application/json"}, timeout=60)
        r.json()["result"]
        checks.append(("ServiceNow PDI", "PASS", f"awake, HTTP {r.status_code}"))
    except Exception as e:
        checks.append(("ServiceNow PDI", "FAIL",
                       f"hibernating or unreachable — open the PDI in a browser to wake it ({type(e).__name__})"))

    # Connector control-plane entry
    c = requests.get(f"{ES}/_connector/{CONNECTOR_ID}", auth=AUTH, timeout=30).json()

    status = c.get("status")
    checks.append(("Connector status", "PASS" if status == "connected" else "FAIL",
                   f"{status}" + (f" — {c['error']}" if c.get("error") else "")))

    # Heartbeat freshness — the container polls continuously; a stale last_seen means
    # the EC2 worker is dead even though the registration still exists.
    # ES returns 9 fractional-second digits; fromisoformat accepts at most 6.
    if c.get("last_seen"):
        seen = datetime.fromisoformat(re.sub(r"(\.\d{6})\d*", r"\1", c["last_seen"]))
        age  = (datetime.now(timezone.utc) - seen).total_seconds()
        checks.append(("Connector heartbeat", "PASS" if age < 300 else "FAIL",
                       f"last seen {age:.0f}s ago"))
    else:
        checks.append(("Connector heartbeat", "FAIL",
                       "never checked in — is the EC2 instance up?"))

    # Inference endpoint backing the semantic_text mappings.
    r = requests.get(f"{ES}/_inference/{INFERENCE_ID}", auth=AUTH, timeout=30)
    checks.append(("Inference endpoint", "PASS" if r.ok else "FAIL",
                   INFERENCE_ID if r.ok else f"missing — HTTP {r.status_code}"))

    # Orchestrate — exchange the API key for an MCSP token; confirms URL and key are valid
    # before §6c runs. Does not write config or activate any environment.
    try:
        creds = Credentials(url=WXO_URL, api_key=WXO_KEY, auth_type='mcsp')
        _ = OrchestrateClient(creds).token
        checks.append(("Orchestrate auth", "PASS", WXO_URL))
    except Exception as e:
        checks.append(("Orchestrate auth", "FAIL",
                       f"bad URL or API key — {type(e).__name__}: {e}"))

    df = pd.DataFrame(checks, columns=["Tier", "Verdict", "Detail"])
    failed = (df["Verdict"] == "FAIL").sum()
    print(f"Preflight ({len(checks)} checks): {(df['Verdict'] == 'PASS').sum()} pass, {failed} fail\n")
    display(df.style.hide(axis="index").map(
        lambda v: {"PASS": "color: green", "FAIL": "color: red"}.get(v, ""),
        subset=["Verdict"]))
    assert failed == 0, "Preflight failed — fix the FAIL rows above before continuing"
