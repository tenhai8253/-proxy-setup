DEFAULT_SOCKS_START_PORT=20000                         # 默认 SOCKS5 起始端口
DEFAULT_HTTP_START_PORT=30000                         # 默认 HTTP 起始端口
DEFAULT_SOCKS_USERNAME="userb"                        # 默认 SOCKS5 账号
DEFAULT_SOCKS_PASSWORD="passwordb"                   # 默认 SOCKS5 密码
DEFAULT_HTTP_USERNAME="userh"                        # 默认 HTTP 账号
DEFAULT_HTTP_PASSWORD="passwordh"                   # 默认 HTTP 密码

IP_ADDRESSES=($(hostname -I))

install_xray() {
    echo "安装 Xray..."
    apt-get install unzip -y || yum install unzip -y
    wget https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip
    unzip Xray-linux-64.zip
    mv xray /usr/local/bin/xrayL
    chmod +x /usr/local/bin/xrayL
    cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.toml
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xrayL.service
    systemctl start xrayL.service
    echo "Xray 安装完成."
}

config_xray() {
    mkdir -p /etc/xrayL
    config_content=""

    for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
        # SOCKS5 代理配置
        config_content+="[[inbounds]]\n"
        config_content+="port = $((DEFAULT_SOCKS_START_PORT + i))\n"
        config_content+="protocol = \"socks\"\n"
        config_content+="tag = \"socks_$((i + 1))\"\n"
        config_content+="[inbounds.settings]\n"
        config_content+="auth = \"password\"\n"
        config_content+="udp = true\n"
        config_content+="ip = \"${IP_ADDRESSES[i]}\"\n"
        config_content+="[[inbounds.settings.accounts]]\n"
        config_content+="user = \"$DEFAULT_SOCKS_USERNAME\"\n"
        config_content+="pass = \"$DEFAULT_SOCKS_PASSWORD\"\n\n"

        # HTTP 代理配置
        config_content+="[[inbounds]]\n"
        config_content+="port = $((DEFAULT_HTTP_START_PORT + i))\n"
        config_content+="protocol = \"http\"\n"
        config_content+="tag = \"http_$((i + 1))\"\n"
        config_content+="[inbounds.settings]\n"
        config_content+="auth = \"password\"\n"
        config_content+="ip = \"${IP_ADDRESSES[i]}\"\n"
        config_content+="[[inbounds.settings.accounts]]\n"
        config_content+="user = \"$DEFAULT_HTTP_USERNAME\"\n"
        config_content+="pass = \"$DEFAULT_HTTP_PASSWORD\"\n\n"

        # 出站规则
        config_content+="[[outbounds]]\n"
        config_content+="sendThrough = \"${IP_ADDRESSES[i]}\"\n"
        config_content+="protocol = \"freedom\"\n"
        config_content+="tag = \"out_$((i + 1))\"\n\n"
    done
    echo -e "$config_content" >/etc/xrayL/config.toml
    systemctl restart xrayL.service
    systemctl --no-pager status xrayL.service
    echo "\n生成 SOCKS5 和 HTTP 配置完成\n"
    echo "SOCKS5 起始端口: $DEFAULT_SOCKS_START_PORT"
    echo "HTTP 起始端口: $DEFAULT_HTTP_START_PORT"
    echo "SOCKS5 账号: $DEFAULT_SOCKS_USERNAME"
    echo "SOCKS5 密码: $DEFAULT_SOCKS_PASSWORD"
    echo "HTTP 账号: $DEFAULT_HTTP_USERNAME"
    echo "HTTP 密码: $DEFAULT_HTTP_PASSWORD"
}

main() {
    [ -x "$(command -v xrayL)" ] || install_xray
    config_xray
}

main
