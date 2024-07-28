#!/bin/bash

# 检测 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，正在安装 Docker..."

    # 更新系统并安装 Docker
    sudo apt-get update || { echo "更新软件包列表失败"; exit 1; }
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release || { echo "安装依赖失败"; exit 1; }
    
    # 添加 Docker 的官方 GPG 密钥
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add - || { echo "添加 Docker GPG 密钥失败"; exit 1; }
    
    # 设置 Docker 仓库
    echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo "添加 Docker 源失败"; exit 1; }
    
    # 更新软件包列表并安装 Docker
    sudo apt-get update || { echo "更新软件包列表失败"; exit 1; }
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io || { echo "安装 Docker 失败"; exit 1; }

    # 启动 Docker 服务
    sudo systemctl start docker || { echo "启动 Docker 服务失败"; exit 1; }
    sudo systemctl enable docker || { echo "设置 Docker 服务开机启动失败"; exit 1; }

    echo "Docker 安装完成。"
else
    echo "Docker 已安装。"
fi

# 启用 BBR
echo "启用 BBR..."

# 修改 sysctl 配置文件以启用 BBR
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

# 重新加载 sysctl 配置
sudo sysctl -p || { echo "重新加载 sysctl 配置失败"; exit 1; }

echo "BBR 已启用。"

# 提示用户输入 NodeID
read -p "Enter NodeID: " NODE_ID

# 确保用户输入了 NodeID
if [ -z "$NODE_ID" ]; then
  echo "Error: NodeID cannot be empty."
  exit 1
fi

# 设置文件路径
FILE_PATH="./config.yml" # 修改为目标路径

# 创建配置文件的目录（如果不存在）
mkdir -p "$(dirname "$FILE_PATH")"

# 配置内容，其中 NodeID 使用用户输入的值
CONFIG_CONTENT=$(cat <<EOF
Log:
  Level: none # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnectionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 10 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB 
Nodes:
  -
    PanelType: "V2board" # Panel type: SSpanel, NewV2board, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "https://www.cockatielcloud.com"
      ApiKey: "laggard-fig-reagent-chidden"
      NodeID: ${NODE_ID} # NodeID from user input
      NodeType: V2ray # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/XrayR/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      DisableSniffing: false # Disable domain sniffing 
      EnableProxyProtocol: false
      AutoSpeedLimitConfig:
        Limit: 0 # Warned speed. Set to 0 to disable AutoSpeedLimit (mbps)
        WarnTimes: 0 # After (WarnTimes) consecutive warnings, the user will be limited. Set to 0 to punish overspeed user immediately.
        LimitSpeed: 0 # The speedlimit of a limited user (unit: mbps)
        LimitDuration: 0 # How many minutes will the limiting last (unit: minute)
      GlobalDeviceLimitConfig:
        Enable: false # Enable the global device limit of a user
        RedisAddr: 127.0.0.1:6379 # The redis server address
        RedisPassword: YOUR PASSWORD # Redis password
        RedisDB: 0 # Redis DB
        Timeout: 5 # Timeout for redis request
        Expiry: 60 # Expiry time (second)
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Alpn: # Alpn, Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: dns # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        RejectUnknownSni: false # Reject unknown SNI
        CertDomain: "node1.test.com" # Domain to cert
        CertFile: /etc/XrayR/cert/node1.test.com.cert # Provided if the CertMode is file
        KeyFile: /etc/XrayR/cert/node1.test.com.key
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
EOF
)

# 将配置内容写入配置文件
echo "$CONFIG_CONTENT" > "$FILE_PATH" || { echo "写入配置文件失败"; exit 1; }

echo "配置文件已创建：$FILE_PATH"

# 拉取 Docker 镜像并运行容器
docker pull ghcr.io/xrayr-project/xrayr:latest || { echo "拉取 Docker 镜像失败"; exit 1; }

docker run --restart=always --name xrayr -d \
    -v "$FILE_PATH:/etc/XrayR/config.yml" \
    --network=host \
    ghcr.io/xrayr-project/xrayr:latest || { echo "启动 Docker 容器失败"; exit 1; }

echo "XrayR 容器已启动。"

