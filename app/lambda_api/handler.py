import os
import json
import time
import logging
import datetime as dt
from decimal import Decimal
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# ---- Environment -------------------------------------------------------------

DDB_TABLE = os.environ["DDB_TABLE"]

FMP_BASE_URL = os.environ.get("FMP_BASE_URL", "https://financialmodelingprep.com/stable").rstrip("/")
FMP_API_KEY = os.environ.get("FMP_API_KEY", "")

TTL_QUOTE_SECONDS = int(os.environ.get("TTL_QUOTE_SECONDS", "28800"))  # 8 hours
WRITE_RUN_HISTORY = os.environ.get("WRITE_RUN_HISTORY", "true").lower() == "true"

SCHEDULED_TICKERS = [t.strip().upper() for t in os.environ.get("SCHEDULED_TICKERS", "PLUG").split(",") if t.strip()]
SCHEDULED_CHUNK_SIZE = int(os.environ.get("SCHEDULED_CHUNK_SIZE", "17"))  # 17 + 17 + 16 ~= 50/day

RUN_UNTIL_UTC = os.environ.get("RUN_UNTIL_UTC", "").strip()  # e.g. 2025-12-27T00:00:00Z

ddb = boto3.resource("dynamodb")
table = ddb.Table(DDB_TABLE)


# ---- Helpers ----------------------------------------------------------------

def now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def iso_now() -> str:
    return now_utc().isoformat(timespec="seconds")


def epoch_now() -> int:
    return int(time.time())


def parse_run_until() -> Optional[dt.datetime]:
    if not RUN_UNTIL_UTC:
        return None
    try:
        return dt.datetime.fromisoformat(RUN_UNTIL_UTC.replace("Z", "+00:00"))
    except Exception:
        logger.warning("Invalid RUN_UNTIL_UTC format: %s", RUN_UNTIL_UTC)
        return None


