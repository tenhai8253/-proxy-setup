#!/bin/bash

read -p "请输入 SOCKS5 代理起始端口（默认 20000）: " START_PORT_SOCKS5
START_PORT_SOCKS5=${START_PORT_SOCKS5:-20000}

read -p "请输入 HTTP 代理起始端口（默认 30000）: " START_PORT_HTTP
START_PORT_HTTP=${START_PORT_HTTP:-30000}

read -p "请输入 SOCKS5 账号: " SOCKS_USERNAME
read -s -p "请输入 SOCKS5 密码: " SOCKS_PASSWORD
echo ""
read -p "请输入 HTTP 账号: " HTTP_USERNAME
read -s -p "请输入 HTTP 密码: " HTTP_PASSWORD
echo ""

read -p "请输入绑定的 IP 地址（用空格分隔）: " -a IP_ADDRESSES

install_xray() {
    echo "🚀 安装 Xray..."
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

    PORT_SOCKS5=$START_PORT_SOCKS5
    PORT_HTTP=$START_PORT_HTTP
    INDEX=0

    for ip in "${IP_ADDRESSES[@]}"; do
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
      }
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
      }
    },
EOF
        ((PORT_SOCKS5++))
        ((PORT_HTTP++))
        ((INDEX++))
    done

    # 删除最后一个逗号
    sed -i '$ s/,$//' /etc/xray/config.json

    cat <<EOF >> /etc/xray/config.json
  ],
  "outbounds": [
EOF

    for ip in "${IP_ADDRESSES[@]}"; do
        cat <<EOF >> /etc/xray/config.json
    {
      "protocol": "freedom",
      "settings": {},
      "sendThrough": "$ip"
    },
EOF
    done

    # 删除最后一个逗号
    sed -i '$ s/,$//' /etc/xray/config.json

    cat <<EOF >> /etc/xray/config.json
  ]
}
EOF
    echo "✅ Xray 配置文件已生成."
}

setup_routing() {
    echo "⚙️ 配置路由规则..."
    for ip in "${IP_ADDRESSES[@]}"; do
        ip rule add from "$ip" table 100
        ip route add default via "$ip" dev eth0 table 100
    done
    echo "✅ 路由规则已应用."
}

restart_xray() {
    systemctl restart xray.service
    systemctl status xray.service --no-pager
    echo "✅ Xray 代理已启动."
}

enable_autostart() {
    echo "🔄 代理开机自启..."
    systemctl enable xray
    systemctl restart xray
    systemctl status xray --no-pager
    echo "✅ 代理已设置为开机自启."
}

display_proxy_info() {
    echo "✅ 代理配置完成!"
    INDEX=0
    for ip in "${IP_ADDRESSES[@]}"; do
        echo "🔹 SOCKS5 代理: socks5://$SOCKS_USERNAME:$SOCKS_PASSWORD@$ip:$START_PORT_SOCKS5"
        echo "🔹 HTTP  代理: http://$HTTP_USERNAME:$HTTP_PASSWORD@$ip:$START_PORT_HTTP"
        ((START_PORT_SOCKS5++))
        ((START_PORT_HTTP++))
        ((INDEX++))
    done
}

main() {
    [ -x "$(command -v xray)" ] || install_xray
    generate_config
    setup_routing
    restart_xray
    enable_autostart
    display_proxy_info
}

main
