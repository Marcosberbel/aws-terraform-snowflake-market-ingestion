import json
import os
import time
import boto3

TABLE_NAME = os.environ.get("TABLE_NAME", "")
dynamodb = boto3.resource("dynamodb") if TABLE_NAME else None

def lambda_handler(event, context):
    # Endpoint simple para entrevistas:
    # - Lee querystring ?ticker=IBM
    # - Guarda/actualiza en DynamoDB con timestamp
    # - Devuelve respuesta JSON
    qs = (event.get("queryStringParameters") or {})
    ticker = (qs.get("ticker") or "IBM").upper()
    now = int(time.time())

    if dynamodb:
        table = dynamodb.Table(TABLE_NAME)
        table.put_item(Item={"ticker": ticker, "updated_at": now})

    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps({"ticker": ticker, "updated_at": now, "stored": bool(dynamodb)})
    }
