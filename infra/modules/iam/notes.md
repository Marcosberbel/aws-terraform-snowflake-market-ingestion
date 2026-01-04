# module/iam

## Qué crea
- Role IAM para Lambda con **mínimo privilegio**:
  - Escribir logs en CloudWatch
  - Leer/escribir en una tabla DynamoDB concreta

## Por qué
- En entrevistas esto suma muchísimo: permisos específicos por ARN, no `*`.
