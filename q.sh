#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v node &> /dev/null; then
        node -e "console.log(require('crypto').randomUUID())"
    else
        hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/' | tr '[:upper:]' '[:lower:]'
    fi
}

clear

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Nodejs Argo 一键部署脚本          ${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}基于项目: ${YELLOW}https://github.com/eooce/nodejs-argo${NC}"
echo -e "${BLUE}脚本仓库: ${YELLOW}https://github.com/byJoey/free-vps-py${NC}"
echo -e "${BLUE}TG交流群: ${YELLOW}https://t.me/+ft-zI76oovgwNmRh${NC}"
echo
echo -e "${GREEN}本脚本基于 eooce 大佬的 nodejs-argo 项目开发${NC}"
echo -e "${GREEN}使用 Node.js 环境，支持多种代理协议和哪吒监控${NC}"
echo -e "${GREEN}支持临时和固定 Argo 隧道，配置简单快速${NC}"
echo

echo -e "${YELLOW}请选择配置模式:${NC}"
echo -e "${BLUE}1) 极速模式 - 最少配置快速启动${NC}"
echo -e "${BLUE}2) 完整模式 - 详细配置所有选项${NC}"
echo
read -p "请输入选择 (1/2): " MODE_CHOICE

echo -e "${BLUE}检查并安装依赖...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}正在安装 Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

if ! command -v npm &> /dev/null; then
    echo -e "${YELLOW}正在安装 npm...${NC}"
    sudo apt-get install -y npm
fi

PROJECT_DIR="nodejs-argo"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${BLUE}下载完整仓库...${NC}"
    if command -v git &> /dev/null; then
        git clone https://github.com/eooce/nodejs-argo.git
    else
        echo -e "${YELLOW}Git未安装，使用wget下载...${NC}"
        wget -q https://github.com/eooce/nodejs-argo/archive/refs/heads/main.zip -O nodejs-argo.zip
        if command -v unzip &> /dev/null; then
            unzip -q nodejs-argo.zip
            mv nodejs-argo-main nodejs-argo
            rm nodejs-argo.zip
        else
            echo -e "${YELLOW}正在安装 unzip...${NC}"
            sudo apt-get install -y unzip
            unzip -q nodejs-argo.zip
            mv nodejs-argo-main nodejs-argo
            rm nodejs-argo.zip
        fi
    fi
    
    if [ $? -ne 0 ] || [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}下载失败，请检查网络连接${NC}"
        exit 1
    fi
fi

cd "$PROJECT_DIR"

echo -e "${BLUE}安装项目依赖...${NC}"
npm install

echo -e "${GREEN}依赖安装完成！${NC}"
echo

if [ ! -f "index.js" ]; then
    echo -e "${RED}未找到index.js文件！${NC}"
    exit 1
fi

cp index.js index.js.backup 2>/dev/null || true
echo -e "${YELLOW}已备份原始文件${NC}"

UUID=""
PORT="3000"
ARGO_PORT="8001"
CFIP="joeyblog.net"
CFPORT="443"
NAME="Vls"
SUB_PATH="sub"
FILE_PATH="./tmp"
PROJECT_URL=""
UPLOAD_URL=""
AUTO_ACCESS="false"
NEZHA_SERVER=""
NEZHA_PORT=""
NEZHA_KEY=""
ARGO_DOMAIN=""
ARGO_AUTH=""

if [ "$MODE_CHOICE" = "1" ]; then
    echo -e "${BLUE}=== 极速模式 ===${NC}"
    echo
    
    read -p "请输入 UUID (留空自动生成): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID=$(generate_uuid)
        echo -e "${GREEN}自动生成UUID: $UUID${NC}"
    else
        UUID="$UUID_INPUT"
    fi
    
    read -p "请输入节点名称 (留空使用默认 Vls): " NAME_INPUT
    if [ -n "$NAME_INPUT" ]; then
        NAME="$NAME_INPUT"
    fi
    
    read -p "请输入服务端口 (留空使用默认 3000): " PORT_INPUT
    if [ -n "$PORT_INPUT" ]; then
        PORT="$PORT_INPUT"
    fi
    
    CFIP="joeyblog.net"
    echo -e "${GREEN}优选IP已自动设置为: joeyblog.net${NC}"
    
    echo
    echo -e "${GREEN}极速配置完成！${NC}"
    
