#!/bin/bash
set -e

dnf install -y docker
systemctl enable --now docker

mkdir -p /opt/connectors-config
cat > /opt/connectors-config/config.yml << EOF
elasticsearch.host: ${elasticsearch_endpoint}
elasticsearch.api_key: ${connector_api_key}

connectors:
  - connector_id: ${connector_id}
    service_type: servicenow
    api_key: ${connector_api_key}
EOF

cat > /etc/systemd/system/elastic-connector.service << EOF
[Unit]
Description=Elastic Connector Service
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker run \
  --name elastic-connector \
  -v /opt/connectors-config:/config \
  ${connector_image} \
  /app/bin/elastic-ingest -c /config/config.yml
ExecStop=/usr/bin/docker stop elastic-connector
ExecStopPost=/usr/bin/docker rm -f elastic-connector

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable elastic-connector
systemctl start elastic-connector
