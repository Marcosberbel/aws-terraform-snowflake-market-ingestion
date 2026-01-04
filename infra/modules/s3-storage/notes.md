# module/s3-storage

## Qué crea
- Bucket S3 (NO es el bucket de state)
- Public access block (bloqueo total)
- Cifrado SSE-S3 (AES256)
- Versioning (configurable)

## Por qué
Este bucket es para datos del proyecto (ej: dumps JSON, ficheros para Snowpipe, etc.)
- Seguridad por defecto: sin público + cifrado.

## Coste
- Casi 0 si no guardas mucho (solo almacenamiento).
