#!/bin/bash
# 简单的定时请求脚本
# 每两分钟请求一次指定URL，默认请求谷歌

# 默认参数
URL="${1:-https://www.google.com}"
INTERVAL=120  # 2分钟 = 120秒
LOG_FILE="request_log_$(date +%Y%m%d).txt"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - $1" | tee -a "$LOG_FILE"
}

# 信号处理函数
cleanup() {
    log "${YELLOW}接收到退出信号，正在停止服务...${NC}"
    exit 0
}

# 注册信号处理
trap cleanup SIGINT SIGTERM

# 发起请求的函数
make_request() {
    local start_time=$(date +%s.%N)
    
    # 使用curl发起请求
    if response=$(curl -s -w "%{http_code}:%{time_total}" -o /dev/null \
                      -H "User-Agent: Mozilla/5.0 (Linux; request-script)" \
                      --connect-timeout 30 \
                      --max-time 60 \
                      "$URL" 2>/dev/null); then
        
        local http_code=$(echo "$response" | cut -d':' -f1)
        local time_total=$(echo "$response" | cut -d':' -f2)
        
        if [ "$http_code" = "200" ]; then
            log "${GREEN}✓ 请求成功${NC} | URL: $URL | 状态码: $http_code | 响应时间: ${time_total}s"
        else
            log "${YELLOW}⚠ 请求异常${NC} | URL: $URL | 状态码: $http_code | 响应时间: ${time_total}s"
        fi
    else
        log "${RED}✗ 请求失败${NC} | URL: $URL | 错误: 网络连接失败"
    fi
}

# 主函数
main() {
    log "${GREEN}开始定时请求服务${NC}"
    log "目标URL: $URL"
    log "请求间隔: ${INTERVAL}秒"
    log "日志文件: $LOG_FILE"
    log "按 Ctrl+C 停止服务"
    echo ""
    
    local count=0
    
    while true; do
        count=$((count + 1))
        log "--- 第 $count 次请求 ---"
        
        make_request
        
        log "等待 ${INTERVAL} 秒后进行下次请求..."
        sleep "$INTERVAL"
    done
}

# 检查参数
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "用法: $0 [URL]"
    echo ""
    echo "参数:"
    echo "  URL    要请求的网址 (默认: https://www.google.com)"
    echo ""
    echo "示例:"
    echo "  $0                           # 请求谷歌"
    echo ""
    echo "后台运行:"
    echo "  nohup $0 > /dev/null 2>&1 &"
    echo "  # 或者"
    echo "  $0 &"
    exit 0
fi

# 启动主程序
main# 完整模式配置
elif [ "$MODE_CHOICE" = "2" ]; then
    echo -e "${BLUE}=== 完整配置模式 ===${NC}"
    echo
    
    # UUID配置
    echo -e "${YELLOW}当前UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)${NC}"
    read -p "请输入新的 UUID (留空自动生成): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID_INPUT=$(generate_uuid)
        echo -e "${GREEN}自动生成UUID: $UUID_INPUT${NC}"
    fi
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"

    # 节点名称配置
    echo -e "${YELLOW}当前节点名称: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)${NC}"
    read -p "请输入节点名称 (留空保持不变): " NAME_INPUT
    if [ -n "$NAME_INPUT" ]; then
        sed -i "s/NAME = os.environ.get('NAME', '[^']*')/NAME = os.environ.get('NAME', '$NAME_INPUT')/" app.py
        echo -e "${GREEN}节点名称已设置为: $NAME_INPUT${NC}"
    fi

    # 服务端口配置
    echo -e "${YELLOW}当前服务端口: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)${NC}"
    read -p "请输入服务端口 (留空保持不变): " PORT_INPUT
    if [ -n "$PORT_INPUT" ]; then
        sed -i "s/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or [0-9]*)/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or $PORT_INPUT)/" app.py
        echo -e "${GREEN}端口已设置为: $PORT_INPUT${NC}"
    fi

    # 优选IP配置
    echo -e "${YELLOW}当前优选IP: $(grep "CFIP = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入优选IP/域名 (留空使用默认 joeyblog.net): " CFIP_INPUT
    if [ -z "$CFIP_INPUT" ]; then
        CFIP_INPUT="joeyblog.net"
    fi
    sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', '$CFIP_INPUT')/" app.py
    echo -e "${GREEN}优选IP已设置为: $CFIP_INPUT${NC}"

    # 优选端口配置
    echo -e "${YELLOW}当前优选端口: $(grep "CFPORT = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入优选端口 (留空保持不变): " CFPORT_INPUT
    if [ -n "$CFPORT_INPUT" ]; then
        sed -i "s/CFPORT = int(os.environ.get('CFPORT', '[^']*'))/CFPORT = int(os.environ.get('CFPORT', '$CFPORT_INPUT'))/" app.py
        echo -e "${GREEN}优选端口已设置为: $CFPORT_INPUT${NC}"
    fi

    # Argo端口配置
    echo -e "${YELLOW}当前Argo端口: $(grep "ARGO_PORT = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入 Argo 端口 (留空保持不变): " ARGO_PORT_INPUT
    if [ -n "$ARGO_PORT_INPUT" ]; then
        sed -i "s/ARGO_PORT = int(os.environ.get('ARGO_PORT', '[^']*'))/ARGO_PORT = int(os.environ.get('ARGO_PORT', '$ARGO_PORT_INPUT'))/" app.py
        echo -e "${GREEN}Argo端口已设置为: $ARGO_PORT_INPUT${NC}"
    fi

    # 订阅路径配置
    echo -e "${YELLOW}当前订阅路径: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入订阅路径 (留空保持不变): " SUB_PATH_INPUT
    if [ -n "$SUB_PATH_INPUT" ]; then
        sed -i "s/SUB_PATH = os.environ.get('SUB_PATH', '[^']*')/SUB_PATH = os.environ.get('SUB_PATH', '$SUB_PATH_INPUT')/" app.py
        echo -e "${GREEN}订阅路径已设置为: $SUB_PATH_INPUT${NC}"
    fi

    # 保活配置
    echo
    configure_keepalive

    # 高级选项
    echo
    echo -e "${YELLOW}是否配置高级选项? (y/n)${NC}"
    read -p "> " ADVANCED_CONFIG

    if [ "$ADVANCED_CONFIG" = "y" ] || [ "$ADVANCED_CONFIG" = "Y" ]; then
        # 哪吒监控配置
        echo -e "${YELLOW}当前哪吒服务器: $(grep "NEZHA_SERVER = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入哪吒服务器地址 (留空保持不变): " NEZHA_SERVER_INPUT
        if [ -n "$NEZHA_SERVER_INPUT" ]; then
            sed -i "s|NEZHA_SERVER = os.environ.get('NEZHA_SERVER', '[^']*')|NEZHA_SERVER = os.environ.get('NEZHA_SERVER', '$NEZHA_SERVER_INPUT')|" app.py
            
            echo -e "${YELLOW}当前哪吒端口: $(grep "NEZHA_PORT = " app.py | cut -d"'" -f4)${NC}"
            read -p "请输入哪吒端口 (v1版本留空): " NEZHA_PORT_INPUT
            if [ -n "$NEZHA_PORT_INPUT" ]; then
                sed -i "s|NEZHA_PORT = os.environ.get('NEZHA_PORT', '[^']*')|NEZHA_PORT = os.environ.get('NEZHA_PORT', '$NEZHA_PORT_INPUT')|" app.py
            fi
            
            echo -e "${YELLOW}当前哪吒密钥: $(grep "NEZHA_KEY = " app.py | cut -d"'" -f4)${NC}"
            read -p "请输入哪吒密钥: " NEZHA_KEY_INPUT
            if [ -n "$NEZHA_KEY_INPUT" ]; then
                sed -i "s|NEZHA_KEY = os.environ.get('NEZHA_KEY', '[^']*')|NEZHA_KEY = os.environ.get('NEZHA_KEY', '$NEZHA_KEY_INPUT')|" app.py
            fi
            echo -e "${GREEN}哪吒配置已设置${NC}"
        fi

        # Argo固定隧道配置
        echo -e "${YELLOW}当前Argo域名: $(grep "ARGO_DOMAIN = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入 Argo 固定隧道域名 (留空保持不变): " ARGO_DOMAIN_INPUT
        if [ -n "$ARGO_DOMAIN_INPUT" ]; then
            sed -i "s|ARGO_DOMAIN = os.environ.get('ARGO_DOMAIN', '[^']*')|ARGO_DOMAIN = os.environ.get('ARGO_DOMAIN', '$ARGO_DOMAIN_INPUT')|" app.py
            
            echo -e "${YELLOW}当前Argo密钥: $(grep "ARGO_AUTH = " app.py | cut -d"'" -f4)${NC}"
            read -p "请输入 Argo 固定隧道密钥: " ARGO_AUTH_INPUT
            if [ -n "$ARGO_AUTH_INPUT" ]; then
                sed -i "s|ARGO_AUTH = os.environ.get('ARGO_AUTH', '[^']*')|ARGO_AUTH = os.environ.get('ARGO_AUTH', '$ARGO_AUTH_INPUT')|" app.py
            fi
            echo -e "${GREEN}Argo固定隧道配置已设置${NC}"
        fi

        # Telegram配置
        echo -e "${YELLOW}当前Bot Token: $(grep "BOT_TOKEN = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入 Telegram Bot Token (留空保持不变): " BOT_TOKEN_INPUT
        if [ -n "$BOT_TOKEN_INPUT" ]; then
            sed -i "s|BOT_TOKEN = os.environ.get('BOT_TOKEN', '[^']*')|BOT_TOKEN = os.environ.get('BOT_TOKEN', '$BOT_TOKEN_INPUT')|" app.py
            
            echo -e "${YELLOW}当前Chat ID: $(grep "CHAT_ID = " app.py | cut -d"'" -f4)${NC}"
            read -p "请输入 Telegram Chat ID: " CHAT_ID_INPUT
            if [ -n "$CHAT_ID_INPUT" ]; then
                sed -i "s|CHAT_ID = os.environ.get('CHAT_ID', '[^']*')|CHAT_ID = os.environ.get('CHAT_ID', '$CHAT_ID_INPUT')|" app.py
            fi
            echo -e "${GREEN}Telegram配置已设置${NC}"
        fi
    fi
    
    echo
    echo -e "${GREEN}完整配置完成！${NC}"
