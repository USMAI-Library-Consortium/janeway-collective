{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "janeway.fullname" -}}
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

{{/* This defines what the 'component' label should be for the Janeway Deployment and Pod
See ADR-1 for more information. */}}
{{- define "common.labels.component.app" -}}
  app.kubernetes.io/component: server
{{- end -}}

{{/* This defines what the 'component' label should be for other related Janeway resources
(Ingress, networkpolicies, services, etc). See ADR-1 for more information. */}}
{{- define "common.labels.component.other" -}}
  app.kubernetes.io/component: server
{{- end -}}

{{/*
Credit to Christian Huth for the excellent user guide on this: https://christianhuth.de/best-way-to-use-bitnamis-database-helm-charts/
The following 5 sections use his template and guidance.

These variables allow for deploying different database options.
*/}}

{{/*
Return the hostname of the database to use
*/}}
{{- define "janeway.database.hostname" -}}
    {{ default .Values.global.postgresql.hostname .Values.externalDatabase.hostname | required "You must include a Database Hostname." }}
{{- end -}}

{{/*
Return the name of the database to use
*/}}
{{- define "janeway.database.name" -}}
    {{- printf "%s" (default .Values.global.postgresql.auth.database .Values.externalDatabase.database | required "You must provide the database name") -}}
{{- end -}}

{{/*
Return the username of the database user
*/}}
{{- define "janeway.database.username" -}}
    {{- printf "%s" (default .Values.global.postgresql.auth.username .Values.externalDatabase.username | required "You must provide a database username") -}}
{{- end -}}

{{/*
Return the name of the database secret to use
*/}}
{{- define "janeway.database.secret" -}}
  {{ .Values.externalDatabase.externalSecret | default .Values.global.postgresql.auth.externalSecret | required "You must include a database secret name." }}
{{- end -}}

{{/*
Get the user-password key for the database password
*/}}
{{- define "janeway.database.passwordKey" -}}
  {{- if .Values.global.postgresql.auth.secretKeys.userPasswordKey -}}
    {{- printf "%s" (tpl .Values.global.postgresql.auth.secretKeys.userPasswordKey $) -}}
  {{- else if .Values.externalDatabase.userPasswordKey -}}
    {{- printf "%s" (tpl .Values.externalDatabase.userPasswordKey $) -}}
  {{- else -}}
    {{- "PGPASSWORD" -}}
  {{- end -}}
{{- end -}}

{{/*
Define Janeway options for setting up authentication
*/}}
{{- define "janeway.auth.superUserUsername" -}}
    {{- if .Values.global.janeway.auth.superUserUsername -}}
        {{- .Values.global.janeway.auth.superUserUsername -}}
    {{- else -}}
        {{- .Values.auth.superUserUsername | required "You must provide a superuser username." -}}
    {{- end -}}
{{- end -}}

{{/* Specify the environment variable containing the password key */}}
{{- define "janeway.auth.superUserPasswordKey" -}}
    {{- if or .Values.global.janeway.auth.superUserPasswordKey .Values.auth.superUserPasswordKey -}}
        {{- if  .Values.global.janeway.auth.superUserPasswordKey -}}
            {{ .Values.global.janeway.auth.superUserPasswordKey }}
        {{- else if  .Values.auth.superUserPasswordKey -}}
            {{ .Values.auth.superUserPasswordKey }}
        {{- end -}}
    {{- else -}}
        JANEWAY_PASSWORD
    {{- end -}}
{{ end }}

{{- define "janeway.auth.superUserEmail" -}}
    {{- if or .Values.global.janeway.auth.superUserEmail .Values.auth.superUserEmail -}}
        {{- if  .Values.global.janeway.auth.superUserEmail -}}
            {{ .Values.global.janeway.auth.superUserEmail }}
        {{- else if  .Values.auth.superUserEmail -}}
            {{ .Values.auth.superUserEmail }}
        {{- end -}} 
    {{- end -}}
{{ end }}

{{- define "janeway.persistence.claimName" -}}
  {{- if (.Values.global.janeway.persistence.enabled | default .Values.persistence.enabled ) -}}
    {{- if .Values.global.janeway.persistence.existingClaim | default .Values.persistence.existingClaim -}}
      {{ .Values.global.janeway.persistence.existingClaim | default .Values.persistence.existingClaim }}
    {{- else -}}
    {{- /* Create a PVC name */ -}}
      {{ include "janeway.fullname" . }}-app
    {{- end -}}
  {{- else -}}
  ""
  {{- end -}}
{{- end -}}


{{/*
Define Janeway options for setting up domains
*/}}

