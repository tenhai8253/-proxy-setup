#!/bin/bash

DEFAULT_START_PORT_SOCKS5=20000  # 默认 SOCKS5 代理起始端口
DEFAULT_START_PORT_HTTP=30000    # 默认 HTTP 代理起始端口

read -p "请输入 SOCKS5 代理用户名 (默认 userb): " SOCKS_USERNAME
SOCKS_USERNAME=${SOCKS_USERNAME:-userb}

read -p "请输入 SOCKS5 代理密码 (默认 passwordb): " SOCKS_PASSWORD
SOCKS_PASSWORD=${SOCKS_PASSWORD:-passwordb}

read -p "请输入 HTTP 代理用户名 (默认 userb): " HTTP_USERNAME
HTTP_USERNAME=${HTTP_USERNAME:-userb}

read -p "请输入 HTTP 代理密码 (默认 passwordb): " HTTP_PASSWORD
HTTP_PASSWORD=${HTTP_PASSWORD:-passwordb}

IP_ADDRESSES=($(hostname -I)) # 获取所有 IP 地址

install_xray() {
    echo "🔧 安装 Xray..."
    apt-get update -y
    apt-get install unzip -y || yum install unzip -y
    wget -qO /tmp/Xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    unzip -o /tmp/Xray.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/xray
    rm -f /tmp/Xray.zip
    mkdir -p /etc/xray
    cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray Proxy Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xray.service
    echo "✅ Xray 安装完成."
}

generate_config() {
    echo "🛠 生成 Xray 配置..."
    cat <<EOF > /etc/xray/config.json
{
  "inbounds": [
EOF

    PORT_SOCKS5=$DEFAULT_START_PORT_SOCKS5
    PORT_HTTP=$DEFAULT_START_PORT_HTTP
    OUTBOUND_CONFIG=""
    ROUTING_CONFIG=""

    for ip in "${IP_ADDRESSES[@]}"; do
        tag="out_${PORT_SOCKS5}"

        cat <<EOF >> /etc/xray/config.json
    {
      "listen": "$ip",
      "port": $PORT_SOCKS5,
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "$SOCKS_USERNAME",
            "pass": "$SOCKS_PASSWORD"
          }
        ],
        "udp": true
      },
      "tag": "$tag"
    },
    {
      "listen": "$ip",
      "port": $PORT_HTTP,
      "protocol": "http",
      "settings": {
        "accounts": [
          {
            "user": "$HTTP_USERNAME",
            "pass": "$HTTP_PASSWORD"
          }
        ],
        "allowTransparent": false
      },
      "tag": "$tag"
    },
EOF

        OUTBOUND_CONFIG+=$(cat <<EOF
    {
      "protocol": "freedom",
      "settings": {
        "sendThrough": "$ip"
      },
      "tag": "$tag"
    },
EOF
        )

        ROUTING_CONFIG+=$(cat <<EOF
    {
      "type": "field",
      "inboundTag": ["$tag"],
      "outboundTag": "$tag"
    },
EOF
        )

        ((PORT_SOCKS5++))
        ((PORT_HTTP++))
    done

    # 删除最后的逗号
    sed -i '$ s/,$//' /etc/xray/config.json

    cat <<EOF >> /etc/xray/config.json
  ],
  "outbounds": [
$OUTBOUND_CONFIG
  ],
  "routing": {
    "rules": [
$ROUTING_CONFIG
    ]
  }
}
EOF
    echo "✅ Xray 配置文件已生成."
}

restart_xray() {
    systemctl restart xray.service
    systemctl enable xray.service
    systemctl status xray.service --no-pager
    echo "✅ Xray 代理已启动."
}

display_proxy_info() {
    echo "✅ 代理配置完成!"
    for ip in "${IP_ADDRESSES[@]}"; do
        echo "🔹 SOCKS5 代理: socks5://$SOCKS_USERNAME:$SOCKS_PASSWORD@$ip:$DEFAULT_START_PORT_SOCKS5"
        echo "🔹 HTTP  代理: http://$HTTP_USERNAME:$HTTP_PASSWORD@$ip:$DEFAULT_START_PORT_HTTP"
        ((DEFAULT_START_PORT_SOCKS5++))
        ((DEFAULT_START_PORT_HTTP++))
    done
}

main() {
    [ -x "$(command -v xray)" ] || install_xray
    generate_config
    restart_xray
    display_proxy_info
}

main