def to_ddb_safe(value: Any) -> Any:
    """Convert floats into Decimal for DynamoDB compatibility."""
    if isinstance(value, float):
        return Decimal(str(value))
    if isinstance(value, dict):
        return {k: to_ddb_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [to_ddb_safe(v) for v in value]
    return value


def chunk(items: List[str], size: int, index: int) -> List[str]:
    if size <= 0:
        return items
    start = index * size
    end = start + size
    return items[start:end]


def event_chunk_index(event: Dict[str, Any]) -> int:
    try:
        return int((event or {}).get("chunk_index", 0))
    except Exception:
        return 0


# ---- FMP Client -------------------------------------------------------------

def fmp_get(path: str, params: Dict[str, str]) -> Tuple[int, Any]:
    """Call FMP and return (status_code, parsed_json_or_text)."""
    if not FMP_API_KEY:
        return 500, {"error": "missing_api_key", "details": "FMP_API_KEY is empty"}

    q = dict(params or {})
    q["apikey"] = FMP_API_KEY

    url = f"{FMP_BASE_URL}/{path.lstrip('/')}"
    full_url = f"{url}?{urlencode(q)}"

    req = Request(full_url, headers={"User-Agent": "aws-terraform-market-ingestion/1.0"})

    try:
        with urlopen(req, timeout=10) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            try:
                return resp.status, json.loads(body)
            except Exception:
                return resp.status, body

    except HTTPError as e:
        body = e.read().decode("utf-8", errors="replace") if hasattr(e, "read") else str(e)
        return e.code, body

    except URLError as e:
        return 599, {"error": "network_error", "details": str(e)}


def fetch_quote_free_safe(ticker: str) -> Tuple[int, Any]:
    """
    Free-safe endpoints only.
    - quote: /quote?symbol={ticker}
    """
    status, data = fmp_get("quote", {"symbol": ticker})
    if status == 200 and isinstance(data, list) and data:
        return 200, data[0]
    return status, data


# ---- DynamoDB Access --------------------------------------------------------

def ddb_key_latest(ticker: str) -> Dict[str, str]:
    return {"pk": f"TICKER#{ticker}", "sk": "LATEST#quote"}


def ddb_get_latest(ticker: str) -> Optional[Dict[str, Any]]:
    resp = table.get_item(Key=ddb_key_latest(ticker))
    return resp.get("Item")


def cache_valid(item: Optional[Dict[str, Any]]) -> bool:
    if not item:
        return False
    try:
        return int(item.get("expires_at", 0)) > epoch_now()
    except Exception:
        return False


def ddb_put_quote(ticker: str, status: int, payload: Any, cache_hit: bool) -> Dict[str, Any]:
    ts = iso_now()

    base_item = {
        "pk": f"TICKER#{ticker}",
        "sk": "LATEST#quote",
        "type": "quote",
        "ticker": ticker,
        "source": "FMP",
        "status": int(status),
        "cache_hit": bool(cache_hit),
        "ts": ts,
        "expires_at": epoch_now() + TTL_QUOTE_SECONDS,
        "payload": to_ddb_safe(payload),
    }

    table.put_item(Item=base_item)

    if WRITE_RUN_HISTORY:
        history_item = dict(base_item)
        history_item["sk"] = f"RUN#{ts}#quote"
        table.put_item(Item=history_item)

    return base_item


# ---- Business Logic ---------------------------------------------------------

def handle_ticker(ticker: str) -> Dict[str, Any]:
    ticker = ticker.strip().upper()

    cached = ddb_get_latest(ticker)
    if cache_valid(cached):
        logger.info("CACHE HIT ticker=%s", ticker)
        return {
            "ticker": ticker,
            "cache_hit": True,
            "expires_at": cached.get("expires_at"),
            "status": cached.get("status"),
            "payload": cached.get("payload"),
        }

    status, payload = fetch_quote_free_safe(ticker)

    if status == 402:
        logger.warning("FMP 402 (plan limitation) ticker=%s", ticker)
        saved = ddb_put_quote(
            ticker=ticker,
            status=status,
            payload={"available": False, "reason": "not_in_free_plan", "raw": payload},
            cache_hit=False,
        )
        return {"ticker": ticker, "cache_hit": False, "status": status, "saved": True, "ddb": {"pk": saved["pk"], "sk": saved["sk"]}}

    if status != 200:
        logger.error("FMP error ticker=%s status=%s", ticker, status)
        saved = ddb_put_quote(
            ticker=ticker,
            status=status,
            payload={"error": "upstream_error", "status": status, "raw": payload},
            cache_hit=False,
        )
        return {"ticker": ticker, "cache_hit": False, "status": status, "saved": True, "ddb": {"pk": saved["pk"], "sk": saved["sk"]}}

    logger.info("FMP OK ticker=%s", ticker)
    saved = ddb_put_quote(ticker=ticker, status=200, payload=payload, cache_hit=False)
    return {"ticker": ticker, "cache_hit": False, "status": 200, "saved": True, "ddb": {"pk": saved["pk"], "sk": saved["sk"]}}


def lambda_handler(event, context):
    # Hard-stop after the configured date to avoid unexpected charges.
    until = parse_run_until()
    if until and now_utc() > until:
        return {"statusCode": 200, "body": json.dumps({"disabled": True, "reason": "RUN_UNTIL_UTC passed"})}

    event = event or {}
    q = event.get("queryStringParameters") or {}

    # HTTP mode: /ticket?ticker=PLUG
    if "ticker" in q:
        ticker = (q.get("ticker") or "").strip().upper()
        if not ticker:
            return {"statusCode": 400, "body": json.dumps({"error": "missing_ticker"})}
        out = handle_ticker(ticker)
        return {"statusCode": 200, "body": json.dumps(out, default=str)}

    # Scheduled mode: run a chunk to keep daily calls bounded.
    idx = event_chunk_index(event)
    tickers = chunk(SCHEDULED_TICKERS, SCHEDULED_CHUNK_SIZE, idx)

    logger.info("SCHEDULED RUN chunk_index=%s tickers=%s", idx, len(tickers))

    results = []
    for t in tickers:
        try:
            results.append(handle_ticker(t))
        except Exception as e:
            logger.exception("Ticker failed: %s", t)
            results.append({"ticker": t, "error": str(e)})

    body = {
        "mode": "scheduled",
        "chunk_index": idx,
        "chunk_size": SCHEDULED_CHUNK_SIZE,
        "tickers_total": len(SCHEDULED_TICKERS),
        "tickers_run": tickers,
        "results": results,
    }
    return {"statusCode": 200, "body": json.dumps(body, default=str)}