{{/* Get the final networking values for the Janeway Press */}}
{{- define "janeway.press.networking" -}}
  {{- $domain := ( .Values.global.janeway.press.networking.domain | default .Values.press.networking.domain | required "You must provide the press domain name." ) -}}
  {{- $secretName := "" -}}
  {{- if .Values.ingress.enabled -}}
    {{- $secret := ( .Values.global.janeway.press.networking.externalSecret | default .Values.press.networking.externalSecret ) -}}
    {{- if $secret -}}
      {{- $secretName = $secret -}}
    {{- else -}}
      {{- $secretName = printf "%s-tls" $domain  -}}
    {{- end -}}
  {{- end -}}
  {{ dict "domain" $domain "secretName" $secretName | toJson }}
{{- end -}}

{{/* Get the final networking values for Janeway journals */}}
{{- define "janeway.journals.networking" -}}
  {{- $journals := ( .Values.global.janeway.journals.networking | default .Values.journals.networking ) -}}
  {{ $results := list }}
  {{- range $journals -}}
    {{- $secretName := "" -}}
    {{- if $.Values.ingress.enabled -}}
      {{- if .externalSecret -}}
        {{- $secretName = .externalSecret -}}
      {{- else -}}
        {{- $secretName = printf "%s-tls" .domain  -}}
      {{- end -}}
    {{- end -}}
    {{- $results = append $results ( dict "domain" .domain "secretName" $secretName ) -}}
  {{- end -}}
  {{- $results | toYaml -}}
{{- end -}}

{{- define "janeway.env" -}}
# DATABASE CONNECTION
- name: DB_USER
  value: {{ include "janeway.database.username" . | quote }}
- name: DB_NAME
  value: {{ include "janeway.database.name" . | quote }}
- name: DB_HOST
  value: {{ include "janeway.database.hostname" . | quote}}
- name: DB_PORT
  value: "5432"
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ ( include "janeway.database.secret" . ) | required "You must have a database secret." | quote }}
      key: {{ include "janeway.database.passwordKey" . | quote }}
- name: JANEWAY_PORT
  value: "8050"
- name: JANEWAY_PRESS_DOMAIN
  value: {{ (include "janeway.press.networking" . | fromJson).domain | quote }}
- name: JANEWAY_PRESS_DOMAIN_SCHEME
  value: {{ (include "janeway.press.networking" . | fromJson).scheme | default "https://" | quote }}
{{ if .Release.IsInstall -}}
{{- $_ := .Values.press.name | required "Press name is required for Janeway install" -}}
{{- end -}}
- name: JANEWAY_PRESS_NAME
  value: {{ .Values.press.name | quote }}
{{ if .Release.IsInstall -}}
{{- $_ := .Values.press.contact | required "Press contact is required for Janeway install" -}}
{{- end -}}
- name: JANEWAY_PRESS_CONTACT
  value: {{ .Values.press.contact | quote }}
{{ if .Release.IsInstall -}}
{{- $_ := .Values.journals.initial.code | required "A code for an initial journal is required for Janeway install" -}}
{{- end -}}
- name: JANEWAY_JOURNAL_CODE
  value: {{ .Values.journals.initial.code | quote }}
{{ if .Release.IsInstall -}}
{{- $_ := .Values.journals.initial.name | required "A name for an initial journal is required for Janeway install" -}}
{{- end -}}
- name: JANEWAY_JOURNAL_NAME
  value: {{ .Values.journals.initial.name | quote}}
# DJANGO ADMIN AUTH VARIABLES
{{ if .Release.IsInstall -}}
{{- $_ := (include "janeway.auth.superUserUsername" .) | required "A Superuser Username is required for Janeway Install" -}}
{{- end -}}
- name: DJANGO_SUPERUSER_USERNAME
  value: {{ include "janeway.auth.superUserUsername" . | quote }}
- name: DJANGO_SUPERUSER_PASSWORD
  valueFrom: 
    secretKeyRef:
      name: {{ default .Values.global.janeway.auth.externalSecret .Values.auth.externalSecret  | required "You must reference a secret containing the Janeway Superuser Password in auth.externalSecret (or the global equivalent)." }}
      key: {{ include "janeway.auth.superUserPasswordKey" . | quote }}
{{ if .Release.IsInstall -}}
{{- $_ := (include "janeway.auth.superUserEmail" .) | required "A Superuser Email in auth.superUserEmail is required for Janeway install." -}}
{{- end -}}
- name: DJANGO_SUPERUSER_EMAIL
  value: {{ include "janeway.auth.superUserEmail" . | quote }}
- name: JANEWAY_EMAIL_HOST
  value: {{ .Values.global.janeway.email.host | default .Values.email.host | quote }}