fi

# ==============================================
# 配置摘要显示
# ==============================================

echo
echo -e "${YELLOW}=== 当前配置摘要 ===${NC}"
echo -e "UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)"
echo -e "节点名称: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)"
echo -e "服务端口: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)"
echo -e "优选IP: $(grep "CFIP = " app.py | cut -d"'" -f4)"
echo -e "优选端口: $(grep "CFPORT = " app.py | cut -d"'" -f4)"
echo -e "订阅路径: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)"

# 显示保活配置
case "${KEEPALIVE_MODE:-auto}" in
    "manual")
        echo -e "保活模式: ${BLUE}手动配置${NC}"
        echo -e "保活URL: ${YELLOW}${KEEPALIVE_URL}${NC}"
        ;;
    "auto")
        echo -e "保活模式: ${GREEN}自动提取${NC}"
        echo -e "保活说明: ${BLUE}从节点信息自动提取host${NC}"
        ;;
    "disabled")
        echo -e "保活模式: ${RED}已禁用${NC}"
        ;;
esac

echo -e "${YELLOW}========================${NC}"
echo

# ==============================================
# Python文件修改和优化
# ==============================================

echo -e "${BLUE}正在优化Python配置...${NC}"
echo -e "${YELLOW}当前工作目录：$(pwd)${NC}"

# 创建YouTube分流和80端口节点补丁
cat > youtube_patch.py << 'EOF'
# 读取app.py文件
with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 替换xray配置，添加YouTube分流
old_config = 'config ={"log":{"access":"/dev/null","error":"/dev/null","loglevel":"none",},"inbounds":[{"port":ARGO_PORT ,"protocol":"vless","settings":{"clients":[{"id":UUID ,"flow":"xtls-rprx-vision",},],"decryption":"none","fallbacks":[{"dest":3001 },{"path":"/vless-argo","dest":3002 },{"path":"/vmess-argo","dest":3003 },{"path":"/trojan-argo","dest":3004 },],},"streamSettings":{"network":"tcp",},},{"port":3001 ,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID },],"decryption":"none"},"streamSettings":{"network":"ws","security":"none"}},{"port":3002 ,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID ,"level":0 }],"decryption":"none"},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/vless-argo"}},"sniffing":{"enabled":True ,"destOverride":["http","tls","quic"],"metadataOnly":False }},{"port":3003 ,"listen":"127.0.0.1","protocol":"vmess","settings":{"clients":[{"id":UUID ,"alterId":0 }]},"streamSettings":{"network":"ws","wsSettings":{"path":"/vmess-argo"}},"sniffing":{"enabled":True ,"destOverride":["http","tls","quic"],"metadataOnly":False }},{"port":3004 ,"listen":"127.0.0.1","protocol":"trojan","settings":{"clients":[{"password":UUID },]},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/trojan-argo"}},"sniffing":{"enabled":True ,"destOverride":["http","tls","quic"],"metadataOnly":False }},],"outbounds":[{"protocol":"freedom","tag": "direct" },{"protocol":"blackhole","tag":"block"}]}'

