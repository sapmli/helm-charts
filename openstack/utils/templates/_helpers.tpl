{{- define "joinKey" -}}
{{ range $item, $_ := . -}}{{$item | replace "." "_" -}},{{- end }}
{{- end -}}

{{- define "util.helpers.valuesToIni" -}}
  {{- range $section, $values := . -}}
[{{ $section }}]
    {{- range $key, $value := $values}}
{{ $key }} = {{ $value }}
    {{- end }}

{{ end }}
{{- end }}

{{- define "loggerIni" -}}
{{ range $top_level_key, $value := . }}
[{{ $top_level_key }}]
keys={{ include "joinKey" $value | trimAll "," }}
{{range $item, $values := $value}}

[{{ $top_level_key | trimSuffix "s" }}_{{ $item | replace "." "_" }}]
{{- if and (eq $top_level_key "loggers") (ne $item "root")}}
qualname={{ $item }}
propagate=0
{{- end}}
{{- range $key, $value := $values }}
{{ $key }}={{ $value }}
{{- end }}
{{- end }}
{{ end }}
{{- end }}

{{- define "osprofiler" }}
{{- if .Values.osprofiler.enabled }}
[profiler]
enabled = true
connection_string = jaeger://localhost:6831
hmac_keys = {{ .Values.global.osprofiler.hmac_keys }}
trace_sqlalchemy = {{ .Values.global.osprofiler.trace_sqlalchemy }}
{{- end }}
{{- end }}

{{- define "osprofiler_pipe" }}
    {{- if .Values.osprofiler.enabled }} osprofiler{{ end -}}
{{- end }}

{{- define "jaeger_agent_sidecar" }}
{{- if .Values.osprofiler.enabled }}
- image: {{.Values.global.dockerHubMirrorAlternateRegion}}/jaegertracing/jaeger-agent:{{ .Values.global.osprofiler.jaeger.version }}
  name: jaeger-agent
  ports:
    - containerPort: 5775
      name: zk-compact-trft
      protocol: UDP
    - containerPort: 6831
      name: jg-compact-trft
      protocol: UDP
    - containerPort: 6832
      name: jg-binary-trft
      protocol: UDP
    - containerPort: 5778
      name: config-rest
      protocol: TCP
    - containerPort: 14271
      name: admin-http
      protocol: TCP
  args:
    - --reporter.grpc.host-port=openstack-jaeger-collector.{{ .Release.Namespace }}.svc:14250
    - --log-level=debug
{{- end }}
{{- end }}

{{- define "utils.proxysql.volume_mount" }}
  {{- if .Values.proxysql }}
    {{- if .Values.proxysql.mode }}{{/* Always mount it, it doesn't cost much and eases migrations */}}
- mountPath: /run/proxysql
  name: runproxysql
    {{- end }}
  {{- end }}
{{- end }}

{{- define "utils.proxysql.container" }}
  {{- if .Values.proxysql }}
    {{- if .Values.proxysql.mode }}
- name: proxysql
  image: {{ required ".Values.global.dockerHubMirror is missing" .Values.global.dockerHubMirror}}/{{ default "proxysql/proxysql" .Values.proxysql.image }}:{{ .Values.proxysql.imageTag | default "2.4.1-debian" }}
  imagePullPolicy: IfNotPresent
  command: ["proxysql"]
  args: ["--config", "/etc/proxysql/proxysql.cnf", "--exit-on-error", "--foreground", "--idle-threads", "--admin-socket", "/run/proxysql/admin.sock", "--no-version-check", "-D", "/run/proxysql"]
  ports:
  - name: metrics-psql
    containerPort: {{ default 6070 .Values.proxysql.restapi_port }}
  livenessProbe:
    exec:
      command:
      - test
      - -S
      - /run/proxysql/mysql.sock
  volumeMounts:
  - mountPath: /etc/proxysql
    name: etcproxysql
    {{- include "utils.proxysql.volume_mount" . | indent 2 }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "utils.proxysql.volumes" }}
  {{- if .Values.proxysql }}
    {{- if .Values.proxysql.mode }}
- name: runproxysql
  emptyDir: {}
- name: etcproxysql
  configMap:
    name: {{ .Release.Name }}-proxysql-etc
    {{- end }}
  {{- end }}
{{- end }}

# Place this to the pod spec to reroute the traffic via hostAliases
{{- define "utils.proxysql.pod_settings" }}
  {{- if .Values.proxysql }}
    {{- if .Values.proxysql.mode }}
    {{- $envAll := . }}
hostAliases:
- ip: "127.0.0.1"
  hostnames:
      {{- range $d := .Chart.Dependencies }}
        {{- if and $d.Enabled (hasPrefix "mariadb" $d.Name)}}
  - {{ print (get $envAll.Values $d.Name).name "-mariadb" | quote }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}


# Place this to the pod spec of a job to allow the job to
# stop the sidecar pod via pkill
{{- define "utils.proxysql.job_pod_settings" }}
  {{- if .Values.proxysql }}
    {{- if .Values.proxysql.mode }}
{{- include "utils.proxysql.pod_settings" . }}
shareProcessNamespace: true
securityContext:
  runAsUser: 65534
    {{- end }}
  {{- end }}
{{- end }}

# Place this in job scripts when your script stops normally, but not abnormally
# as this causes the side-car pod finish normally, but we need it for the re-runs
{{- define "utils.proxysql.proxysql_signal_stop_script" }}
  {{- if .Values.proxysql }}
    {{- if .Values.proxysql.mode }}
pkill proxysql || true
    {{- end }}
  {{- end }}
{{- end }}
