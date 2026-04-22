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

{{/* This defines what the 'component' label should be for the Janeway Deployment and Pod */}}
{{- define "common.labels.component.app" -}}
  {{- if .Values.postgresql.enabled -}}
  app.kubernetes.io/component: primary
  {{- else -}}
  app.kubernetes.io/component: app
  {{- end -}}
{{- end -}}

{{/* This defines what the 'component' label should be for other related Janeway resources
(Ingress, networkpolicies, services, etc) */}}
{{- define "common.labels.component.other" -}}
  {{- if .Values.postgresql.enabled -}}
  app.kubernetes.io/component: primary
  {{- else }}
  {{- /* No label for other components when PostgreSQL is disabled */ -}}
  {{- end }}
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
  {{- if .Values.postgresql.enabled -}}
    {{- printf "%s" (include "postgresql.v1.primary.fullname" .Subcharts.postgresql) -}}
  {{- else -}}
    {{ default .Values.global.postgresql.hostname .Values.externalDatabase.hostname | required "You must include a Database Hostname." }}
  {{- end -}}
{{- end -}}

{{/*
Return the name of the database to use
*/}}
{{- define "janeway.database.name" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- printf "%s" (include "postgresql.v1.database" .Subcharts.postgresql) -}}
  {{- else -}}
    {{- printf "%s" (default .Values.global.postgresql.auth.database .Values.externalDatabase.database | required "You must provide the database name") -}}
  {{- end -}}
{{- end -}}

{{/*
Return the username of the database user
*/}}
{{- define "janeway.database.username" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- printf "%s" (include "postgresql.v1.username" .Subcharts.postgresql) -}}
  {{- else -}}
    {{- printf "%s" (default .Values.global.postgresql.auth.username .Values.externalDatabase.username | required "You must provide a database username") -}}
  {{- end -}}
{{- end -}}

{{/*
Return the name of the database secret to use
*/}}
{{- define "janeway.database.secret" -}}
  {{- $secretName := "" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- $secretName = ( include "postgresql.v1.secretName" .Subcharts.postgresql ) -}}
  {{- else -}}
    {{- $secretName = .Values.externalDatabase.externalSecret | default .Values.global.postgresql.auth.externalSecret -}}
  {{- end -}}
  {{ $secretName | required "You must include a database secret name." }}
{{- end -}}

{{/*
Get the user-password key for the database password
*/}}
{{- define "janeway.database.passwordKey" -}}
  {{- if .Values.postgresql.enabled -}}
    {{- printf "%s" (include "postgresql.v1.userPasswordKey" .Subcharts.postgresql) -}}
  {{- else if .Values.global.postgresql.auth.secretKeys.userPasswordKey -}}
    {{- printf "%s" (tpl .Values.global.postgresql.auth.secretKeys.userPasswordKey $) -}}
  {{- else if .Values.externalDatabase.userPasswordKey -}}
    {{- printf "%s" (tpl .Values.externalDatabase.userPasswordKey $) -}}
  {{- else -}}
    {{- "PGPASSWORD" -}}
  {{- end -}}
{{- end -}}

{{/*
Define Janeway options for setting up authentication

This is done using the same patterns as the Bitnami repos.
*/}}
{{- define "janeway.primary.auth.superUserUsername" -}}
    {{- if .Values.global.janeway.primary.auth.superUserUsername -}}
        {{- .Values.global.janeway.primary.auth.superUserUsername -}}
    {{- else -}}
        {{- .Values.primary.auth.superUserUsername | required "You must provide a superuser username." -}}
    {{- end -}}
{{- end -}}

{{- define "janeway.primary.auth.superUserPasswordKey" -}}
    {{- if or .Values.global.janeway.primary.auth.superUserPasswordKey .Values.primary.auth.superUserPasswordKey -}}
        {{- if  .Values.global.janeway.primary.auth.superUserPasswordKey -}}
            {{ .Values.global.janeway.primary.auth.superUserPasswordKey }}
        {{- else if  .Values.primary.auth.superUserPasswordKey -}}
            {{ .Values.primary.auth.superUserPasswordKey }}
        {{- end -}}
    {{- else -}}
        JANEWAY_PASSWORD
    {{- end -}}
{{ end }}

{{- define "janeway.primary.auth.superUserEmail" -}}
    {{- if or .Values.global.janeway.primary.auth.superUserEmail .Values.primary.auth.superUserEmail -}}
        {{- if  .Values.global.janeway.primary.auth.superUserEmail -}}
            {{ .Values.global.janeway.primary.auth.superUserEmail }}
        {{- else if  .Values.primary.auth.superUserEmail -}}
            {{ .Values.primary.auth.superUserEmail }}
        {{- end -}} 
    {{- end -}}
{{ end }}

{{- define "janeway.primary.persistence.claimName" -}}
  {{- if (.Values.global.janeway.primary.persistence.enabled | default .Values.primary.persistence.enabled ) -}}
    {{- if .Values.global.janeway.primary.persistence.existingClaim | default .Values.primary.persistence.existingClaim -}}
      {{ .Values.global.janeway.primary.persistence.existingClaim | default .Values.primary.persistence.existingClaim }}
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
  {{- if .Values.primary.ingress.enabled -}}
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
    {{- if $.Values.primary.ingress.enabled -}}
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