new_config = '''config = {
        "log": {
            "access": "/dev/null",
            "error": "/dev/null",
            "loglevel": "none"
        },
        "inbounds": [
            {
                "port": ARGO_PORT,
                "protocol": "vless",
                "settings": {
                    "clients": [{"id": UUID, "flow": "xtls-rprx-vision"}],
                    "decryption": "none",
                    "fallbacks": [
                        {"dest": 3001},
                        {"path": "/vless-argo", "dest": 3002},
                        {"path": "/vmess-argo", "dest": 3003},
                        {"path": "/trojan-argo", "dest": 3004}
                    ]
                },
                "streamSettings": {"network": "tcp"}
            },
            {
                "port": 3001,
                "listen": "127.0.0.1",
                "protocol": "vless",
                "settings": {
                    "clients": [{"id": UUID}],
                    "decryption": "none"
                },
                "streamSettings": {"network": "ws", "security": "none"}
            },
            {
                "port": 3002,
                "listen": "127.0.0.1",
                "protocol": "vless",
                "settings": {
                    "clients": [{"id": UUID, "level": 0}],
                    "decryption": "none"
                },
                "streamSettings": {
                    "network": "ws",
                    "security": "none",
                    "wsSettings": {"path": "/vless-argo"}
                },
                "sniffing": {
                    "enabled": True,
                    "destOverride": ["http", "tls", "quic"],
                    "metadataOnly": False
                }
            },
            {
                "port": 3003,
                "listen": "127.0.0.1",
                "protocol": "vmess",
                "settings": {
                    "clients": [{"id": UUID, "alterId": 0}]
                },
                "streamSettings": {
                    "network": "ws",
                    "wsSettings": {"path": "/vmess-argo"}
                },
                "sniffing": {
                    "enabled": True,
                    "destOverride": ["http", "tls", "quic"],
                    "metadataOnly": False
                }
            },
            {
                "port": 3004,
                "listen": "127.0.0.1",
                "protocol": "trojan",
                "settings": {
                    "clients": [{"password": UUID}]
                },
                "streamSettings": {
                    "network": "ws",
                    "security": "none",
                    "wsSettings": {"path": "/trojan-argo"}
                },
                "sniffing": {
                    "enabled": True,
                    "destOverride": ["http", "tls", "quic"],
                    "metadataOnly": False
                }
            }
        ],
        "outbounds": [
            {"protocol": "freedom", "tag": "direct"},
            {
                "protocol": "vmess",
                "tag": "youtube",
                "settings": {
                    "vnext": [{
                        "address": "172.233.171.224",
                        "port": 16416,
                        "users": [{
                            "id": "8c1b9bea-cb51-43bb-a65c-0af31bbbf145",
                            "alterId": 0
                        }]
                    }]
                },
                "streamSettings": {"network": "tcp"}
            },
            {"protocol": "blackhole", "tag": "block"}
        ],
        "routing": {
            "domainStrategy": "IPIfNonMatch",
            "rules": [
                {
                    "type": "field",
                    "domain": [
                        "youtube.com",
                        "googlevideo.com",
                        "ytimg.com",
                        "gstatic.com",
                        "googleapis.com",
                        "ggpht.com",
                        "googleusercontent.com"
                    ],
                    "outboundTag": "youtube"
                }
            ]
        }
    }'''

# 替换配置
content = content.replace(old_config, new_config)

# 修改generate_links函数，添加80端口节点
old_generate_function = '''# Generate links and subscription content
async def generate_links(argo_domain):
    meta_info = subprocess.run(['curl', '-s', 'https://speed.cloudflare.com/meta'], capture_output=True, text=True)
    meta_info = meta_info.stdout.split('"')
    ISP = f"{meta_info[25]}-{meta_info[17]}".replace(' ', '_').strip()

    time.sleep(2)
    VMESS = {"v": "2", "ps": f"{NAME}-{ISP}", "add": CFIP, "port": CFPORT, "id": UUID, "aid": "0", "scy": "none", "net": "ws", "type": "none", "host": argo_domain, "path": "/vmess-argo?ed=2560", "tls": "tls", "sni": argo_domain, "alpn": "", "fp": "chrome"}
 
    list_txt = f"""
vless://{UUID}@{CFIP}:{CFPORT}?encryption=none&security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Fvless-argo%3Fed%3D2560#{NAME}-{ISP}
  
vmess://{ base64.b64encode(json.dumps(VMESS).encode('utf-8')).decode('utf-8')}

trojan://{UUID}@{CFIP}:{CFPORT}?security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Ftrojan-argo%3Fed%3D2560#{NAME}-{ISP}
    """
    
    with open(os.path.join(FILE_PATH, 'list.txt'), 'w', encoding='utf-8') as list_file:
        list_file.write(list_txt)

    sub_txt = base64.b64encode(list_txt.encode('utf-8')).decode('utf-8')
    with open(os.path.join(FILE_PATH, 'sub.txt'), 'w', encoding='utf-8') as sub_file:
        sub_file.write(sub_txt)
        
    print(sub_txt)
    
    print(f"{FILE_PATH}/sub.txt saved successfully")
    
    # Additional actions
    send_telegram()
    upload_nodes()
  
    return sub_txt'''

