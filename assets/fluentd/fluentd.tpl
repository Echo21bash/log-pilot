{{range .configList}}
<source>
  @type tail
  tag docker.{{ $.containerId }}.{{ .Name }}
  path {{ .HostDir }}/{{ .File }}
  exclude_path ["{{ .HostDir }}/*.gz", "{{ .HostDir }}/*.zip"]
  follow_inodes true
  <parse>
    {{if .Stdout}}
    @type json
    {{else}}
    @type {{ .Format }}
    {{end}}
    {{ $time_key := "" }}
    {{if .FormatConfig}}
    {{range $key, $value := .FormatConfig}}
    {{ $key }} {{ $value }}
    {{end}}
    {{end}}
    {{ if .EstimateTime }}
    estimate_current_event true
    {{end}}
    keep_time_key true
  </parse>
  read_from_head false
  pos_file /pilot/pos/{{ $.containerId }}.{{ .Name }}.pos
</source>

{{if .Stdout}}
<filter docker.{{ $.containerId }}.{{ .Name }}>
  @type parser
  key_name log
  <parse>
    @type multi_format
    <pattern>
     {{ if and (ne .Format "none") (ne .Format "nginx" ) (ne .Format "json" ) (ne .Format "csv" ) (ne .Format "apache2" ) }}
      format regexp
      expression {{ .Format }}
      {{else}}
      format {{ .Format }}
      {{end}}
    </pattern>
  </parse>
</filter>
{{end}}

<filter docker.{{ $.containerId }}.{{ .Name }}>
  @type concat
  key log
  stream_identity_key container_id
  multiline_start_regexp /^(\d{4}-\d{1,2}-\d{1,2}|\[\w+\]\s)/
  separator ""
  flush_interval 10
  timeout_label @NORMAL
</filter>

<filter docker.{{ $.containerId }}.{{ .Name }}>
  @type record_transformer
  enable_ruby true
  <record>
    host "#{Socket.gethostname}"
    {{range $key, $value := .Tags}}
    {{ $key }} {{ $value }}
    {{end}}
    {{if eq $.output "elasticsearch"}}
    _target {{if .Target}}{{.Target}}-${time.strftime('%Y.%m.%d')}{{else}}{{ .Name }}-${time.strftime('%Y.%m.%d')}{{end}}
    {{else}}
    _target {{if .Target}}{{.Target}}{{else}}{{ .Name }}{{end}}
    {{end}}
    {{range $key, $value := $.container}}
    {{ $key }} {{ $value }}
    {{end}}
    @timestamp ${Time.now.utc.iso8601}
    message ${record["log"]}
  </record>
    remove_keys log
</filter>

<match docker.{{ $.containerId }}.{{ .Name }}>
  @label @NORMAL
  @type relabel
</match>
{{end}}