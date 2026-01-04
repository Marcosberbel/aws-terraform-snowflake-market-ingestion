# module/dynamodb

## Qué crea
- Tabla DynamoDB en modo **PAY_PER_REQUEST** (ideal para proyectos/entrevistas)
- PK simple: `ticker` (String)

## Por qué
- Serverless, sin capacity planning.
- Latencia baja para serving de API.

## Coste
- Solo pagas por requests y almacenamiento. Con poco tráfico, suele ser céntimos.