else
    echo -e "${BLUE}=== 完整配置模式 ===${NC}"
    echo
    
    read -p "请输入 UUID (留空自动生成): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID=$(generate_uuid)
        echo -e "${GREEN}自动生成UUID: $UUID${NC}"
    else
        UUID="$UUID_INPUT"
    fi
    
    read -p "请输入节点名称 (默认: Vls): " NAME_INPUT
    if [ -n "$NAME_INPUT" ]; then
        NAME="$NAME_INPUT"
    fi
    
    read -p "请输入HTTP服务端口 (默认: 3000): " PORT_INPUT
    if [ -n "$PORT_INPUT" ]; then
        PORT="$PORT_INPUT"
    fi
    
    read -p "请输入Argo隧道端口 (默认: 8001): " ARGO_PORT_INPUT
    if [ -n "$ARGO_PORT_INPUT" ]; then
        ARGO_PORT="$ARGO_PORT_INPUT"
    fi
    
    read -p "请输入优选IP/域名 (默认: joeyblog.net): " CFIP_INPUT
    if [ -n "$CFIP_INPUT" ]; then
        CFIP="$CFIP_INPUT"
    fi
    
    read -p "请输入优选端口 (默认: 443): " CFPORT_INPUT
    if [ -n "$CFPORT_INPUT" ]; then
        CFPORT="$CFPORT_INPUT"
    fi
    
    read -p "请输入订阅路径 (默认: sub): " SUB_PATH_INPUT
    if [ -n "$SUB_PATH_INPUT" ]; then
        SUB_PATH="$SUB_PATH_INPUT"
    fi
    
    echo
    echo -e "${YELLOW}是否配置高级选项? (y/n)${NC}"
    read -p "> " ADVANCED_CONFIG
    
    if [ "$ADVANCED_CONFIG" = "y" ] || [ "$ADVANCED_CONFIG" = "Y" ]; then
        read -p "请输入项目URL (可选): " PROJECT_URL
        read -p "请输入上传URL (可选): " UPLOAD_URL
        
        echo -e "${YELLOW}是否启用自动保活? (y/n)${NC}"
        read -p "> " AUTO_ACCESS_INPUT
        if [ "$AUTO_ACCESS_INPUT" = "y" ] || [ "$AUTO_ACCESS_INPUT" = "Y" ]; then
            AUTO_ACCESS="true"
        fi
        
        read -p "请输入哪吒服务器地址 (可选, 格式: domain:port): " NEZHA_SERVER
        if [ -n "$NEZHA_SERVER" ]; then
            read -p "请输入哪吒端口 (v1版本留空): " NEZHA_PORT
            read -p "请输入哪吒密钥: " NEZHA_KEY
        fi
        
        read -p "请输入Argo固定隧道域名 (可选): " ARGO_DOMAIN
        if [ -n "$ARGO_DOMAIN" ]; then
            read -p "请输入Argo固定隧道密钥: " ARGO_AUTH
        fi
    fi
    
    echo
    echo -e "${GREEN}完整配置完成！${NC}"
fi

echo -e "${YELLOW}=== 当前配置摘要 ===${NC}"
echo -e "UUID: $UUID"
echo -e "节点名称: $NAME"
echo -e "服务端口: $PORT"
echo -e "Argo端口: $ARGO_PORT"
echo -e "优选IP: $CFIP"
echo -e "优选端口: $CFPORT"
echo -e "订阅路径: $SUB_PATH"
[ -n "$PROJECT_URL" ] && echo -e "项目URL: $PROJECT_URL"
[ -n "$NEZHA_SERVER" ] && echo -e "哪吒服务器: $NEZHA_SERVER"
[ -n "$ARGO_DOMAIN" ] && echo -e "Argo域名: $ARGO_DOMAIN"
echo -e "${YELLOW}========================${NC}"
echo

echo -e "${BLUE}正在启动 nodejs-argo 服务...${NC}"

export PORT="$PORT"
export ARGO_PORT="$ARGO_PORT"
export UUID="$UUID"
export CFIP="$CFIP"
export CFPORT="$CFPORT"
export NAME="$NAME"
export SUB_PATH="$SUB_PATH"
export FILE_PATH="$FILE_PATH"

[ -n "$PROJECT_URL" ] && export PROJECT_URL="$PROJECT_URL"
[ -n "$UPLOAD_URL" ] && export UPLOAD_URL="$UPLOAD_URL"
[ "$AUTO_ACCESS" = "true" ] && export AUTO_ACCESS="true"
[ -n "$NEZHA_SERVER" ] && export NEZHA_SERVER="$NEZHA_SERVER"
[ -n "$NEZHA_PORT" ] && export NEZHA_PORT="$NEZHA_PORT"
[ -n "$NEZHA_KEY" ] && export NEZHA_KEY="$NEZHA_KEY"
[ -n "$ARGO_DOMAIN" ] && export ARGO_DOMAIN="$ARGO_DOMAIN"
[ -n "$ARGO_AUTH" ] && export ARGO_AUTH="$ARGO_AUTH"

LOG_FILE="nodejs-argo.log"
nohup node index.js > $LOG_FILE 2>&1 &
APP_PID=$!

echo -e "${GREEN}服务已在后台启动，PID: $APP_PID${NC}"
echo -e "${YELLOW}日志文件: $(pwd)/$LOG_FILE${NC}"

echo -e "${BLUE}等待服务启动...${NC}"
sleep 10

if ps -p $APP_PID > /dev/null; then
    echo -e "${GREEN}服务运行正常${NC}"