new_generate_function = '''# Generate links and subscription content
async def generate_links(argo_domain):
    meta_info = subprocess.run(['curl', '-s', 'https://speed.cloudflare.com/meta'], capture_output=True, text=True)
    meta_info = meta_info.stdout.split('"')
    ISP = f"{meta_info[25]}-{meta_info[17]}".replace(' ', '_').strip()

    time.sleep(2)
    
    # TLS节点 (443端口)
    VMESS_TLS = {"v": "2", "ps": f"{NAME}-{ISP}-TLS", "add": CFIP, "port": CFPORT, "id": UUID, "aid": "0", "scy": "none", "net": "ws", "type": "none", "host": argo_domain, "path": "/vmess-argo?ed=2560", "tls": "tls", "sni": argo_domain, "alpn": "", "fp": "chrome"}
    
    # 无TLS节点 (80端口)
    VMESS_80 = {"v": "2", "ps": f"{NAME}-{ISP}-80", "add": CFIP, "port": "80", "id": UUID, "aid": "0", "scy": "none", "net": "ws", "type": "none", "host": argo_domain, "path": "/vmess-argo?ed=2560", "tls": "", "sni": "", "alpn": "", "fp": ""}
 
    list_txt = f"""
vless://{UUID}@{CFIP}:{CFPORT}?encryption=none&security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Fvless-argo%3Fed%3D2560#{NAME}-{ISP}-TLS
  
vmess://{ base64.b64encode(json.dumps(VMESS_TLS).encode('utf-8')).decode('utf-8')}

trojan://{UUID}@{CFIP}:{CFPORT}?security=tls&sni={argo_domain}&fp=chrome&type=ws&host={argo_domain}&path=%2Ftrojan-argo%3Fed%3D2560#{NAME}-{ISP}-TLS

vless://{UUID}@{CFIP}:80?encryption=none&security=none&type=ws&host={argo_domain}&path=%2Fvless-argo%3Fed%3D2560#{NAME}-{ISP}-80

vmess://{ base64.b64encode(json.dumps(VMESS_80).encode('utf-8')).decode('utf-8')}

trojan://{UUID}@{CFIP}:80?security=none&type=ws&host={argo_domain}&path=%2Ftrojan-argo%3Fed%3D2560#{NAME}-{ISP}-80
    """
    
    with open(os.path.join(FILE_PATH, 'list.txt'), 'w', encoding='utf-8') as list_file:
        list_file.write(list_txt)

    sub_txt = base64.b64encode(list_txt.encode('utf-8')).decode('utf-8')
    with open(os.path.join(FILE_PATH, 'sub.txt'), 'w', encoding='utf-8') as sub_file:
        sub_file.write(sub_txt)
        
    print(sub_txt)
    
    print(f"{FILE_PATH}/sub.txt saved successfully")
    
    # Additional actions
    send_telegram()
    upload_nodes()
  
    return sub_txt'''

# 替换generate_links函数
content = content.replace(old_generate_function, new_generate_function)

# 写回文件
with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("YouTube分流配置和80端口节点已成功添加")
EOF

# 执行补丁
python3 youtube_patch.py
rm youtube_patch.py

echo -e "${GREEN}✓ YouTube分流和80端口节点已集成${NC}"

# ==============================================
# 服务启动
# ==============================================

echo -e "${BLUE}正在启动Xray服务...${NC}"

# 清理现有进程
pkill -f "python3 app.py" > /dev/null 2>&1
sleep 2

# 启动服务
python3 app.py > app.log 2>&1 &
APP_PID=$!

# 验证启动
if [ -z "$APP_PID" ] || [ "$APP_PID" -eq 0 ]; then
    echo -e "${YELLOW}PID获取失败，尝试其他方式启动${NC}"
    nohup python3 app.py > app.log 2>&1 &
    sleep 2
    APP_PID=$(pgrep -f "python3 app.py" | head -1)
fi

if [ -z "$APP_PID" ]; then
    echo -e "${RED}服务启动失败${NC}"
    echo -e "${YELLOW}查看日志: tail -f app.log${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Xray服务已启动，PID: $APP_PID${NC}"
echo -e "${YELLOW}日志文件: $(pwd)/app.log${NC}"

# 等待服务稳定
echo -e "${BLUE}等待服务启动完成...${NC}"
sleep 8

# 检查服务状态
if ! ps -p "$APP_PID" > /dev/null 2>&1; then
    echo -e "${RED}服务启动失败，请检查日志${NC}"
    echo -e "${YELLOW}查看日志: tail -f app.log${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 服务运行正常${NC}"

# ==============================================
# 节点信息生成
# ==============================================

# 获取配置信息
SERVICE_PORT=$(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)
CURRENT_UUID=$(grep "UUID = " app.py | head -1 | cut -d"'" -f2)
SUB_PATH_VALUE=$(grep "SUB_PATH = " app.py | cut -d"'" -f4)

echo -e "${BLUE}等待节点信息生成...${NC}"
echo -e "${YELLOW}正在等待Argo隧道建立，请耐心等待...${NC}"

# 等待节点信息生成
MAX_WAIT=600  # 10分钟
WAIT_COUNT=0
NODE_INFO=""

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -f ".cache/sub.txt" ]; then
        NODE_INFO=$(cat .cache/sub.txt 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}✓ 节点信息已生成！${NC}"
            break
        fi
    elif [ -f "sub.txt" ]; then
        NODE_INFO=$(cat sub.txt 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}✓ 节点信息已生成！${NC}"
            break
        fi
    fi
    
    # 进度提示
    if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
        local minutes=$((WAIT_COUNT / 60))
        local seconds=$((WAIT_COUNT % 60))
        echo -e "${YELLOW}已等待 ${minutes}分${seconds}秒，继续等待...${NC}"
    fi
    
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 5))
done

# 检查生成结果
if [ -z "$NODE_INFO" ]; then
    echo -e "${RED}节点信息生成超时${NC}"
    echo -e "${YELLOW}可能原因：网络问题或Argo隧道建立失败${NC}"
    echo -e "${BLUE}服务信息：${NC}"
    echo -e "进程PID: ${BLUE}$APP_PID${NC}"
    echo -e "服务端口: ${BLUE}$SERVICE_PORT${NC}"
    echo -e "日志文件: ${YELLOW}$(pwd)/app.log${NC}"
    echo
    echo -e "${YELLOW}建议操作：${NC}"
    echo -e "1. 查看日志: tail -f $(pwd)/app.log"
    echo -e "2. 等待更长时间后重新运行脚本查看节点信息"
    echo -e "3. 检查网络连接和防火墙设置"
    exit 1
fi

# ==============================================
# 部署完成展示
# ==============================================

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}           部署完成！                   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# 服务信息
echo -e "${YELLOW}=== 服务信息 ===${NC}"
echo -e "服务状态: ${GREEN}运行中${NC}"
echo -e "进程PID: ${BLUE}$APP_PID${NC}"
echo -e "服务端口: ${BLUE}$SERVICE_PORT${NC}"
echo -e "UUID: ${BLUE}$CURRENT_UUID${NC}"
echo -e "订阅路径: ${BLUE}/$SUB_PATH_VALUE${NC}"
echo

