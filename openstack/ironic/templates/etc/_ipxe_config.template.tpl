{{- define "ipxe_config_template" -}}
{{- $conductor := index . 1 -}}
{{- with index . 0 -}}
{{`#!ipxe

set attempts:int32 10
set i:int32 0

goto deploy

:deploy
imgfree
kernel {% if pxe_options.ipxe_timeout > 0 %}--timeout {{ pxe_options.ipxe_timeout }} {% endif %}{{ pxe_options.deployment_aki_path }} selinux=0 troubleshoot=0 text {{ pxe_options.pxe_append_params|default("", true) }} BOOTIF=${mac} initrd={{ pxe_options.initrd_filename|default("deploy_ramdisk", true) }}  || chain `}}{{ printf "http://%v:%v/%v" .Values.global.ironic_tftp_ip .Values.conductor.deploy.port $conductor.pxe.pxe_bootfile_name }}{{` || goto retry

initrd {% if pxe_options.ipxe_timeout > 0 %}--timeout {{ pxe_options.ipxe_timeout }} {% endif %}{{ pxe_options.deployment_ari_path }} || goto retry
boot

:retry
iseq ${i} ${attempts} && goto fail ||
inc i
echo No response, retrying in ${i} seconds.
sleep ${i}
goto deploy

:fail
echo Failed to get a response after ${attempts} attempts
echo Powering off in 30 seconds.
sleep 30
poweroff

:boot_partition
imgfree
kernel {% if pxe_options.ipxe_timeout > 0 %}--timeout {{ pxe_options.ipxe_timeout }} {% endif %}{{ pxe_options.aki_path }} root={{ ROOT }} ro text {{ pxe_options.pxe_append_params|default("", true) }} initrd=ramdisk || goto boot_partition
initrd {% if pxe_options.ipxe_timeout > 0 %}--timeout {{ pxe_options.ipxe_timeout }} {% endif %}{{ pxe_options.ari_path }} || goto boot_partition
boot

:boot_anaconda
imgfree
kernel {% if pxe_options.ipxe_timeout > 0 %}--timeout {{ pxe_options.ipxe_timeout }} {% endif %}{{ pxe_options.aki_path }} text {{ pxe_options.pxe_append_params|default("", true) }} inst.ks={{ pxe_options.ks_cfg_url }} inst.stage2={{ pxe_options.stage2_url }} initrd=ramdisk || goto boot_anaconda
initrd {% if pxe_options.ipxe_timeout > 0 %}--timeout {{ pxe_options.ipxe_timeout }} {% endif %}{{ pxe_options.ari_path }} || goto boot_anaconda
boot

:boot_ramdisk
imgfree
{%- if pxe_options.boot_iso_url %}
sanboot {{ pxe_options.boot_iso_url }}
{%- else %}
kernel {% if pxe_options.ipxe_timeout > 0 %}--timeout {{ pxe_options.ipxe_timeout }} {% endif %}{{ pxe_options.aki_path }} root=/dev/ram0 text {{ pxe_options.pxe_append_params|default("", true) }} {{ pxe_options.ramdisk_opts|default('', true) }} initrd=ramdisk || goto boot_ramdisk
initrd {% if pxe_options.ipxe_timeout > 0 %}--timeout {{ pxe_options.ipxe_timeout }} {% endif %}{{ pxe_options.ari_path }} || goto boot_ramdisk
boot
{%- endif %}

{%- if pxe_options.boot_from_volume %}

:boot_iscsi
imgfree
{% if pxe_options.username %}set username {{ pxe_options.username }}{% endif %}
{% if pxe_options.password %}set password {{ pxe_options.password }}{% endif %}
{% if pxe_options.iscsi_initiator_iqn %}set initiator-iqn {{ pxe_options.iscsi_initiator_iqn }}{% endif %}
sanhook --drive 0x80 {{ pxe_options.iscsi_boot_url }} || goto fail_iscsi_retry
{%- if pxe_options.iscsi_volumes %}{% for i, volume in enumerate(pxe_options.iscsi_volumes) %}
set username {{ volume.username }}
set password {{ volume.password }}
{%- set drive_id = 129 + i %}
sanhook --drive {{ '0x%x' % drive_id }} {{ volume.url }} || goto fail_iscsi_retry
{%- endfor %}{% endif %}
{% if pxe_options.iscsi_volumes %}set username {{ pxe_options.username }}{% endif %}
{% if pxe_options.iscsi_volumes %}set password {{ pxe_options.password }}{% endif %}
sanboot --no-describe || goto fail_iscsi_retry

:fail_iscsi_retry
echo Failed to attach iSCSI volume(s), retrying in 10 seconds.
sleep 10
goto boot_iscsi
{%- endif %}

:boot_whole_disk
sanboot --no-describe`}}
{{- end }}
{{- end }}
