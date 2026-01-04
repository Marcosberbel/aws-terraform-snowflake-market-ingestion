# module/api-gateway

## Qué crea
- API Gateway **HTTP API** (v2) -> integración proxy con Lambda
- Ruta: `GET /quote`
- Stage `$default` con `auto_deploy`
- Permiso para invocar Lambda

## Probar
Tras `apply`, el output `api_endpoint` será algo como:
`https://xxxx.execute-api.eu-south-2.amazonaws.com`

Llamada:
`GET {api_endpoint}/quote?ticker=IBM`