# 访问地址
echo -e "${YELLOW}=== 访问地址 ===${NC}"
if command -v curl &> /dev/null; then
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "获取失败")
    if [ "$PUBLIC_IP" != "获取失败" ]; then
        echo -e "订阅地址: ${GREEN}http://$PUBLIC_IP:$SERVICE_PORT/$SUB_PATH_VALUE${NC}"
        echo -e "管理面板: ${GREEN}http://$PUBLIC_IP:$SERVICE_PORT${NC}"
    fi
fi
echo -e "本地订阅: ${GREEN}http://localhost:$SERVICE_PORT/$SUB_PATH_VALUE${NC}"
echo -e "本地面板: ${GREEN}http://localhost:$SERVICE_PORT${NC}"
echo

# 节点信息
echo -e "${YELLOW}=== 节点信息 ===${NC}"
DECODED_NODES=$(echo "$NODE_INFO" | base64 -d 2>/dev/null || echo "$NODE_INFO")

echo -e "${GREEN}节点配置:${NC}"
echo "$DECODED_NODES"
echo

echo -e "${GREEN}订阅链接:${NC}"
echo "$NODE_INFO"
echo

# ==============================================
# 保存节点信息
# ==============================================

SAVE_INFO="========================================
           节点信息保存               
========================================

部署时间: $(date)
UUID: $CURRENT_UUID
服务端口: $SERVICE_PORT
订阅路径: /$SUB_PATH_VALUE

=== 访问地址 ==="

if command -v curl &> /dev/null; then
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "获取失败")
    if [ "$PUBLIC_IP" != "获取失败" ]; then
        SAVE_INFO="${SAVE_INFO}
订阅地址: http://$PUBLIC_IP:$SERVICE_PORT/$SUB_PATH_VALUE
管理面板: http://$PUBLIC_IP:$SERVICE_PORT"
    fi
fi

SAVE_INFO="${SAVE_INFO}
本地订阅: http://localhost:$SERVICE_PORT/$SUB_PATH_VALUE
本地面板: http://localhost:$SERVICE_PORT

=== 节点信息 ===
$DECODED_NODES

=== 订阅链接 ===
$NODE_INFO

=== 管理命令 ===
查看日志: tail -f $(pwd)/app.log
停止服务: kill $APP_PID
重启服务: kill $APP_PID && nohup python3 app.py > app.log 2>&1 &
查看进程: ps aux | grep python3
查看节点: bash $0 -v
保活状态: 重新运行脚本选择选项4
实时日志: 重新运行脚本选择选项5

=== 快捷命令 ===
bash $0 -v     # 查看节点信息
bash $0 -h     # 显示帮助信息

=== 功能特性 ===
- YouTube分流优化已集成
- 支持TLS(443)和非TLS(80)双端口
- 智能保活功能已配置
- 完整的监控和日志系统"

echo "$SAVE_INFO" > "$NODE_INFO_FILE"
echo -e "${GREEN}✓ 节点信息已保存到 $NODE_INFO_FILE${NC}"

# ==============================================
# 启动保活服务
# ==============================================

echo -e "${BLUE}正在启动保活服务...${NC}"

if [ "${KEEPALIVE_MODE:-auto}" = "disabled" ]; then
    echo -e "${YELLOW}⚠️  保活功能已禁用${NC}"
else
    # 创建保活脚本
    create_keepalive_script
    
    # 启动保活服务
    if [ "${KEEPALIVE_MODE:-auto}" = "manual" ] && [ -n "${KEEPALIVE_URL:-}" ]; then
        start_keepalive_service "manual" "$KEEPALIVE_URL"
    else
        start_keepalive_service "auto"
    fi
    
    # 检查启动状态
    sleep 2
    local keepalive_pid=$(pgrep -f "xray_keepalive.sh" | head -1)
    if [ -n "$keepalive_pid" ]; then
        echo -e "${GREEN}✓ 保活服务运行正常${NC}"
        echo -e "${BLUE}保活间隔: 每2分钟执行${NC}"
    else
        echo -e "${YELLOW}⚠️  保活服务可能未启动成功${NC}"
    fi
fi

# ==============================================
# 完成提示
# ==============================================

echo
echo -e "${GREEN}🎉 所有服务已启动完成！${NC}"
echo

echo -e "${YELLOW}=== 重要提示 ===${NC}"
echo -e "${GREEN}✓ 部署已完成，可立即使用订阅地址${NC}"
echo -e "${GREEN}✓ YouTube分流已自动配置，无需额外设置${NC}"
echo -e "${GREEN}✓ 保活功能已启动，自动维持连接${NC}"
echo -e "${GREEN}✓ 支持TLS和非TLS双端口访问${NC}"
echo

echo -e "${YELLOW}=== 管理功能 ===${NC}"
echo -e "${BLUE}查看节点信息: ${YELLOW}bash $0 -v${NC}"
echo -e "${BLUE}监控保活状态: ${YELLOW}重新运行脚本选择选项4${NC}"
echo -e "${BLUE}查看实时日志: ${YELLOW}重新运行脚本选择选项5${NC}"
echo -e "${BLUE}显示帮助信息: ${YELLOW}bash $0 -h${NC}"
echo

echo -e "${YELLOW}=== 保活功能说明 ===${NC}"
case "${KEEPALIVE_MODE:-auto}" in
    "manual")
        echo -e "${GREEN}✓ 手动保活模式已启用${NC}"
        echo -e "${BLUE}目标URL: ${YELLOW}${KEEPALIVE_URL}${NC}"
        echo -e "${BLUE}每2分钟自动请求指定URL保持连接${NC}"
        ;;
    "auto")
        echo -e "${GREEN}✓ 自动保活模式已启用${NC}"
        echo -e "${BLUE}自动从节点信息提取隧道域名${NC}"
        echo -e "${BLUE}每2分钟自动curl请求保持隧道活跃${NC}"
        echo -e "${BLUE}支持HTTP/HTTPS双协议自适应${NC}"
        ;;
    "disabled")
        echo -e "${YELLOW}⚠️  保活功能已禁用${NC}"
        echo -e "${BLUE}如需启用，请重新运行脚本重新配置${NC}"
        ;;
esac

echo
echo -e "${GREEN}感谢使用！祝您使用愉快！${NC}"

# 脚本结束
exit 0#!/bin/bash

# ==============================================
#  Python Xray Argo 一键部署脚本 (增强版)
#  支持智能保活、YouTube分流、双端口节点
# ==============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局变量
NODE_INFO_FILE="$HOME/.xray_nodes_info"
KEEPALIVE_LOG_FILE="$HOME/.xray_keepalive.log"
KEEPALIVE_CONFIG_FILE="$HOME/.xray_keepalive_config"

