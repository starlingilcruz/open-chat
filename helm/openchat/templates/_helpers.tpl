{{/*
Expand the name of the chart.
*/}}
{{- define "openchat.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "openchat.fullname" -}}
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
{{- define "openchat.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openchat.labels" -}}
helm.sh/chart: {{ include "openchat.chart" . }}
{{ include "openchat.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openchat.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openchat.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Web component labels
*/}}
{{- define "openchat.web.labels" -}}
{{ include "openchat.labels" . }}
app: {{ .Values.app.name }}
component: web
{{- end }}

{{/*
DB component labels
*/}}
{{- define "openchat.db.labels" -}}
{{ include "openchat.labels" . }}
app: {{ .Values.app.name }}
component: db
{{- end }}

{{/*
Redis component labels
*/}}
{{- define "openchat.redis.labels" -}}
{{ include "openchat.labels" . }}
app: {{ .Values.app.name }}
component: redis
{{- end }}
