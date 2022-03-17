### Maintenance inhibition alerts ###

groups:
- name: maintenance.alerts
  rules:
  - alert: NodeInMaintenance
    expr: kube_node_labels{label_cloud_sap_maintenance_state="in-maintenance"} == 1
    for: 15m
    labels:
      tier: {{ required ".Values.tier missing" .Values.tier }}
      service: node
      severity: none
      context: node
      meta: "Node {{`{{ $labels.node }}`}} is in maintenance."
    annotations:
      summary: Node in maintenance
      description: "Node {{`{{ $labels.node }}`}} is in scheduled maintenance. Add the label `inhibited-by: node-maintenance` to alerts that should be inhibited while a node is in maintenance"
