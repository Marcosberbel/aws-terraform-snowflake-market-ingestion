# aws-terraform-snowflake-market-ingestion

Pipeline **serverless** en AWS gestionado con **Terraform** para:
1) Exponer un endpoint HTTP (`/ticket` y `/resolve`)
2) Consultar una API externa (market data)
3) Normalizar la respuesta
4) Persistirla en **DynamoDB** con **caché (TTL)** para minimizar llamadas
5) (Futuro) Volcar a S3/Snowflake en fases posteriores

> **Motivo técnico clave:** En `eu-south-2` se usa **API Gateway HTTP API** en lugar de **Lambda Function URL** (limitaciones/región).

---

## Tabla de contenidos
- [Objetivo](#objetivo)
- [Arquitectura](#arquitectura)
- [Decisiones de diseño](#decisiones-de-diseño)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Requisitos](#requisitos)
- [Quickstart (DEV)](#quickstart-dev)
- [Cómo desplegar (DEV)](#cómo-desplegar-dev)
- [Cómo probar la API](#cómo-probar-la-api)
- [Modelo de datos en DynamoDB](#modelo-de-datos-en-dynamodb)
- [Consultar DynamoDB (AWS CLI)](#consultar-dynamodb-aws-cli)
- [Costes y guardarraíles](#costes-y-guardarraíles)
- [Seguridad](#seguridad)
- [Calidad (opcional)](#calidad-opcional)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)

---

## Objetivo

Construir una base **profesional** (IaC + API + persistencia) para ingestar datos de mercado
(por ejemplo: cotizaciones, perfiles, histórico y, si el proveedor lo permite, noticias/eventos).

El proyecto está planteado para crecer:
- DEV: serverless y barato, ideal para iterar rápido
- PRE/PROD: promoción por entornos y mejores controles (auth, secrets, CI/CD, observabilidad)

---

## Arquitectura

**Flujo principal**
1. Cliente llama: `GET /ticket?ticker=PLUG`
2. **API Gateway HTTP API** invoca la Lambda (proxy)
3. **Lambda**:
   - llama a una API externa (FMP en este proyecto)
   - normaliza el payload
   - persiste cachés y resultados en **DynamoDB**
4. Lambda devuelve JSON con datos + metadatos (cache HIT/MISS, timestamp, etc.)

**Servicios AWS**
- Terraform backend remoto: **S3** (state) + **DynamoDB** (locks)
- Runtime: **AWS Lambda** (Python)
- Exposición HTTP: **API Gateway v2 (HTTP API)**
- Persistencia: **DynamoDB** (on-demand, PAY_PER_REQUEST)
- Logging: **CloudWatch Logs**

---

## Decisiones de diseño

### Por qué serverless en DEV
- Minimiza costes fijos (evita NAT Gateway, ALB, ECS/Fargate)
- Escala automáticamente
- Reproducible (Terraform + empaquetado ZIP)

### Por qué DynamoDB
- Baja latencia, on-demand, esquema flexible
- Ideal para caché + “event log” de ingestas por ticker

### Por qué separar en ficheros numerados
Terraform carga todos los `.tf` del directorio como una unidad; los ficheros son organización humana.  
Los números ayudan a mantener un orden visual y facilitan mantenimiento.

---

## Estructura del repositorio

```text
.
├─ app/
│  └─ lambda_api/
│     └─ handler.py                # parseo request, fetch API externa, normalización, put/get DynamoDB
│
└─ infra/
   ├─ bootstrap/                   # opcional: recursos base del backend remoto (bucket tfstate + lock table)
   │  ├─ main.tf
   │  ├─ providers.tf
   │  └─ versions.tf
   │
   └─ envs/
      └─ dev/
         ├─ 00-backend.tf          # backend remoto (S3 + DynamoDB locks)
         ├─ 01-providers.tf        # provider AWS + archive
         ├─ 02-variables.tf        # variables (region, profile, fmp_api_key)
         ├─ 05-locals.tf           # naming + tags
         ├─ 10-storage-ddb.tf      # DynamoDB principal
         ├─ 20-iam.tf              # IAM role/policies para Lambda (mínimo privilegio)
         ├─ 30-lambda.tf           # empaquetado zip + lambda function + env vars
         ├─ 40-api-http.tf         # API Gateway HTTP API, integración proxy y permisos
         └─ 99-outputs.tf          # outputs (endpoint, tabla, región)
