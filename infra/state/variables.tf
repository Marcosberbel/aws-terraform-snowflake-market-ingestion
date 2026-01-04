variable "project" {
  description = "Nombre del proyecto (para tags)."
  type        = string
}

variable "project_short" {
  description = "ID corto del proyecto para nombres de recursos (ej: atsmi, snowmkt, mkt-ing)."
  type        = string
}

variable "region" {
  description = "Región donde se crean los buckets de state y la tabla de locks."
  type        = string
  default     = "eu-south-2"
}

variable "environments" {
  description = "Lista de entornos a crear."
  type        = list(string)
  default     = ["dev", "pre", "pro"]
}

variable "bucket_suffix" {
  description = "Sufijo opcional para unicidad global de S3 (ej: mberbel, x7p9q2)."
  type        = string
  default     = ""
}