{{- define "janeway.primary.env" -}}
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
{{- $_ := (include "janeway.primary.auth.superUserUsername" .) | required "A Superuser Username is required for Janeway Install" -}}
{{- end -}}
- name: DJANGO_SUPERUSER_USERNAME
  value: {{ include "janeway.primary.auth.superUserUsername" . | quote }}
- name: DJANGO_SUPERUSER_PASSWORD
  valueFrom: 
    secretKeyRef:
      name: {{ default .Values.primary.auth.externalSecret .Values.global.janeway.primary.auth.externalSecret | required "You must reference a secret containing the Janeway Superuser Password in primary.auth.externalSecret (or the global equivalent)." }}
      key: {{ include "janeway.primary.auth.superUserPasswordKey" . | quote }}
{{ if .Release.IsInstall -}}
{{- $_ := (include "janeway.primary.auth.superUserEmail" .) | required "A Superuser Email in primary.auth.superUserEmail is required for Janeway install." -}}
{{- end -}}
- name: DJANGO_SUPERUSER_EMAIL
  value: {{ include "janeway.primary.auth.superUserEmail" . | quote }}
- name: JANEWAY_EMAIL_HOST
  value: {{ .Values.global.janeway.primary.email.host | default .Values.primary.email.host | quote }}
- name: JANEWAY_EMAIL_PORT
  value: {{ .Values.global.janeway.primary.email.port | default .Values.primary.email.port | quote }}
- name: JANEWAY_EMAIL_USE_TLS
  value: {{ .Values.global.janeway.primary.email.useTls | default .Values.primary.email.useTls | quote }}
- name: JANEWAY_ENABLE_ORCID
  value: {{ .Values.global.janeway.primary.enableOrcid | default .Values.primary.enableOrcid | quote }}
- name: DJANGO_DEBUG
  value: {{ .Values.primary.debug | default "false" | quote }}
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
{{ include "janeway.primary.env.plugins" . }}
{{ include "janeway.primary.env.additionalEnvVars" . }}
{{- end -}}

{{- define "janeway.primary.env.additionalEnvVars" -}}
  {{- if .Values.primary.env.additionalEnvVars -}}
    {{- range .Values.primary.env.additionalEnvVars -}}
- name: {{ .name }}
  value: {{ .value | quote }}
    {{ end -}}
  {{- end -}}
  {{- if .Values.global.janeway.primary.env.additionalEnvVars -}}
    {{- range .Values.global.janeway.primary.env.additionalEnvVars -}}
- name: {{ .name }}
  value: {{ .value | quote }}
    {{ end -}}
  {{- end -}}
{{- end -}}

{{- define "janeway.primary.env.plugins" -}}
- name: INSTALL_PANDOC_PLUGIN
  value: {{ if .Values.primary.plugins.pandocPlugin.install }}"TRUE"{{ else }}"FALSE"{{ end }}
- name: INSTALL_CUSTOMSTYLING_PLUGIN
  value: {{ if .Values.primary.plugins.customstylingPlugin.install }}"TRUE"{{ else }}"FALSE"{{ end }}
- name: INSTALL_PORTICO_PLUGIN
  value: {{ if .Values.primary.plugins.porticoPlugin.install }}"TRUE"{{ else }}"FALSE"{{ end }}
- name: INSTALL_IMPORTS_PLUGIN
  value: {{ if .Values.primary.plugins.importsPlugin.install }}"TRUE"{{ else }}"FALSE"{{ end }}
- name: INSTALL_DOAJ_TRANSPORTER_PLUGIN
  value: {{ if .Values.primary.plugins.DOAJTransporterPlugin.install }}"TRUE"{{ else }}"FALSE"{{ end }}
- name: INSTALL_BACK_CONTENT_PLUGIN
  value: {{ if .Values.primary.plugins.backContentPlugin.install }}"TRUE"{{ else }}"FALSE"{{ end }}
- name: INSTALL_REPORTING_PLUGIN
  value: {{ if .Values.primary.plugins.reportingPlugin.install }}"TRUE"{{ else }}"FALSE"{{ end }}
- name: INSTALL_DATACITE_PLUGIN
  value: {{ if .Values.primary.plugins.dataCitePlugin.install }}"TRUE"{{ else }}"FALSE"{{ end }}
{{- end -}}

{{/*
Volume Mounts used by Janeway App and it's CronJobs.
*/}}
{{- define "janeway.primary.webapp.volumeMounts" -}}
{{- include "janeway.primary.volumeMounts" . }}
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
{{- define "janeway.primary.volumeMounts" -}}
- mountPath: "/var/www/janeway"
  name: "files-vol"
  subPath: "janeway"
- mountPath: "/tmp"
  name: "temp-vol"
  subPath: "tmp"
{{- end -}}

{{- define "janeway.primary.webapp.image" -}}
{{ print (.Values.primary.imageOverride.repository | default "janeway-warpspeed") ":" (.Values.primary.imageOverride.tag | default "0.10.2") }}
{{- end -}}