# ==============================================
# 参数处理函数
# ==============================================

# 查看节点信息
show_node_info() {
    if [ -f "$NODE_INFO_FILE" ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}           节点信息查看               ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo
        cat "$NODE_INFO_FILE"
        echo
    else
        echo -e "${RED}未找到节点信息文件${NC}"
        echo -e "${YELLOW}请先运行部署脚本生成节点信息${NC}"
    fi
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}       Python Xray Argo 部署脚本      ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}使用方法:${NC}"
    echo -e "  bash $(basename $0) [选项]"
    echo
    echo -e "${BLUE}选项说明:${NC}"
    echo -e "  无参数     - 进入交互式部署菜单"
    echo -e "  -v         - 查看节点信息"
    echo -e "  -h, --help - 显示此帮助信息"
    echo
    echo -e "${BLUE}保活功能:${NC}"
    echo -e "  自动每2分钟curl请求节点host"
    echo -e "  自动从节点信息中提取host地址"
    echo -e "  支持HTTP和HTTPS两种协议"
    echo -e "  支持手动配置保活URL"
    echo -e "  部署完成后自动启动"
    echo
    echo -e "${BLUE}示例:${NC}"
    echo -e "  bash $(basename $0) -v    # 查看节点信息"
    echo
}

# ==============================================
# 工具函数
# ==============================================

# UUID生成函数
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    else
        hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/' | tr '[:upper:]' '[:lower:]'
    fi
}

# 从节点信息中提取隧道域名
extract_tunnel_domain() {
    local domain=""
    
    if [ -f "$NODE_INFO_FILE" ]; then
        # 方法1: 从节点配置中提取host参数
        domain=$(grep -o "host=[^&]*" "$NODE_INFO_FILE" | head -1 | cut -d"=" -f2)
        if [ -n "$domain" ]; then
            echo "$domain"
            return 0
        fi
    fi
    
    return 1
}

# ==============================================
# 保活相关函数
# ==============================================