- name: JANEWAY_EMAIL_PORT
  value: {{ .Values.global.janeway.email.port | default .Values.email.port | quote }}
- name: JANEWAY_EMAIL_USE_TLS
  value: {{ .Values.global.janeway.email.useTls | default .Values.email.useTls | quote }}
- name: JANEWAY_ENABLE_ORCID
  value: {{ .Values.global.janeway.enableOrcid | default .Values.enableOrcid | quote }}
- name: DJANGO_DEBUG
  value: {{ .Values.debug | default "false" | quote }}
- name: JANEWAY_JOURNAL_DOMAINS
  # Add journal domains so that Django can allow them in CSRF.
  {{ $journals := ( .Values.global.janeway.journals.networking | default .Values.journals.networking ) -}}
  {{- $domains := list -}}
  {{- range $journals -}}
  {{- $domains = append $domains .domain -}}
  {{- end -}}
  value: {{ (join "," $domains) | quote }}
- name: JANEWAY_JOURNAL_DOMAIN_SCHEMES
  {{ $schemes := list -}}
  {{- range $journals -}}
  {{- $schemes = append $schemes (.scheme | default "https://") -}}
  {{- end -}}
  value: {{ (join "," $schemes) | quote }}
- name: JANEWAY_DEFAULT_JOURNAL_INDEX
  value: {{ .Values.journals.initial.domainIndex | default "" | quote }}
- name: INSTALL_CRON
  value: "FALSE"
{{ include "janeway.env.additionalEnvVars" . }}
{{- end -}}

{{/*
Renders a single env var entry.
Supports:
  - name: FOO
    value: "bar"
  - name: SECRET_VAR
    valueFrom:
      secretKeyRef:
        name: my-secret
        key: my-key
        optional: true          # optional
  - name: CM_VAR
    valueFrom:
      configMapKeyRef:
        name: my-configmap
        key: my-key
*/}}
{{- define "janeway.env.renderVar" -}}
- name: {{ .name }}
{{- if .valueFrom }}
  valueFrom:
  {{- if .valueFrom.secretKeyRef }}
    secretKeyRef:
      name: {{ .valueFrom.secretKeyRef.name }}
      key: {{ .valueFrom.secretKeyRef.key }}
    {{- if hasKey .valueFrom.secretKeyRef "optional" }}
      optional: {{ .valueFrom.secretKeyRef.optional }}
    {{- end }}
  {{- else if .valueFrom.configMapKeyRef }}
    configMapKeyRef:
      name: {{ .valueFrom.configMapKeyRef.name }}
      key: {{ .valueFrom.configMapKeyRef.key }}
    {{- if hasKey .valueFrom.configMapKeyRef "optional" }}
      optional: {{ .valueFrom.configMapKeyRef.optional }}
    {{- end }}
  {{- end }}
{{- else }}
  value: {{ .value | quote }}
{{- end }}
{{- end }}

{{- define "janeway.env.additionalEnvVars" -}}
{{- if .Values.env.additionalEnvVars }}
{{- range .Values.env.additionalEnvVars }}
{{ include "janeway.env.renderVar" . }}
{{- end }}
{{- end }}
{{- if .Values.global.janeway.env.additionalEnvVars }}
{{- range .Values.global.janeway.env.additionalEnvVars }}
{{ include "janeway.env.renderVar" . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Volume Mounts used by Janeway App and it's CronJobs.
*/}}
{{- define "janeway.webapp.volumeMounts" -}}
{{- include "janeway.volumeMounts" . }}
- mountPath: "/vol/janeway/src/files"
  name: "files-vol"
  subPath: "src/files"
- mountPath: "/vol/janeway/src/plugins"
  name: "files-vol"
  subPath: "src/plugins"
# Mount XSL file folder, as some of these are generated dynamically
- mountPath: "/vol/janeway/src/transform/xsl"
  name: "files-vol"
  subPath: "xsl"
# Ironically, the static folder also has to be mounted dynamically
- mountPath: "/vol/janeway/src/static"
  name: "files-vol"
  subPath: "static"
- mountPath: "/run"
  name: "temp-vol"
  subPath: "run"
{{- end -}}

{{/*
Volume Mounts shared between Janeway and Nginx.
*/}}
{{- define "janeway.volumeMounts" -}}
- mountPath: "/var/www/janeway"
  name: "files-vol"
  subPath: "janeway"
- mountPath: "/tmp"
  name: "temp-vol"
  subPath: "tmp"
{{- end -}}

{{- define "janeway.webapp.image" -}}
{{ print (.Values.image.repository) ":" (.Values.image.tag) }}
{{- end -}}