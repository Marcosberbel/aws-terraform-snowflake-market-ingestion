data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../app/lambda_api"
  output_path = "${path.module}/lambda_api.zip"
}

resource "aws_lambda_function" "api" {
  function_name = "${local.project}-api-${local.env}"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 20
  memory_size = 256

  environment {
    variables = {
      # Core
      DDB_TABLE = aws_dynamodb_table.quotes.name
      LOG_LEVEL = "INFO"

      # FMP
      FMP_BASE_URL = "https://financialmodelingprep.com/stable"
      FMP_API_KEY  = var.fmp_api_key

      # Cost guards
      TTL_QUOTE_SECONDS = "28800"
      WRITE_RUN_HISTORY = "true"

      # 50 tickers total -> 17/17/16 each day
      SCHEDULED_TICKERS    = "PLUG,ORCL,QBTS,TSLA,AAPL,MSFT,AMZN,NVDA,META,GOOGL,AMD,INTC,PLTR,PYPL,SQ,SHOP,NET,CRWD,DDOG,SNOW,UBER,ABNB,DIS,NKE,KO,PEP,JPM,BAC,GS,MS,V,MA,BRK.B,XOM,CVX,COP,CAT,BA,GE,IBM,CRM,ADBE,CSCO,NOW,AVGO,QCOM,T,TMUS"
      SCHEDULED_CHUNK_SIZE = "17"

      # Auto-stop (set to +7 days)
      RUN_UNTIL_UTC = "2025-12-27T00:00:00Z"
    }
  }
}