# 创建保活脚本
create_keepalive_script() {
    cat > "$HOME/xray_keepalive.sh" << 'EOF'
#!/bin/bash

# 日志文件
LOG_FILE="$HOME/.xray_keepalive.log"

# 保活配置默认值
KEEPALIVE_MODE="auto"
MANUAL_URL=""

# 读取配置文件
if [ -f "$HOME/.xray_keepalive_config" ]; then
    source "$HOME/.xray_keepalive_config"
fi

# 日志函数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# 获取目标URL
get_target_url() {
    # 手动模式：直接返回配置的URL
    if [ "$KEEPALIVE_MODE" = "manual" ] && [ -n "$MANUAL_URL" ]; then
        echo "$MANUAL_URL"
        return 0
    fi
    
    # 自动模式：从节点信息提取
    if [ -f "$HOME/.xray_nodes_info" ]; then
        # 从host参数提取域名
        local host=$(grep -o 'host=[^&]*' "$HOME/.xray_nodes_info" | head -1 | cut -d'=' -f2)
        if [ -n "$host" ]; then
            echo "https://$host"
            return 0
        fi
        
        # 从订阅地址提取
        local sub_link=$(grep "订阅地址:" "$HOME/.xray_nodes_info" | head -1 | cut -d' ' -f2)
        if [ -n "$sub_link" ]; then
            local domain=$(echo "$sub_link" | sed -n 's|http://\([^:]*\):.*|\1|p')
            if [ -n "$domain" ]; then
                echo "https://$domain"
                return 0
            fi
        fi
        
        # 从vless链接提取
        local vless_link=$(grep -o 'vless://[^#]*' "$HOME/.xray_nodes_info" | head -1)
        if [ -n "$vless_link" ]; then
            local host=$(echo "$vless_link" | grep -o 'host=[^&]*' | cut -d'=' -f2)
            if [ -n "$host" ]; then
                echo "https://$host"
                return 0
            fi
        fi
    fi
    
    return 1
}

# 保活函数
keepalive_request() {
    local url="$1"
    
    if [ -z "$url" ]; then
        log_message "保活跳过: 未找到目标URL"
        return 1
    fi
    
    log_message "保活请求: $url"
    
    if command -v curl &> /dev/null; then
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "$url" 2>/dev/null)
        
        if [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || [ "$http_code" = "400" ]; then
            log_message "保活成功: $url (状态码: $http_code)"
            return 0
        elif [ -n "$http_code" ] && [ "$http_code" != "000" ]; then
            log_message "保活响应: $url (状态码: $http_code)"
            return 0
        else
            # HTTPS失败时尝试HTTP（仅自动模式）
            if [[ "$url" == https://* ]] && [ "$KEEPALIVE_MODE" = "auto" ]; then
                local http_url="${url/https:/http:}"
                log_message "HTTPS失败，尝试HTTP: $http_url"
                
                http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "$http_url" 2>/dev/null)
                if [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || [ "$http_code" = "400" ]; then
                    log_message "保活成功: $http_url (状态码: $http_code)"
                    return 0
                fi
            fi
        fi
    fi
    
    log_message "保活失败: $url"
    return 1
}

# 主循环
main() {
    if [ "$KEEPALIVE_MODE" = "manual" ]; then
        log_message "保活服务启动 - 手动模式，目标: $MANUAL_URL"
    else
        log_message "保活服务启动 - 自动模式，每2分钟执行"
    fi
    
    while true; do
        local target_url=$(get_target_url)
        
        if [ -n "$target_url" ]; then
            keepalive_request "$target_url"
        else
            if [ "$KEEPALIVE_MODE" = "manual" ]; then
                log_message "手动模式: URL配置为空"
            else
                log_message "自动模式: 未找到节点域名"
            fi
        fi
        
        sleep 120  # 等待2分钟
    done
}

# 启动主循环
main
EOF
    
    chmod +x "$HOME/xray_keepalive.sh"
}

# 启动保活服务
start_keepalive_service() {
    local mode="${1:-auto}"
    local url="${2:-}"
    
    # 创建配置文件
    cat > "$KEEPALIVE_CONFIG_FILE" << EOF
KEEPALIVE_MODE="$mode"
MANUAL_URL="$url"
EOF
    
    # 停止已存在的进程
    pkill -f "xray_keepalive.sh" > /dev/null 2>&1
    sleep 2
    
    # 启动服务
    nohup "$HOME/xray_keepalive.sh" > /dev/null 2>&1 &
    local pid=$!
    
    sleep 1
    if ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 保活服务已启动，PID: $pid${NC}"
        if [ "$mode" = "manual" ] && [ -n "$url" ]; then
            echo -e "${BLUE}保活模式: 手动配置 - ${YELLOW}$url${NC}"
        else
            echo -e "${BLUE}保活模式: 自动提取host${NC}"
        fi
        return 0
    else
        echo -e "${RED}❌ 保活服务启动失败${NC}"
        return 1
    fi
}

# 显示保活状态
show_keepalive_status() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           保活状态监控               ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    # 检查进程状态
    local pid=$(pgrep -f "xray_keepalive.sh" | head -1)
    if [ -n "$pid" ]; then
        echo -e "${GREEN}✅ 保活服务运行中${NC}"
        echo -e "进程PID: ${BLUE}$pid${NC}"
        
        if command -v ps &> /dev/null; then
            echo -e "${YELLOW}进程详情:${NC}"
            ps -p "$pid" -o pid,ppid,cmd,etime,pcpu,pmem 2>/dev/null || echo "无法获取详情"
        fi
    else
        echo -e "${RED}❌ 保活服务未运行${NC}"
    fi
    
    echo
    
    # 显示配置信息
    if [ -f "$KEEPALIVE_CONFIG_FILE" ]; then
        echo -e "${BLUE}当前配置:${NC}"
        cat "$KEEPALIVE_CONFIG_FILE"
        echo
    fi
    
    # 显示统计信息
    if [ -f "$KEEPALIVE_LOG_FILE" ]; then
        echo -e "${YELLOW}保活统计:${NC}"
        
        local total=$(grep -c "保活请求" "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
        local success=$(grep -c "保活成功" "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
        local failed=$(grep -c "保活失败" "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
        
        echo -e "总请求: ${BLUE}$total${NC}"
        echo -e "成功: ${GREEN}$success${NC}"
        echo -e "失败: ${RED}$failed${NC}"
        
        if [ "$total" -gt 0 ]; then
            local rate=$((success * 100 / total))
            echo -e "成功率: ${GREEN}${rate}%${NC}"
        fi
        
        echo
        echo -e "${YELLOW}最近记录:${NC}"
        tail -n 5 "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "无记录"
    else
        echo -e "${YELLOW}未找到保活日志${NC}"
    fi
    
    # 手动测试选项
    echo
    echo -e "${YELLOW}是否手动测试保活? (y/n)${NC}"
    read -p "> " test_choice
    if [ "$test_choice" = "y" ] || [ "$test_choice" = "Y" ]; then
        manual_test_keepalive
    fi
    
    echo
    read -p "按回车键返回主菜单..."
}

# 手动测试保活
manual_test_keepalive() {
    echo -e "${BLUE}正在手动测试保活...${NC}"
    
    local domain=$(extract_tunnel_domain)
    if [ -n "$domain" ]; then
        echo -e "${GREEN}✓ 检测到域名: ${YELLOW}$domain${NC}"
        local test_url="https://$domain"
    else
        echo -e "${YELLOW}⚠ 未检测到域名，请手动输入${NC}"
        read -p "请输入测试URL: " test_url
    fi
    
    if [ -n "$test_url" ]; then
        echo -e "${BLUE}测试URL: ${YELLOW}$test_url${NC}"
        
        local start_time=$(date +%s)
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "$test_url" 2>/dev/null)
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo -e "${CYAN}测试结果:${NC}"
        echo -e "状态码: ${YELLOW}$http_code${NC}"
        echo -e "耗时: ${YELLOW}${duration}秒${NC}"
        
        if [ "$http_code" = "200" ] || [ "$http_code" = "404" ] || [ "$http_code" = "400" ]; then
            echo -e "${GREEN}✓ 测试成功${NC}"
        else
            echo -e "${RED}✗ 测试失败${NC}"
        fi
        
        # 记录到日志
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 手动测试: $test_url (状态码: $http_code)" >> "$KEEPALIVE_LOG_FILE"
    fi
}

# ==============================================
# 日志查看函数
# ==============================================

show_realtime_logs() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           实时日志监控               ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    echo -e "${YELLOW}选择日志类型:${NC}"
    echo -e "${BLUE}1) 服务运行日志 (app.log)${NC}"
    echo -e "${BLUE}2) 保活功能日志${NC}"
    echo -e "${BLUE}3) 系统日志${NC}"
    echo -e "${BLUE}4) 返回主菜单${NC}"
    echo
    
    read -p "请选择 (1-4): " log_choice
    
    case $log_choice in
        1)
            local work_dir=""
            if [ -d "python-xray-argo" ]; then
                work_dir="python-xray-argo"
            else
                work_dir=$(find $HOME -name "app.py" -path "*/python-xray-argo/*" -exec dirname {} \; 2>/dev/null | head -1)
            fi
            
            if [ -n "$work_dir" ] && [ -f "$work_dir/app.log" ]; then
                echo -e "${GREEN}显示服务日志，按Ctrl+C退出${NC}"
                echo -e "${YELLOW}文件: $work_dir/app.log${NC}"
                echo
                tail -f "$work_dir/app.log"
            else
                echo -e "${RED}未找到服务日志${NC}"
                read -p "按回车返回..."
            fi
            ;;
        2)
            if [ -f "$KEEPALIVE_LOG_FILE" ]; then
                echo -e "${GREEN}显示保活日志，按Ctrl+C退出${NC}"
                echo -e "${YELLOW}文件: $KEEPALIVE_LOG_FILE${NC}"
                echo
                tail -f "$KEEPALIVE_LOG_FILE"
            else
                echo -e "${RED}未找到保活日志${NC}"
                read -p "按回车返回..."
            fi
            ;;
        3)
            if command -v journalctl &> /dev/null; then
                echo -e "${GREEN}显示系统日志，按Ctrl+C退出${NC}"
                echo
                journalctl -f -n 50
            else
                echo -e "${YELLOW}系统不支持journalctl${NC}"
                read -p "按回车返回..."
            fi
            ;;
        *)
            return
            ;;
    esac
}

# ==============================================
# 保活配置函数
# ==============================================

