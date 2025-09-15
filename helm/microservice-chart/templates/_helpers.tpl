{{/*
Expand the name of the chart.
*/}}
{{- define "microservice-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "microservice-chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "microservice-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "microservice-chart.labels" -}}
helm.sh/chart: {{ include "microservice-chart.chart" . }}
{{ include "microservice-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: microservice-platform
environment: {{ .Values.environment }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "microservice-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "microservice-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "microservice-chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database connection string
*/}}
{{- define "microservice-chart.databaseUrl" -}}
{{- if .Values.database.enabled }}
{{- printf "mysql://%s:%s@%s:%d/%s" .Values.database.username "$(DB_PASSWORD)" .Values.database.host (.Values.database.port | int) .Values.database.name }}
{{- end }}
{{- end }}

{{/*
Cache connection string
*/}}
{{- define "microservice-chart.cacheUrl" -}}
{{- if .Values.cache.enabled }}
{{- printf "redis://%s:%d" .Values.cache.host (.Values.cache.port | int) }}
{{- end }}
{{- end }}

{{/*
Environment-specific resource limits
*/}}
{{- define "microservice-chart.resources" -}}
{{- if eq .Values.environment "prod" }}
limits:
  cpu: 1000m
  memory: 1Gi
requests:
  cpu: 500m
  memory: 512Mi
{{- else if eq .Values.environment "staging" }}
limits:
  cpu: 750m
  memory: 768Mi
requests:
  cpu: 375m
  memory: 384Mi
{{- else }}
limits:
  cpu: 500m
  memory: 512Mi
requests:
  cpu: 250m
  memory: 256Mi
{{- end }}
{{- end }}

{{/*
Environment-specific replica count
*/}}
{{- define "microservice-chart.replicaCount" -}}
{{- if eq .Values.environment "prod" }}
{{- default 3 .Values.replicaCount }}
{{- else if eq .Values.environment "staging" }}
{{- default 2 .Values.replicaCount }}
{{- else }}
{{- default 1 .Values.replicaCount }}
{{- end }}
{{- end }}