else
    echo -e "${RED}服务启动失败，请检查日志${NC}"
    echo -e "${YELLOW}查看日志: tail -f $LOG_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}等待节点信息生成...${NC}"
sleep 15

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}           部署完成！                   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo

echo -e "${YELLOW}=== 服务信息 ===${NC}"
echo -e "服务状态: ${GREEN}运行中${NC}"
echo -e "进程PID: ${BLUE}$APP_PID${NC}"
echo -e "服务端口: ${BLUE}$PORT${NC}"
echo -e "Argo端口: ${BLUE}$ARGO_PORT${NC}"
echo -e "UUID: ${BLUE}$UUID${NC}"
echo -e "订阅路径: ${BLUE}/$SUB_PATH${NC}"
echo

echo -e "${YELLOW}=== 访问地址 ===${NC}"
if command -v curl &> /dev/null; then
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "获取失败")
    if [ "$PUBLIC_IP" != "获取失败" ]; then
        echo -e "订阅地址: ${GREEN}http://$PUBLIC_IP:$PORT/$SUB_PATH${NC}"
        echo -e "管理面板: ${GREEN}http://$PUBLIC_IP:$PORT${NC}"
    fi
fi
echo -e "本地订阅: ${GREEN}http://localhost:$PORT/$SUB_PATH${NC}"
echo -e "本地面板: ${GREEN}http://localhost:$PORT${NC}"
echo

if [ -n "$ARGO_DOMAIN" ]; then
    echo -e "${YELLOW}=== Argo固定隧道 ===${NC}"
    echo -e "固定域名订阅: ${GREEN}https://$ARGO_DOMAIN/$SUB_PATH${NC}"
    echo -e "固定域名面板: ${GREEN}https://$ARGO_DOMAIN${NC}"
    echo
else
    echo -e "${YELLOW}=== Argo临时隧道 ===${NC}"
    echo -e "${BLUE}临时隧道域名将在日志中显示，请等待几分钟后查看${NC}"
    echo -e "${BLUE}可以使用命令查看: grep -i 'trycloudflare.com' $LOG_FILE${NC}"
    echo
fi

echo -e "${YELLOW}=== 节点配置信息 ===${NC}"
echo -e "支持协议: ${GREEN}VLESS, VMess, Trojan${NC}"
echo -e "传输协议: ${GREEN}WebSocket${NC}"
echo -e "安全传输: ${GREEN}TLS${NC}"
echo -e "优选地址: ${GREEN}$CFIP:$CFPORT${NC}"
echo -e "节点前缀: ${GREEN}$NAME${NC}"
echo

NODE_INFO=""
if [ -f "$FILE_PATH/sub.txt" ]; then
    NODE_INFO=$(cat "$FILE_PATH/sub.txt")
elif [ -f "sub.txt" ]; then
    NODE_INFO=$(cat sub.txt)
fi

if [ -n "$NODE_INFO" ]; then
    echo -e "${YELLOW}=== 订阅内容预览 ===${NC}"
    DECODED_NODES=$(echo "$NODE_INFO" | base64 -d 2>/dev/null || echo "$NODE_INFO")
    echo -e "${GREEN}节点配置:${NC}"
    echo "$DECODED_NODES" | head -3
    echo
    echo -e "${GREEN}完整订阅链接:${NC}"
    echo "$NODE_INFO"
    echo
else
    echo -e "${YELLOW}=== 订阅信息 ===${NC}"
    echo -e "${BLUE}节点信息正在生成中，请稍等几分钟后访问订阅地址${NC}"
    echo
fi

echo -e "${YELLOW}=== 管理命令 ===${NC}"
echo -e "查看日志: ${BLUE}tail -f $(pwd)/$LOG_FILE${NC}"
echo -e "查看Argo隧道: ${BLUE}grep -i 'trycloudflare.com' $(pwd)/$LOG_FILE${NC}"
echo -e "停止服务: ${BLUE}kill $APP_PID${NC}"
echo -e "重启服务: ${BLUE}kill $APP_PID && nohup node index.js > $LOG_FILE 2>&1 &${NC}"
echo -e "查看进程: ${BLUE}ps aux | grep 'node.*index.js'${NC}"
echo

echo -e "${YELLOW}=== 重要提示 ===${NC}"
echo -e "${GREEN}1. 服务正在后台运行，Argo隧道需要几分钟建立${NC}"
echo -e "${GREEN}2. 临时隧道域名会显示在日志中，请耐心等待${NC}"
echo -e "${GREEN}3. 建议10-15分钟后查看订阅地址获取最新节点${NC}"
echo -e "${GREEN}4. 如需使用固定隧道，请配置ARGO_DOMAIN和ARGO_AUTH${NC}"
echo -e "${GREEN}5. 哪吒监控支持v0和v1版本，会自动检测TLS${NC}"
echo

echo -e "${GREEN}部署完成！感谢使用！${NC}"