configure_keepalive() {
    echo -e "${YELLOW}=== 保活配置 ===${NC}"
    echo -e "${BLUE}保活方式选择:${NC}"
    echo -e "${BLUE}1) 自动保活 - 从节点信息自动提取host (推荐)${NC}"
    echo -e "${BLUE}2) 手动配置保活URL${NC}"
    echo -e "${BLUE}3) 禁用保活功能${NC}"
    read -p "请选择 (1/2/3): " keepalive_choice
    
    case "$keepalive_choice" in
        "1")
            echo -e "${GREEN}✓ 将使用自动保活${NC}"
            KEEPALIVE_MODE="auto"
            KEEPALIVE_URL=""
            ;;
        "2")
            echo -e "${YELLOW}手动配置保活URL:${NC}"
            echo -e "${BLUE}示例格式:${NC}"
            echo -e "  https://your-domain.trycloudflare.com"
            echo -e "  http://example.com"
            echo -e "  https://api.example.com/health"
            echo
            read -p "请输入保活URL: " manual_url
            
            if [ -n "$manual_url" ]; then
                if [[ "$manual_url" =~ ^https?:// ]]; then
                    echo -e "${GREEN}✓ URL格式验证通过${NC}"
                    KEEPALIVE_MODE="manual"
                    KEEPALIVE_URL="$manual_url"
                    echo -e "${GREEN}✓ 保活URL: ${YELLOW}$manual_url${NC}"
                else
                    echo -e "${YELLOW}⚠ 建议使用 http:// 或 https:// 开头${NC}"
                    KEEPALIVE_MODE="manual"
                    KEEPALIVE_URL="$manual_url"
                fi
            else
                echo -e "${YELLOW}未输入URL，使用自动模式${NC}"
                KEEPALIVE_MODE="auto"
                KEEPALIVE_URL=""
            fi
            ;;
        "3")
            echo -e "${YELLOW}⚠ 保活功能已禁用${NC}"
            KEEPALIVE_MODE="disabled"
            KEEPALIVE_URL=""
            ;;
        *)
            echo -e "${GREEN}使用默认自动保活${NC}"
            KEEPALIVE_MODE="auto"
            KEEPALIVE_URL=""
            ;;
    esac
}

# ==============================================
# 主程序入口
# ==============================================

# 处理命令行参数
case "$1" in
    "-v")
        show_node_info
        exit 0
        ;;
    "-h"|"--help")
        show_help
        exit 0
        ;;
esac

# 主菜单
clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Python Xray Argo 一键部署脚本    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}基于项目: ${YELLOW}https://github.com/eooce/python-xray-argo${NC}"
echo -e "${BLUE}脚本仓库: ${YELLOW}https://github.com/byJoey/free-vps-py${NC}"
echo -e "${BLUE}TG交流群: ${YELLOW}https://t.me/+ft-zI76oovgwNmRh${NC}"
echo
echo -e "${GREEN}本脚本基于 eooce 大佬的 Python Xray Argo 项目开发${NC}"
echo -e "${GREEN}提供极速和完整两种配置模式，简化部署流程${NC}"
echo -e "${GREEN}支持自动UUID生成、后台运行、节点信息输出${NC}"
echo -e "${GREEN}默认集成YouTube分流优化，支持交互式查看节点信息${NC}"
echo -e "${GREEN}新增智能保活功能，自动检测节点状态${NC}"
echo

echo -e "${YELLOW}请选择操作:${NC}"
echo -e "${BLUE}1) 极速模式 - 只修改UUID并启动${NC}"
echo -e "${BLUE}2) 完整模式 - 详细配置所有选项${NC}"
echo -e "${BLUE}3) 查看节点信息 - 显示已保存的节点信息${NC}"
echo -e "${BLUE}4) 查看保活状态 - 监控保活功能和统计${NC}"
echo -e "${BLUE}5) 查看实时日志 - 显示服务运行日志${NC}"
echo
read -p "请输入选择 (1/2/3/4/5): " MODE_CHOICE

# 处理选择
case "$MODE_CHOICE" in
    "3")
        if [ -f "$NODE_INFO_FILE" ]; then
            show_node_info
            echo -e "${YELLOW}提示: 如需重新部署，请选择模式1或2${NC}"
        else
            echo -e "${RED}未找到节点信息文件${NC}"
            echo -e "${YELLOW}请先运行部署脚本生成节点信息${NC}"
            echo
            echo -e "${BLUE}是否现在开始部署? (y/n)${NC}"
            read -p "> " start_deploy
            if [ "$start_deploy" = "y" ] || [ "$start_deploy" = "Y" ]; then
                echo -e "${YELLOW}请选择部署模式:${NC}"
                echo -e "${BLUE}1) 极速模式${NC}"
                echo -e "${BLUE}2) 完整模式${NC}"
                read -p "请选择 (1/2): " MODE_CHOICE
                if [ "$MODE_CHOICE" != "1" ] && [ "$MODE_CHOICE" != "2" ]; then
                    echo -e "${GREEN}退出脚本${NC}"
                    exit 0
                fi
            else
                echo -e "${GREEN}退出脚本${NC}"
                exit 0
            fi
        fi
        ;;
    "4")
        show_keepalive_status
        exit 0
        ;;
    "5")
        show_realtime_logs
        exit 0
        ;;
    "1"|"2")
        # 继续部署流程
        ;;
    *)
        echo -e "${RED}无效选择${NC}"
        exit 1
        ;;
esac

# ==============================================
# 依赖检查和安装
# ==============================================

echo -e "${BLUE}检查并安装依赖...${NC}"

# 安装Python3
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python3...${NC}"
    sudo apt-get update && sudo apt-get install -y python3 python3-pip
fi

# 安装Python依赖
if ! python3 -c "import requests" &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python 依赖...${NC}"
    pip3 install requests
fi

# 下载项目
PROJECT_DIR="python-xray-argo"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${BLUE}下载项目仓库...${NC}"
    if command -v git &> /dev/null; then
        git clone https://github.com/eooce/python-xray-argo.git
    else
        echo -e "${YELLOW}Git未安装，使用wget下载...${NC}"
        wget -q https://github.com/eooce/python-xray-argo/archive/refs/heads/main.zip -O python-xray-argo.zip
        
        if command -v unzip &> /dev/null; then
            unzip -q python-xray-argo.zip
            mv python-xray-argo-main python-xray-argo
            rm python-xray-argo.zip
        else
            echo -e "${YELLOW}正在安装 unzip...${NC}"
            sudo apt-get install -y unzip
            unzip -q python-xray-argo.zip
            mv python-xray-argo-main python-xray-argo
            rm python-xray-argo.zip
        fi
    fi
    
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}下载失败，请检查网络连接${NC}"
        exit 1
    fi
fi

cd "$PROJECT_DIR"

if [ ! -f "app.py" ]; then
    echo -e "${RED}未找到app.py文件！${NC}"
    exit 1
fi

# 备份原始文件
cp app.py
