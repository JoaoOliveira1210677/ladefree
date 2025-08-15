#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NODE_INFO_FILE="$HOME/.xray_nodes_info"
KEEPALIVE_CONFIG_FILE="$HOME/.xray_keepalive_config"

# 如果是-v参数，直接查看节点信息
if [ "$1" = "-v" ]; then
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
    exit 0
fi

# 如果是-k参数，管理保活配置
if [ "$1" = "-k" ]; then
    manage_keepalive
    exit 0
fi

# 如果是-h参数，显示帮助信息
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
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
echo -e "  部署完成后自动启动"
echo
echo -e "${BLUE}示例:${NC}"
echo -e "  bash $(basename $0) -v    # 查看节点信息"
    echo
    exit 0
fi

# 显示保活状态函数
show_keepalive_status() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           保活状态监控               ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    # 检查保活进程
    KEEPALIVE_PID=$(pgrep -f "xray_keepalive.sh" | head -1)
    if [ -n "$KEEPALIVE_PID" ]; then
        echo -e "${GREEN}✅ 保活服务运行中${NC}"
        echo -e "进程PID: ${BLUE}$KEEPALIVE_PID${NC}"
        
        # 显示进程信息
        if command -v ps &> /dev/null; then
            echo -e "${YELLOW}进程详情:${NC}"
            ps -p "$KEEPALIVE_PID" -o pid,ppid,cmd,etime,pcpu,pmem 2>/dev/null || echo "无法获取进程详情"
        fi
    else
        echo -e "${RED}❌ 保活服务未运行${NC}"
    fi
    
    echo
    
    # 显示配置文件信息
    if [ -f "$KEEPALIVE_CONFIG_FILE" ]; then
        echo -e "${BLUE}当前保活配置:${NC}"
        cat "$KEEPALIVE_CONFIG_FILE"
        echo
    else
        echo -e "${YELLOW}未找到保活配置文件${NC}"
        echo -e "${BLUE}保活功能将自动使用节点host进行curl请求${NC}"
    fi
    
    # 显示统计信息
    if [ -f "$HOME/.xray_keepalive.log" ]; then
        echo -e "${YELLOW}保活统计信息:${NC}"
        
        # 使用更安全的统计方法
        TOTAL_REQUESTS=$(grep -c "保活请求" "$HOME/.xray_keepalive.log" 2>/dev/null)
        HTTP_REQUESTS=$(grep -c "状态码:" "$HOME/.xray_keepalive.log" 2>/dev/null)
        FAILED_REQUESTS=$(grep -c "连接失败" "$HOME/.xray_keepalive.log" 2>/dev/null)
        
        # 确保变量有值
        TOTAL_REQUESTS=${TOTAL_REQUESTS:-0}
        HTTP_REQUESTS=${HTTP_REQUESTS:-0}
        FAILED_REQUESTS=${FAILED_REQUESTS:-0}
        
        echo -e "总请求次数: ${BLUE}$TOTAL_REQUESTS${NC}"
        echo -e "有效响应次数: ${GREEN}$HTTP_REQUESTS${NC}"
        echo -e "连接失败次数: ${RED}$FAILED_REQUESTS${NC}"
        
        # 显示状态码分布
        echo -e "${YELLOW}状态码分布:${NC}"
        grep "状态码:" "$HOME/.xray_keepalive.log" | grep -o "状态码: [0-9]*" | sort | uniq -c | sort -nr | head -5 | while read count status; do
            echo -e "  $status: ${BLUE}$count${NC}次"
        done
        
        echo
        echo -e "${YELLOW}最近5次保活记录:${NC}"
        if [ -s "$HOME/.xray_keepalive.log" ]; then
            tail -n 5 "$HOME/.xray_keepalive.log" 2>/dev/null || echo "无记录"
        else
            echo "日志文件为空"
        fi
    else
        echo -e "${YELLOW}未找到保活日志文件${NC}"
    fi
    
    echo
    echo -e "${BLUE}保活功能说明:${NC}"
    echo -e "• 自动每2分钟向节点host或自定义URL发送curl请求"
    echo -e "• 支持HTTP和HTTPS两种协议"
    echo -e "• 显示HTTP状态码而不是成功/失败"
    echo -e "• 优先使用自定义URL，否则自动检测节点host"
    echo -e "• 无需手动配置，部署后自动启动"
    
    echo
    read -p "按回车键返回主菜单..."
}

# 显示实时日志函数
show_realtime_logs() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           实时日志监控               ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    echo -e "${YELLOW}选择要查看的日志:${NC}"
    echo -e "${BLUE}1) 服务运行日志 (app.log)${NC}"
    echo -e "${BLUE}2) 保活功能日志${NC}"
    echo -e "${BLUE}3) 系统日志 (如果支持)${NC}"
    echo -e "${BLUE}4) 返回主菜单${NC}"
    echo
    
    read -p "请输入选择 (1-4): " LOG_CHOICE
    
    case $LOG_CHOICE in
        1)
            if [ -f "app.log" ]; then
                echo -e "${GREEN}正在显示服务运行日志，按Ctrl+C退出...${NC}"
                echo -e "${YELLOW}日志文件: $(pwd)/app.log${NC}"
                echo
                tail -f app.log
            else
                echo -e "${RED}未找到服务日志文件${NC}"
                read -p "按回车键返回..."
            fi
            ;;
        2)
            if [ -f "$HOME/.xray_keepalive.log" ]; then
                echo -e "${GREEN}正在显示保活功能日志，按Ctrl+C退出...${NC}"
                echo -e "${YELLOW}日志文件: $HOME/.xray_keepalive.log${NC}"
                echo
                tail -f "$HOME/.xray_keepalive.log"
            else
                echo -e "${RED}未找到保活日志文件${NC}"
                read -p "按回车键返回..."
            fi
            ;;
        3)
            if command -v journalctl &> /dev/null; then
                echo -e "${GREEN}正在显示系统日志，按Ctrl+C退出...${NC}"
                echo -e "${YELLOW}显示最近的系统日志${NC}"
                echo
                journalctl -f -n 50
            else
                echo -e "${YELLOW}系统不支持journalctl${NC}"
                read -p "按回车键返回..."
            fi
            ;;
        4)
            return
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            show_realtime_logs
            ;;
    esac
}

# 配置保活
configure_keepalive() {
    echo -e "${BLUE}=== 配置自动保活 ===${NC}"
    echo
    
    # 检查是否有节点信息
    if [ ! -f "$NODE_INFO_FILE" ]; then
        echo -e "${RED}未找到节点信息文件，请先部署服务${NC}"
        return
    fi
    
    # 从节点信息中提取host
    NODE_HOST=""
    if [ -f "$NODE_INFO_FILE" ]; then
        # 尝试从订阅链接中提取域名
        SUB_LINK=$(grep "订阅地址:" "$NODE_INFO_FILE" | head -1 | cut -d' ' -f2)
        if [ -n "$SUB_LINK" ]; then
            NODE_HOST=$(echo "$SUB_LINK" | sed -n 's|http://\([^:]*\):.*|\1|p')
        fi
        
        # 如果没找到，尝试从节点配置中提取
        if [ -z "$NODE_HOST" ]; then
            NODE_HOST=$(grep -o 'host=[^&]*' "$NODE_INFO_FILE" | head -1 | cut -d'=' -f2)
        fi
    fi
    
    echo -e "${YELLOW}检测到的节点Host: ${BLUE}${NODE_HOST:-未检测到}${NC}"
    echo
    
    read -p "请输入保活目标Host (留空使用检测到的): " KEEPALIVE_HOST
    if [ -z "$KEEPALIVE_HOST" ]; then
        KEEPALIVE_HOST="$NODE_HOST"
    fi
    
    if [ -z "$KEEPALIVE_HOST" ]; then
        echo -e "${RED}无法确定保活目标，请手动输入${NC}"
        read -p "请输入保活目标Host: " KEEPALIVE_HOST
        if [ -z "$KEEPALIVE_HOST" ]; then
            echo -e "${RED}保活目标不能为空${NC}"
            return
        fi
    fi
    
    read -p "请输入保活间隔(分钟，默认30): " KEEPALIVE_INTERVAL
    if [ -z "$KEEPALIVE_INTERVAL" ]; then
        KEEPALIVE_INTERVAL=30
    fi
    
    read -p "请输入保活超时时间(秒，默认10): " KEEPALIVE_TIMEOUT
    if [ -z "$KEEPALIVE_TIMEOUT" ]; then
        KEEPALIVE_TIMEOUT=10
    fi
    
    read -p "是否启用日志记录? (y/n，默认y): " ENABLE_LOGGING
    if [ -z "$ENABLE_LOGGING" ] || [ "$ENABLE_LOGGING" = "y" ] || [ "$ENABLE_LOGGING" = "Y" ]; then
        ENABLE_LOGGING="true"
    else
        ENABLE_LOGGING="false"
    fi
    
    # 保存配置
    cat > "$KEEPALIVE_CONFIG_FILE" << EOF
# Xray节点保活配置
KEEPALIVE_HOST="$KEEPALIVE_HOST"
KEEPALIVE_INTERVAL=$KEEPALIVE_INTERVAL
KEEPALIVE_TIMEOUT=$KEEPALIVE_TIMEOUT
ENABLE_LOGGING="$ENABLE_LOGGING"
LOG_FILE="$HOME/.xray_keepalive.log"
EOF
    
    echo -e "${GREEN}保活配置已保存${NC}"
    
    # 创建保活脚本
    create_keepalive_script
    
    # 询问是否立即启动保活
    echo
    read -p "是否立即启动自动保活? (y/n): " START_NOW
    if [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
        start_keepalive_service
    fi
}

# 创建保活脚本
create_keepalive_script() {
    cat > "$HOME/xray_keepalive.sh" << 'EOF'
#!/bin/bash

# 日志文件
LOG_FILE="$HOME/.xray_keepalive.log"

# 日志函数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# 获取节点host或自定义URL
get_node_host() {
    # 首先检查是否有自定义保活配置
    if [ -f "$HOME/.xray_keepalive_config" ]; then
        source "$HOME/.xray_keepalive_config"
        if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
            echo "$CUSTOM_KEEPALIVE_URL"
            return 0
        fi
    fi
    
    # 从节点信息文件中提取host
    if [ -f "$HOME/.xray_nodes_info" ]; then
        # 方法1: 尝试从订阅链接中提取域名
        SUB_LINK=$(grep "订阅地址:" "$HOME/.xray_nodes_info" | head -1 | cut -d' ' -f2)
        if [ -n "$SUB_LINK" ]; then
            NODE_HOST=$(echo "$SUB_LINK" | sed -n 's|http://\([^:]*\):.*|\1|p')
            if [ -n "$NODE_HOST" ]; then
                echo "$NODE_HOST"
                return 0
            fi
        fi
        
        # 方法2: 尝试从节点配置中提取host参数（主要方法）
        NODE_HOST=$(grep -o 'host=[^&]*' "$HOME/.xray_nodes_info" | head -1 | cut -d'=' -f2)
        if [ -n "$NODE_HOST" ]; then
            echo "$NODE_HOST"
            return 0
        fi
        
        # 方法3: 尝试从vless链接中提取host参数（备用方法）
        NODE_HOST=$(grep -o 'host=[^&]*' "$HOME/.xray_nodes_info" | head -1 | cut -d'=' -f2)
        if [ -n "$NODE_HOST" ]; then
            echo "$NODE_HOST"
            return 0
        fi
        
        # 方法4: 尝试从整个文件内容中提取host参数（更全面的搜索）
        NODE_HOST=$(grep -o 'host=[^&]*' "$HOME/.xray_nodes_info" | head -1 | cut -d'=' -f2)
        if [ -n "$NODE_HOST" ]; then
            echo "$NODE_HOST"
            return 0
        fi
        
        # 方法5: 尝试从vless://链接中提取host（处理URL编码）
        VLESS_LINK=$(grep -o 'vless://[^#]*' "$HOME/.xray_nodes_info" | head -1)
        if [ -n "$VLESS_LINK" ]; then
            # 解码URL编码的host参数
            NODE_HOST=$(echo "$VLESS_LINK" | grep -o 'host=[^&]*' | cut -d'=' -f2 | sed 's/%2F/\//g' | sed 's/%3F/?/g' | sed 's/%3D/=/g')
            if [ -n "$NODE_HOST" ]; then
                echo "$NODE_HOST"
                return 0
            fi
        fi
        
        # 方法6: 使用sed直接提取host参数（更精确的方法）
        NODE_HOST=$(sed -n 's/.*host=\([^&]*\).*/\1/p' "$HOME/.xray_nodes_info" | head -1)
        if [ -n "$NODE_HOST" ]; then
            echo "$NODE_HOST"
            return 0
        fi
        
        # 方法7: 使用awk提取host参数
        NODE_HOST=$(awk -F'host=' '{for(i=2;i<=NF;i++) {split($i,a,"&"); print a[1]; exit}}' "$HOME/.xray_nodes_info")
        if [ -n "$NODE_HOST" ]; then
            echo "$NODE_HOST"
            return 0
        fi
    fi
    
    # 如果都没找到，返回默认值
    echo "localhost"
}

# 保活函数 - 使用curl请求
keepalive() {
    local host="$1"
    
    log_message "保活请求: $host"
    
    # 尝试HTTP请求
    if command -v curl &> /dev/null; then
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "http://$host" 2>/dev/null)
        if [ -n "$HTTP_STATUS" ] && [ "$HTTP_STATUS" != "000" ]; then
            log_message "保活请求: $host (HTTP) - 状态码: $HTTP_STATUS"
            return 0
        fi
        
        # 尝试HTTPS请求
        HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "https://$host" 2>/dev/null)
        if [ -n "$HTTPS_STATUS" ] && [ "$HTTPS_STATUS" != "000" ]; then
            log_message "保活请求: $host (HTTPS) - 状态码: $HTTPS_STATUS"
            return 0
        fi
    fi
    
    log_message "保活请求: $host - 连接失败 (状态码: 000)"
    return 1
}

# 主循环 - 每2分钟执行一次
log_message "保活服务启动，每2分钟执行一次curl请求"

# 检查是否有自定义URL
if [ -f "$HOME/.xray_keepalive_config" ]; then
    source "$HOME/.xray_keepalive_config"
    if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
        log_message "使用自定义保活URL: $CUSTOM_KEEPALIVE_URL"
    else
        log_message "正在获取节点host..."
    fi
else
    log_message "正在获取节点host..."
fi

while true; do
    NODE_HOST=$(get_node_host)
    
    if [ "$NODE_HOST" != "localhost" ]; then
        keepalive "$NODE_HOST"
    else
        log_message "未找到节点host，等待下次检测..."
    fi
    
    # 等待2分钟
    sleep 120
done
EOF
    
    chmod +x "$HOME/xray_keepalive.sh"
    echo -e "${GREEN}保活脚本已创建: $HOME/xray_keepalive.sh${NC}"
}

# 启动保活服务
start_keepalive_service() {
    echo -e "${BLUE}正在启动保活服务...${NC}"
    
    # 停止可能存在的保活进程
    pkill -f "xray_keepalive.sh" > /dev/null 2>&1
    sleep 2
    
    # 启动保活服务
    nohup "$HOME/xray_keepalive.sh" > /dev/null 2>&1 &
    KEEPALIVE_PID=$!
    
    if [ -n "$KEEPALIVE_PID" ] && ps -p "$KEEPALIVE_PID" > /dev/null 2>&1; then
        echo -e "${GREEN}保活服务已启动，PID: $KEEPALIVE_PID${NC}"
        
        # 保存PID到配置文件
        echo "KEEPALIVE_PID=$KEEPALIVE_PID" >> "$KEEPALIVE_CONFIG_FILE"
        
        # 创建systemd服务文件（如果支持）
        create_systemd_service
    else
        echo -e "${RED}保活服务启动失败${NC}"
    fi
}

# 创建systemd服务
create_systemd_service() {
    if command -v systemctl &> /dev/null; then
        echo -e "${BLUE}正在创建systemd服务...${NC}"
        
        cat > /tmp/xray-keepalive.service << EOF
[Unit]
Description=Xray Node Keepalive Service
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$HOME/xray_keepalive.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        if sudo cp /tmp/xray-keepalive.service /etc/systemd/system/; then
            sudo systemctl daemon-reload
            sudo systemctl enable xray-keepalive.service
            echo -e "${GREEN}systemd服务已创建并启用${NC}"
            echo -e "${YELLOW}管理命令:${NC}"
            echo -e "  启动: sudo systemctl start xray-keepalive"
            echo -e "  停止: sudo systemctl stop xray-keepalive"
            echo -e "  状态: sudo systemctl status xray-keepalive"
        else
            echo -e "${YELLOW}无法创建systemd服务，将使用nohup方式运行${NC}"
        fi
        
        rm -f /tmp/xray-keepalive.service
    fi
}

# 执行保活
execute_keepalive() {
    if [ ! -f "$KEEPALIVE_CONFIG_FILE" ]; then
        echo -e "${RED}未找到保活配置文件，请先配置${NC}"
        return
    fi
    
    source "$KEEPALIVE_CONFIG_FILE"
    
    echo -e "${BLUE}正在执行保活检测...${NC}"
    echo -e "目标: ${KEEPALIVE_HOST}"
    echo -e "超时: ${KEEPALIVE_TIMEOUT}秒"
    echo
    
    # 执行一次保活检测
    echo -e "${BLUE}正在执行保活检测...${NC}"
    timeout 30 bash "$HOME/xray_keepalive.sh" test > /tmp/keepalive_test.log 2>&1
    KEEPALIVE_EXIT_CODE=$?
    
    if [ $KEEPALIVE_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}保活检测成功${NC}"
    else
        echo -e "${YELLOW}保活检测完成${NC}"
    fi
    
    echo -e "${BLUE}检测结果:${NC}"
    cat /tmp/keepalive_test.log 2>/dev/null || echo "无检测结果"
    
    rm -f /tmp/keepalive_test.log
}

# 查看保活日志
view_keepalive_logs() {
    if [ -f "$HOME/.xray_keepalive.log" ]; then
        echo -e "${BLUE}=== 保活日志 ===${NC}"
        echo -e "${YELLOW}最近50行日志:${NC}"
        tail -n 50 "$HOME/.xray_keepalive.log"
        echo
        echo -e "${BLUE}日志文件: $HOME/.xray_keepalive.log${NC}"
    else
        echo -e "${YELLOW}未找到保活日志文件${NC}"
    fi
}

# 删除保活配置
delete_keepalive_config() {
    echo -e "${YELLOW}确定要删除保活配置吗? (y/n)${NC}"
    read -p "> " CONFIRM_DELETE
    
    if [ "$CONFIRM_DELETE" = "y" ] || [ "$CONFIRM_DELETE" = "Y" ]; then
        # 停止保活服务
        if [ -f "$KEEPALIVE_CONFIG_FILE" ]; then
            source "$KEEPALIVE_CONFIG_FILE"
            if [ -n "$KEEPALIVE_PID" ]; then
                kill "$KEEPALIVE_PID" > /dev/null 2>&1
            fi
        fi
        
        pkill -f "xray_keepalive.sh" > /dev/null 2>&1
        
        # 删除文件
        rm -f "$KEEPALIVE_CONFIG_FILE"
        rm -f "$HOME/xray_keepalive.sh"
        rm -f "$HOME/.xray_keepalive.log"
        
        # 删除systemd服务
        if command -v systemctl &> /dev/null; then
            sudo systemctl stop xray-keepalive.service > /dev/null 2>&1
            sudo systemctl disable xray-keepalive.service > /dev/null 2>&1
            sudo rm -f /etc/systemd/system/xray-keepalive.service > /dev/null 2>&1
            sudo systemctl daemon-reload > /dev/null 2>&1
        fi
        
        echo -e "${GREEN}保活配置已删除${NC}"
    else
        echo -e "${BLUE}取消删除${NC}"
    fi
}

generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    else
        hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/' | tr '[:upper:]' '[:lower:]'
    fi
}

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

if [ "$MODE_CHOICE" = "3" ]; then
    if [ -f "$NODE_INFO_FILE" ]; then
        echo
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}           节点信息查看               ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo
        cat "$NODE_INFO_FILE"
        echo
        echo -e "${YELLOW}提示: 如需重新部署，请重新运行脚本选择模式1或2${NC}"
    else
        echo
        echo -e "${RED}未找到节点信息文件${NC}"
        echo -e "${YELLOW}请先运行部署脚本生成节点信息${NC}"
        echo
        echo -e "${BLUE}是否现在开始部署? (y/n)${NC}"
        read -p "> " START_DEPLOY
        if [ "$START_DEPLOY" = "y" ] || [ "$START_DEPLOY" = "Y" ]; then
            echo -e "${YELLOW}请选择部署模式:${NC}"
            echo -e "${BLUE}1) 极速模式${NC}"
            echo -e "${BLUE}2) 完整模式${NC}"
            read -p "请输入选择 (1/2): " MODE_CHOICE
        else
            echo -e "${GREEN}退出脚本${NC}"
            exit 0
        fi
    fi
    
    if [ "$MODE_CHOICE" != "1" ] && [ "$MODE_CHOICE" != "2" ]; then
        echo -e "${GREEN}退出脚本${NC}"
        exit 0
    fi
elif [ "$MODE_CHOICE" = "4" ]; then
    show_keepalive_status
    exit 0
elif [ "$MODE_CHOICE" = "5" ]; then
    show_realtime_logs
    exit 0
fi

echo -e "${BLUE}检查并安装依赖...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python3...${NC}"
    sudo apt-get update && sudo apt-get install -y python3 python3-pip
fi

if ! python3 -c "import requests" &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python 依赖...${NC}"
    pip3 install requests
fi

PROJECT_DIR="python-xray-argo"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${BLUE}下载完整仓库...${NC}"
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
    
    if [ $? -ne 0 ] || [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}下载失败，请检查网络连接${NC}"
        exit 1
    fi
fi

cd "$PROJECT_DIR"

echo -e "${GREEN}依赖安装完成！${NC}"
echo

if [ ! -f "app.py" ]; then
    echo -e "${RED}未找到app.py文件！${NC}"
    exit 1
fi

cp app.py app.py.backup
echo -e "${YELLOW}已备份原始文件为 app.py.backup${NC}"

if [ "$MODE_CHOICE" = "1" ]; then
    echo -e "${BLUE}=== 极速模式 ===${NC}"
    echo
    
    echo -e "${YELLOW}当前UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)${NC}"
    read -p "请输入新的 UUID (留空自动生成): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID_INPUT=$(generate_uuid)
        echo -e "${GREEN}自动生成UUID: $UUID_INPUT${NC}"
    fi
    
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"
    
    sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', 'joeyblog.net')/" app.py
    echo -e "${GREEN}优选IP已自动设置为: joeyblog.net${NC}"
    echo -e "${GREEN}YouTube分流已自动配置${NC}"
    
    # 询问是否自定义保活URL
    echo
    echo -e "${YELLOW}是否自定义保活URL? (y/n，默认n使用自动检测)${NC}"
    read -p "> " CUSTOM_KEEPALIVE_CHOICE
    
    if [ "$CUSTOM_KEEPALIVE_CHOICE" = "y" ] || [ "$CUSTOM_KEEPALIVE_CHOICE" = "Y" ]; then
        echo -e "${BLUE}请输入自定义保活URL (例如: https://example.com 或 example.com)${NC}"
        read -p "> " CUSTOM_KEEPALIVE_URL
        
        if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
            # 创建保活配置文件
            mkdir -p "$HOME"
            cat > "$HOME/.xray_keepalive_config" << EOF
# Xray节点保活配置
CUSTOM_KEEPALIVE_URL="$CUSTOM_KEEPALIVE_URL"
EOF
            echo -e "${GREEN}自定义保活URL已设置: $CUSTOM_KEEPALIVE_URL${NC}"
        else
            echo -e "${YELLOW}未输入URL，将使用自动检测的节点host${NC}"
        fi
    else
        echo -e "${BLUE}将使用自动检测的节点host进行保活${NC}"
    fi
    
    echo
    echo -e "${GREEN}极速配置完成！正在启动服务...${NC}"
    echo
    
else
    echo -e "${BLUE}=== 完整配置模式 ===${NC}"
    echo
    
    echo -e "${YELLOW}当前UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)${NC}"
    read -p "请输入新的 UUID (留空自动生成): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID_INPUT=$(generate_uuid)
        echo -e "${GREEN}自动生成UUID: $UUID_INPUT${NC}"
    fi
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"

    echo -e "${YELLOW}当前节点名称: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)${NC}"
    read -p "请输入节点名称 (留空保持不变): " NAME_INPUT
    if [ -n "$NAME_INPUT" ]; then
        sed -i "s/NAME = os.environ.get('NAME', '[^']*')/NAME = os.environ.get('NAME', '$NAME_INPUT')/" app.py
        echo -e "${GREEN}节点名称已设置为: $NAME_INPUT${NC}"
    fi

    echo -e "${YELLOW}当前服务端口: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)${NC}"
    read -p "请输入服务端口 (留空保持不变): " PORT_INPUT
    if [ -n "$PORT_INPUT" ]; then
        sed -i "s/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or [0-9]*)/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or $PORT_INPUT)/" app.py
        echo -e "${GREEN}端口已设置为: $PORT_INPUT${NC}"
    fi

    echo -e "${YELLOW}当前优选IP: $(grep "CFIP = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入优选IP/域名 (留空使用默认 joeyblog.net): " CFIP_INPUT
    if [ -z "$CFIP_INPUT" ]; then
        CFIP_INPUT="joeyblog.net"
    fi
    sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', '$CFIP_INPUT')/" app.py
    echo -e "${GREEN}优选IP已设置为: $CFIP_INPUT${NC}"

    echo -e "${YELLOW}当前优选端口: $(grep "CFPORT = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入优选端口 (留空保持不变): " CFPORT_INPUT
    if [ -n "$CFPORT_INPUT" ]; then
        sed -i "s/CFPORT = int(os.environ.get('CFPORT', '[^']*'))/CFPORT = int(os.environ.get('CFPORT', '$CFPORT_INPUT'))/" app.py
        echo -e "${GREEN}优选端口已设置为: $CFPORT_INPUT${NC}"
    fi

    echo -e "${YELLOW}当前Argo端口: $(grep "ARGO_PORT = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入 Argo 端口 (留空保持不变): " ARGO_PORT_INPUT
    if [ -n "$ARGO_PORT_INPUT" ]; then
        sed -i "s/ARGO_PORT = int(os.environ.get('ARGO_PORT', '[^']*'))/ARGO_PORT = int(os.environ.get('ARGO_PORT', '$ARGO_PORT_INPUT'))/" app.py
        echo -e "${GREEN}Argo端口已设置为: $ARGO_PORT_INPUT${NC}"
    fi

    echo -e "${YELLOW}当前订阅路径: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入订阅路径 (留空保持不变): " SUB_PATH_INPUT
    if [ -n "$SUB_PATH_INPUT" ]; then
        sed -i "s/SUB_PATH = os.environ.get('SUB_PATH', '[^']*')/SUB_PATH = os.environ.get('SUB_PATH', '$SUB_PATH_INPUT')/" app.py
        echo -e "${GREEN}订阅路径已设置为: $SUB_PATH_INPUT${NC}"
    fi

    echo
    echo -e "${YELLOW}是否配置高级选项? (y/n)${NC}"
    read -p "> " ADVANCED_CONFIG

    if [ "$ADVANCED_CONFIG" = "y" ] || [ "$ADVANCED_CONFIG" = "Y" ]; then
        echo -e "${YELLOW}当前上传URL: $(grep "UPLOAD_URL = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入上传URL (留空保持不变): " UPLOAD_URL_INPUT
        if [ -n "$UPLOAD_URL_INPUT" ]; then
            sed -i "s|UPLOAD_URL = os.environ.get('UPLOAD_URL', '[^']*')|UPLOAD_URL = os.environ.get('UPLOAD_URL', '$UPLOAD_URL_INPUT')|" app.py
            echo -e "${GREEN}上传URL已设置${NC}"
        fi

        echo -e "${YELLOW}当前项目URL: $(grep "PROJECT_URL = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入项目URL (留空保持不变): " PROJECT_URL_INPUT
        if [ -n "$PROJECT_URL_INPUT" ]; then
            sed -i "s|PROJECT_URL = os.environ.get('PROJECT_URL', '[^']*')|PROJECT_URL = os.environ.get('PROJECT_URL', '$PROJECT_URL_INPUT')|" app.py
            echo -e "${GREEN}项目URL已设置${NC}"
        fi

        echo -e "${YELLOW}注意: 自动保活功能已移至脚本管理，请使用选项4进行配置${NC}"

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
    
    echo -e "${GREEN}YouTube分流已自动配置${NC}"

    # 询问是否自定义保活URL
    echo
    echo -e "${YELLOW}是否自定义保活URL? (y/n，默认n使用自动检测)${NC}"
    read -p "> " CUSTOM_KEEPALIVE_CHOICE
    
    if [ "$CUSTOM_KEEPALIVE_CHOICE" = "y" ] || [ "$CUSTOM_KEEPALIVE_CHOICE" = "Y" ]; then
        echo -e "${BLUE}请输入自定义保活URL (例如: https://example.com 或 example.com)${NC}"
        read -p "> " CUSTOM_KEEPALIVE_URL
        
        if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
            # 创建保活配置文件
            mkdir -p "$HOME"
            cat > "$HOME/.xray_keepalive_config" << EOF
# Xray节点保活配置
CUSTOM_KEEPALIVE_URL="$CUSTOM_KEEPALIVE_URL"
EOF
            echo -e "${GREEN}自定义保活URL已设置: $CUSTOM_KEEPALIVE_URL${NC}"
        else
            echo -e "${YELLOW}未输入URL，将使用自动检测的节点host${NC}"
        fi
    else
        echo -e "${BLUE}将使用自动检测的节点host进行保活${NC}"
    fi

    echo
    echo -e "${GREEN}完整配置完成！${NC}"
fi

echo -e "${YELLOW}=== 当前配置摘要 ===${NC}"
echo -e "UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)"
echo -e "节点名称: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)"
echo -e "服务端口: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)"
echo -e "优选IP: $(grep "CFIP = " app.py | cut -d"'" -f4)"
echo -e "优选端口: $(grep "CFPORT = " app.py | cut -d"'" -f4)"
echo -e "订阅路径: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)"
echo -e "${YELLOW}========================${NC}"
echo

echo -e "${BLUE}正在启动服务...${NC}"
echo -e "${YELLOW}当前工作目录：$(pwd)${NC}"
echo

# 修改Python文件添加YouTube分流到xray配置，并增加80端口节点
echo -e "${BLUE}正在添加YouTube分流功能和80端口节点...${NC}"
cat > youtube_patch.py << 'EOF'
# 读取app.py文件
with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 找到原始配置并替换为包含YouTube分流的配置
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

python3 youtube_patch.py
rm youtube_patch.py

echo -e "${GREEN}YouTube分流和80端口节点已集成${NC}"

# 先清理可能存在的进程
pkill -f "python3 app.py" > /dev/null 2>&1
sleep 2

# 启动服务并获取PID
python3 app.py > app.log 2>&1 &
APP_PID=$!

# 验证PID获取成功
if [ -z "$APP_PID" ] || [ "$APP_PID" -eq 0 ]; then
    echo -e "${RED}获取进程PID失败，尝试直接启动${NC}"
    nohup python3 app.py > app.log 2>&1 &
    sleep 2
    APP_PID=$(pgrep -f "python3 app.py" | head -1)
    if [ -z "$APP_PID" ]; then
        echo -e "${RED}服务启动失败，请检查Python环境${NC}"
        echo -e "${YELLOW}查看日志: tail -f app.log${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}服务已在后台启动，PID: $APP_PID${NC}"
echo -e "${YELLOW}日志文件: $(pwd)/app.log${NC}"

echo -e "${BLUE}等待服务启动...${NC}"
sleep 8

# 检查服务是否正常运行
if ! ps -p "$APP_PID" > /dev/null 2>&1; then
    echo -e "${RED}服务启动失败，请检查日志${NC}"
    echo -e "${YELLOW}查看日志: tail -f app.log${NC}"
    echo -e "${YELLOW}检查端口占用: netstat -tlnp | grep :3000${NC}"
    exit 1
fi

echo -e "${GREEN}服务运行正常${NC}"

SERVICE_PORT=$(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)
CURRENT_UUID=$(grep "UUID = " app.py | head -1 | cut -d"'" -f2)
SUB_PATH_VALUE=$(grep "SUB_PATH = " app.py | cut -d"'" -f4)

echo -e "${BLUE}等待节点信息生成...${NC}"
echo -e "${YELLOW}正在等待Argo隧道建立和节点生成，请耐心等待...${NC}"

# 循环等待节点信息生成，最多等待10分钟
MAX_WAIT=600  # 10分钟
WAIT_COUNT=0
NODE_INFO=""

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -f ".cache/sub.txt" ]; then
        NODE_INFO=$(cat .cache/sub.txt 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}节点信息已生成！${NC}"
            break
        fi
    elif [ -f "sub.txt" ]; then
        NODE_INFO=$(cat sub.txt 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}节点信息已生成！${NC}"
            break
        fi
    fi
    
    # 每30秒显示一次等待提示
    if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
        MINUTES=$((WAIT_COUNT / 60))
        SECONDS=$((WAIT_COUNT % 60))
        echo -e "${YELLOW}已等待 ${MINUTES}分${SECONDS}秒，继续等待节点生成...${NC}"
        echo -e "${BLUE}提示: Argo隧道建立需要时间，请继续等待${NC}"
    fi
    
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 5))
done

# 检查是否成功获取到节点信息
if [ -z "$NODE_INFO" ]; then
    echo -e "${RED}等待超时！节点信息未能在10分钟内生成${NC}"
    echo -e "${YELLOW}可能原因：${NC}"
    echo -e "1. 网络连接问题"
    echo -e "2. Argo隧道建立失败"
    echo -e "3. 服务配置错误"
    echo
    echo -e "${BLUE}建议操作：${NC}"
    echo -e "1. 查看日志: ${YELLOW}tail -f $(pwd)/app.log${NC}"
    echo -e "2. 检查服务: ${YELLOW}ps aux | grep python3${NC}"
    echo -e "3. 重新运行脚本"
    echo
    echo -e "${YELLOW}服务信息：${NC}"
    echo -e "进程PID: ${BLUE}$APP_PID${NC}"
    echo -e "服务端口: ${BLUE}$SERVICE_PORT${NC}"
    echo -e "日志文件: ${YELLOW}$(pwd)/app.log${NC}"
    exit 1
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}           部署完成！                   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo

echo -e "${YELLOW}=== 服务信息 ===${NC}"
echo -e "服务状态: ${GREEN}运行中${NC}"
echo -e "进程PID: ${BLUE}$APP_PID${NC}"
echo -e "服务端口: ${BLUE}$SERVICE_PORT${NC}"
echo -e "UUID: ${BLUE}$CURRENT_UUID${NC}"
echo -e "订阅路径: ${BLUE}/$SUB_PATH_VALUE${NC}"
echo

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

echo -e "${YELLOW}=== 节点信息 ===${NC}"
DECODED_NODES=$(echo "$NODE_INFO" | base64 -d 2>/dev/null || echo "$NODE_INFO")

echo -e "${GREEN}节点配置:${NC}"
echo "$DECODED_NODES"
echo

echo -e "${GREEN}订阅链接:${NC}"
echo "$NODE_INFO"
echo

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

=== 分流说明 ===
- 已集成YouTube分流优化到xray配置
- YouTube相关域名自动走专用线路
- 无需额外配置，透明分流"

echo "$SAVE_INFO" > "$NODE_INFO_FILE"
echo -e "${GREEN}节点信息已保存到 $NODE_INFO_FILE${NC}"
echo -e "${YELLOW}使用脚本选择选项3可随时查看节点信息${NC}"

echo -e "${YELLOW}=== 重要提示 ===${NC}"
echo -e "${GREEN}部署已完成，节点信息已成功生成${NC}"
echo -e "${GREEN}可以立即使用订阅地址添加到客户端${NC}"
echo -e "${GREEN}YouTube分流已集成到xray配置，无需额外设置${NC}"
echo -e "${GREEN}服务将持续在后台运行${NC}"
echo

echo -e "${YELLOW}=== 保活功能说明 ===${NC}"
echo -e "${GREEN}新增智能保活功能，支持自定义URL和自动检测${NC}"
echo -e "${BLUE}使用方法:${NC}"
echo -e "  1. 运行脚本选择选项4查看保活状态"
echo -e "  2. 选择选项5查看实时日志"
echo -e "  3. 保活功能自动启动，无需手动配置"
echo -e "  4. 优先使用自定义URL，否则自动检测节点host"
echo -e "  5. 每2分钟执行一次HTTP/HTTPS请求"
echo -e "  6. 显示HTTP状态码，支持日志记录和状态监控"
echo

echo -e "${GREEN}部署完成！感谢使用！${NC}"

# 自动启动保活服务
echo -e "${BLUE}正在启动保活服务...${NC}"
if [ -f "$HOME/xray_keepalive.sh" ]; then
    # 停止可能存在的保活进程
    pkill -f "xray_keepalive.sh" > /dev/null 2>&1
    sleep 2
    
    # 启动保活服务
    nohup "$HOME/xray_keepalive.sh" > /dev/null 2>&1 &
    KEEPALIVE_PID=$!
    
    if [ -n "$KEEPALIVE_PID" ] && ps -p "$KEEPALIVE_PID" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 保活服务已启动，PID: $KEEPALIVE_PID${NC}"
        echo -e "${BLUE}保活服务将每2分钟自动curl请求节点host${NC}"
    else
        echo -e "${YELLOW}⚠️  保活服务启动失败，请手动检查${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  保活脚本未找到，正在创建...${NC}"
    create_keepalive_script
    
    # 启动保活服务
    nohup "$HOME/xray_keepalive.sh" > /dev/null 2>&1 &
    KEEPALIVE_PID=$!
    
    if [ -n "$KEEPALIVE_PID" ] && ps -p "$KEEPALIVE_PID" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 保活服务已启动，PID: $KEEPALIVE_PID${NC}"
        echo -e "${BLUE}保活服务将每2分钟自动curl请求节点host${NC}"
    else
        echo -e "${YELLOW}⚠️  保活服务启动失败${NC}"
    fi
fi

echo
echo -e "${GREEN}🎉 所有服务已启动完成！${NC}"

# 退出脚本，避免重复执行
exit 0    echo -e "${GREEN}       Python Xray Argo 部署脚本      ${NC}"
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
echo -e "  部署完成后自动启动"
echo
echo -e "${BLUE}示例:${NC}"
echo -e "  bash $(basename $0) -v    # 查看节点信息"
    echo
    exit 0
fi

# 显示保活状态函数
show_keepalive_status() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           保活状态监控               ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    # 检查保活进程
    KEEPALIVE_PID=$(pgrep -f "xray_keepalive.sh" | head -1)
    if [ -n "$KEEPALIVE_PID" ]; then
        echo -e "${GREEN}✅ 保活服务运行中${NC}"
        echo -e "进程PID: ${BLUE}$KEEPALIVE_PID${NC}"
        
        # 显示进程信息
        if command -v ps &> /dev/null; then
            echo -e "${YELLOW}进程详情:${NC}"
            ps -p "$KEEPALIVE_PID" -o pid,ppid,cmd,etime,pcpu,pmem 2>/dev/null || echo "无法获取进程详情"
        fi
    else
        echo -e "${RED}❌ 保活服务未运行${NC}"
    fi
    
    echo
    
    # 显示配置文件信息
    if [ -f "$KEEPALIVE_CONFIG_FILE" ]; then
        echo -e "${BLUE}当前保活配置:${NC}"
        cat "$KEEPALIVE_CONFIG_FILE"
        echo
    else
        echo -e "${YELLOW}未找到保活配置文件${NC}"
        echo -e "${BLUE}保活功能将自动使用节点host进行curl请求${NC}"
    fi
    
    # 显示统计信息
    if [ -f "$HOME/.xray_keepalive.log" ]; then
        echo -e "${YELLOW}保活统计信息:${NC}"
        
        # 使用更安全的统计方法
        TOTAL_REQUESTS=$(grep -c "保活请求" "$HOME/.xray_keepalive.log" 2>/dev/null)
        HTTP_REQUESTS=$(grep -c "状态码:" "$HOME/.xray_keepalive.log" 2>/dev/null)
        FAILED_REQUESTS=$(grep -c "连接失败" "$HOME/.xray_keepalive.log" 2>/dev/null)
        
        # 确保变量有值
        TOTAL_REQUESTS=${TOTAL_REQUESTS:-0}
        HTTP_REQUESTS=${HTTP_REQUESTS:-0}
        FAILED_REQUESTS=${FAILED_REQUESTS:-0}
        
        echo -e "总请求次数: ${BLUE}$TOTAL_REQUESTS${NC}"
        echo -e "有效响应次数: ${GREEN}$HTTP_REQUESTS${NC}"
        echo -e "连接失败次数: ${RED}$FAILED_REQUESTS${NC}"
        
        # 显示状态码分布
        echo -e "${YELLOW}状态码分布:${NC}"
        grep "状态码:" "$HOME/.xray_keepalive.log" | grep -o "状态码: [0-9]*" | sort | uniq -c | sort -nr | head -5 | while read count status; do
            echo -e "  $status: ${BLUE}$count${NC}次"
        done
        
        echo
        echo -e "${YELLOW}最近5次保活记录:${NC}"
        if [ -s "$HOME/.xray_keepalive.log" ]; then
            tail -n 5 "$HOME/.xray_keepalive.log" 2>/dev/null || echo "无记录"
        else
            echo "日志文件为空"
        fi
    else
        echo -e "${YELLOW}未找到保活日志文件${NC}"
    fi
    
    echo
    echo -e "${BLUE}保活功能说明:${NC}"
    echo -e "• 自动每2分钟向节点host或自定义URL发送curl请求"
    echo -e "• 支持HTTP和HTTPS两种协议"
    echo -e "• 显示HTTP状态码而不是成功/失败"
    echo -e "• 优先使用自定义URL，否则自动检测节点host"
    echo -e "• 无需手动配置，部署后自动启动"
    
    echo
    read -p "按回车键返回主菜单..."
}

# 显示实时日志函数
show_realtime_logs() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           实时日志监控               ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    echo -e "${YELLOW}选择要查看的日志:${NC}"
    echo -e "${BLUE}1) 服务运行日志 (app.log)${NC}"
    echo -e "${BLUE}2) 保活功能日志${NC}"
    echo -e "${BLUE}3) 系统日志 (如果支持)${NC}"
    echo -e "${BLUE}4) 返回主菜单${NC}"
    echo
    
    read -p "请输入选择 (1-4): " LOG_CHOICE
    
    case $LOG_CHOICE in
        1)
            if [ -f "app.log" ]; then
                echo -e "${GREEN}正在显示服务运行日志，按Ctrl+C退出...${NC}"
                echo -e "${YELLOW}日志文件: $(pwd)/app.log${NC}"
                echo
                tail -f app.log
            else
                echo -e "${RED}未找到服务日志文件${NC}"
                read -p "按回车键返回..."
            fi
            ;;
        2)
            if [ -f "$HOME/.xray_keepalive.log" ]; then
                echo -e "${GREEN}正在显示保活功能日志，按Ctrl+C退出...${NC}"
                echo -e "${YELLOW}日志文件: $HOME/.xray_keepalive.log${NC}"
                echo
                tail -f "$HOME/.xray_keepalive.log"
            else
                echo -e "${RED}未找到保活日志文件${NC}"
                read -p "按回车键返回..."
            fi
            ;;
        3)
            if command -v journalctl &> /dev/null; then
                echo -e "${GREEN}正在显示系统日志，按Ctrl+C退出...${NC}"
                echo -e "${YELLOW}显示最近的系统日志${NC}"
                echo
                journalctl -f -n 50
            else
                echo -e "${YELLOW}系统不支持journalctl${NC}"
                read -p "按回车键返回..."
            fi
            ;;
        4)
            return
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            show_realtime_logs
            ;;
    esac
}

# 配置保活
configure_keepalive() {
    echo -e "${BLUE}=== 配置自动保活 ===${NC}"
    echo
    
    # 检查是否有节点信息
    if [ ! -f "$NODE_INFO_FILE" ]; then
        echo -e "${RED}未找到节点信息文件，请先部署服务${NC}"
        return
    fi
    
    # 从节点信息中提取host
    NODE_HOST=""
    if [ -f "$NODE_INFO_FILE" ]; then
        # 尝试从订阅链接中提取域名
        SUB_LINK=$(grep "订阅地址:" "$NODE_INFO_FILE" | head -1 | cut -d' ' -f2)
        if [ -n "$SUB_LINK" ]; then
            NODE_HOST=$(echo "$SUB_LINK" | sed -n 's|http://\([^:]*\):.*|\1|p')
        fi
        
        # 如果没找到，尝试从节点配置中提取
        if [ -z "$NODE_HOST" ]; then
            NODE_HOST=$(grep -o 'host=[^&]*' "$NODE_INFO_FILE" | head -1 | cut -d'=' -f2)
        fi
    fi
    
    echo -e "${YELLOW}检测到的节点Host: ${BLUE}${NODE_HOST:-未检测到}${NC}"
    echo
    
    read -p "请输入保活目标Host (留空使用检测到的): " KEEPALIVE_HOST
    if [ -z "$KEEPALIVE_HOST" ]; then
        KEEPALIVE_HOST="$NODE_HOST"
    fi
    
    if [ -z "$KEEPALIVE_HOST" ]; then
        echo -e "${RED}无法确定保活目标，请手动输入${NC}"
        read -p "请输入保活目标Host: " KEEPALIVE_HOST
        if [ -z "$KEEPALIVE_HOST" ]; then
            echo -e "${RED}保活目标不能为空${NC}"
            return
        fi
    fi
    
    read -p "请输入保活间隔(分钟，默认30): " KEEPALIVE_INTERVAL
    if [ -z "$KEEPALIVE_INTERVAL" ]; then
        KEEPALIVE_INTERVAL=30
    fi
    
    read -p "请输入保活超时时间(秒，默认10): " KEEPALIVE_TIMEOUT
    if [ -z "$KEEPALIVE_TIMEOUT" ]; then
        KEEPALIVE_TIMEOUT=10
    fi
    
    read -p "是否启用日志记录? (y/n，默认y): " ENABLE_LOGGING
    if [ -z "$ENABLE_LOGGING" ] || [ "$ENABLE_LOGGING" = "y" ] || [ "$ENABLE_LOGGING" = "Y" ]; then
        ENABLE_LOGGING="true"
    else
        ENABLE_LOGGING="false"
    fi
    
    # 保存配置
    cat > "$KEEPALIVE_CONFIG_FILE" << EOF
# Xray节点保活配置
KEEPALIVE_HOST="$KEEPALIVE_HOST"
KEEPALIVE_INTERVAL=$KEEPALIVE_INTERVAL
KEEPALIVE_TIMEOUT=$KEEPALIVE_TIMEOUT
ENABLE_LOGGING="$ENABLE_LOGGING"
LOG_FILE="$HOME/.xray_keepalive.log"
EOF
    
    echo -e "${GREEN}保活配置已保存${NC}"
    
    # 创建保活脚本
    create_keepalive_script
    
    # 询问是否立即启动保活
    echo
    read -p "是否立即启动自动保活? (y/n): " START_NOW
    if [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
        start_keepalive_service
    fi
}

# 创建保活脚本
create_keepalive_script() {
    cat > "$HOME/xray_keepalive.sh" << 'EOF'
#!/bin/bash

# 日志文件
LOG_FILE="$HOME/.xray_keepalive.log"

# 日志函数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# 获取节点host或自定义URL
get_node_host() {
    # 首先检查是否有自定义保活配置
    if [ -f "$HOME/.xray_keepalive_config" ]; then
        source "$HOME/.xray_keepalive_config"
        if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
            echo "$CUSTOM_KEEPALIVE_URL"
            return 0
        fi
    fi
    
    # 从节点信息文件中提取host
    if [ -f "$HOME/.xray_nodes_info" ]; then
        # 方法1: 尝试从订阅链接中提取域名
        SUB_LINK=$(grep "订阅地址:" "$HOME/.xray_nodes_info" | head -1 | cut -d' ' -f2)
        if [ -n "$SUB_LINK" ]; then
            NODE_HOST=$(echo "$SUB_LINK" | sed -n 's|http://\([^:]*\):.*|\1|p')
            if [ -n "$NODE_HOST" ]; then
                echo "$NODE_HOST"
                return 0
            fi
        fi
        
        # 方法2: 尝试从节点配置中提取host参数（主要方法）
        NODE_HOST=$(grep -o 'host=[^&]*' "$HOME/.xray_nodes_info" | head -1 | cut -d'=' -f2)
        if [ -n "$NODE_HOST" ]; then
            echo "$NODE_HOST"
            return 0
        fi
        
        # 方法3: 尝试从vless链接中提取host参数（备用方法）
        NODE_HOST=$(grep -o 'host=[^&]*' "$HOME/.xray_nodes_info" | head -1 | cut -d'=' -f2)
        if [ -n "$NODE_HOST" ]; then
            echo "$NODE_HOST"
            return 0
        fi
        
        # 方法4: 尝试从整个文件内容中提取host参数（更全面的搜索）
        NODE_HOST=$(grep -o 'host=[^&]*' "$HOME/.xray_nodes_info" | head -1 | cut -d'=' -f2)
        if [ -n "$NODE_HOST" ]; then
            echo "$NODE_HOST"
            return 0
        fi
        
        # 方法5: 尝试从vless://链接中提取host（处理URL编码）
        VLESS_LINK=$(grep -o 'vless://[^#]*' "$HOME/.xray_nodes_info" | head -1)
        if [ -n "$VLESS_LINK" ]; then
            # 解码URL编码的host参数
            NODE_HOST=$(echo "$VLESS_LINK" | grep -o 'host=[^&]*' | cut -d'=' -f2 | sed 's/%2F/\//g' | sed 's/%3F/?/g' | sed 's/%3D/=/g')
            if [ -n "$NODE_HOST" ]; then
                echo "$NODE_HOST"
                return 0
            fi
        fi
        
        # 方法6: 使用sed直接提取host参数（更精确的方法）
        NODE_HOST=$(sed -n 's/.*host=\([^&]*\).*/\1/p' "$HOME/.xray_nodes_info" | head -1)
        if [ -n "$NODE_HOST" ]; then
            echo "$NODE_HOST"
            return 0
        fi
        
        # 方法7: 使用awk提取host参数
        NODE_HOST=$(awk -F'host=' '{for(i=2;i<=NF;i++) {split($i,a,"&"); print a[1]; exit}}' "$HOME/.xray_nodes_info")
        if [ -n "$NODE_HOST" ]; then
            echo "$NODE_HOST"
            return 0
        fi
    fi
    
    # 如果都没找到，返回默认值
    echo "localhost"
}

# 保活函数 - 使用curl请求
keepalive() {
    local host="$1"
    
    log_message "保活请求: $host"
    
    # 尝试HTTP请求
    if command -v curl &> /dev/null; then
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "http://$host" 2>/dev/null)
        if [ -n "$HTTP_STATUS" ] && [ "$HTTP_STATUS" != "000" ]; then
            log_message "保活请求: $host (HTTP) - 状态码: $HTTP_STATUS"
            return 0
        fi
        
        # 尝试HTTPS请求
        HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "https://$host" 2>/dev/null)
        if [ -n "$HTTPS_STATUS" ] && [ "$HTTPS_STATUS" != "000" ]; then
            log_message "保活请求: $host (HTTPS) - 状态码: $HTTPS_STATUS"
            return 0
        fi
    fi
    
    log_message "保活请求: $host - 连接失败 (状态码: 000)"
    return 1
}

# 主循环 - 每2分钟执行一次
log_message "保活服务启动，每2分钟执行一次curl请求"

# 检查是否有自定义URL
if [ -f "$HOME/.xray_keepalive_config" ]; then
    source "$HOME/.xray_keepalive_config"
    if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
        log_message "使用自定义保活URL: $CUSTOM_KEEPALIVE_URL"
    else
        log_message "正在获取节点host..."
    fi
else
    log_message "正在获取节点host..."
fi

while true; do
    NODE_HOST=$(get_node_host)
    
    if [ "$NODE_HOST" != "localhost" ]; then
        keepalive "$NODE_HOST"
    else
        log_message "未找到节点host，等待下次检测..."
    fi
    
    # 等待2分钟
    sleep 120
done
EOF
    
    chmod +x "$HOME/xray_keepalive.sh"
    echo -e "${GREEN}保活脚本已创建: $HOME/xray_keepalive.sh${NC}"
}

# 启动保活服务
start_keepalive_service() {
    echo -e "${BLUE}正在启动保活服务...${NC}"
    
    # 停止可能存在的保活进程
    pkill -f "xray_keepalive.sh" > /dev/null 2>&1
    sleep 2
    
    # 启动保活服务
    nohup "$HOME/xray_keepalive.sh" > /dev/null 2>&1 &
    KEEPALIVE_PID=$!
    
    if [ -n "$KEEPALIVE_PID" ] && ps -p "$KEEPALIVE_PID" > /dev/null 2>&1; then
        echo -e "${GREEN}保活服务已启动，PID: $KEEPALIVE_PID${NC}"
        
        # 保存PID到配置文件
        echo "KEEPALIVE_PID=$KEEPALIVE_PID" >> "$KEEPALIVE_CONFIG_FILE"
        
        # 创建systemd服务文件（如果支持）
        create_systemd_service
    else
        echo -e "${RED}保活服务启动失败${NC}"
    fi
}

# 创建systemd服务
create_systemd_service() {
    if command -v systemctl &> /dev/null; then
        echo -e "${BLUE}正在创建systemd服务...${NC}"
        
        cat > /tmp/xray-keepalive.service << EOF
[Unit]
Description=Xray Node Keepalive Service
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$HOME/xray_keepalive.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        if sudo cp /tmp/xray-keepalive.service /etc/systemd/system/; then
            sudo systemctl daemon-reload
            sudo systemctl enable xray-keepalive.service
            echo -e "${GREEN}systemd服务已创建并启用${NC}"
            echo -e "${YELLOW}管理命令:${NC}"
            echo -e "  启动: sudo systemctl start xray-keepalive"
            echo -e "  停止: sudo systemctl stop xray-keepalive"
            echo -e "  状态: sudo systemctl status xray-keepalive"
        else
            echo -e "${YELLOW}无法创建systemd服务，将使用nohup方式运行${NC}"
        fi
        
        rm -f /tmp/xray-keepalive.service
    fi
}

# 执行保活
execute_keepalive() {
    if [ ! -f "$KEEPALIVE_CONFIG_FILE" ]; then
        echo -e "${RED}未找到保活配置文件，请先配置${NC}"
        return
    fi
    
    source "$KEEPALIVE_CONFIG_FILE"
    
    echo -e "${BLUE}正在执行保活检测...${NC}"
    echo -e "目标: ${KEEPALIVE_HOST}"
    echo -e "超时: ${KEEPALIVE_TIMEOUT}秒"
    echo
    
    # 执行一次保活检测
    echo -e "${BLUE}正在执行保活检测...${NC}"
    timeout 30 bash "$HOME/xray_keepalive.sh" test > /tmp/keepalive_test.log 2>&1
    KEEPALIVE_EXIT_CODE=$?
    
    if [ $KEEPALIVE_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}保活检测成功${NC}"
    else
        echo -e "${YELLOW}保活检测完成${NC}"
    fi
    
    echo -e "${BLUE}检测结果:${NC}"
    cat /tmp/keepalive_test.log 2>/dev/null || echo "无检测结果"
    
    rm -f /tmp/keepalive_test.log
}

# 查看保活日志
view_keepalive_logs() {
    if [ -f "$HOME/.xray_keepalive.log" ]; then
        echo -e "${BLUE}=== 保活日志 ===${NC}"
        echo -e "${YELLOW}最近50行日志:${NC}"
        tail -n 50 "$HOME/.xray_keepalive.log"
        echo
        echo -e "${BLUE}日志文件: $HOME/.xray_keepalive.log${NC}"
    else
        echo -e "${YELLOW}未找到保活日志文件${NC}"
    fi
}

# 删除保活配置
delete_keepalive_config() {
    echo -e "${YELLOW}确定要删除保活配置吗? (y/n)${NC}"
    read -p "> " CONFIRM_DELETE
    
    if [ "$CONFIRM_DELETE" = "y" ] || [ "$CONFIRM_DELETE" = "Y" ]; then
        # 停止保活服务
        if [ -f "$KEEPALIVE_CONFIG_FILE" ]; then
            source "$KEEPALIVE_CONFIG_FILE"
            if [ -n "$KEEPALIVE_PID" ]; then
                kill "$KEEPALIVE_PID" > /dev/null 2>&1
            fi
        fi
        
        pkill -f "xray_keepalive.sh" > /dev/null 2>&1
        
        # 删除文件
        rm -f "$KEEPALIVE_CONFIG_FILE"
        rm -f "$HOME/xray_keepalive.sh"
        rm -f "$HOME/.xray_keepalive.log"
        
        # 删除systemd服务
        if command -v systemctl &> /dev/null; then
            sudo systemctl stop xray-keepalive.service > /dev/null 2>&1
            sudo systemctl disable xray-keepalive.service > /dev/null 2>&1
            sudo rm -f /etc/systemd/system/xray-keepalive.service > /dev/null 2>&1
            sudo systemctl daemon-reload > /dev/null 2>&1
        fi
        
        echo -e "${GREEN}保活配置已删除${NC}"
    else
        echo -e "${BLUE}取消删除${NC}"
    fi
}

generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    else
        hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/' | tr '[:upper:]' '[:lower:]'
    fi
}

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

if [ "$MODE_CHOICE" = "3" ]; then
    if [ -f "$NODE_INFO_FILE" ]; then
        echo
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}           节点信息查看               ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo
        cat "$NODE_INFO_FILE"
        echo
        echo -e "${YELLOW}提示: 如需重新部署，请重新运行脚本选择模式1或2${NC}"
    else
        echo
        echo -e "${RED}未找到节点信息文件${NC}"
        echo -e "${YELLOW}请先运行部署脚本生成节点信息${NC}"
        echo
        echo -e "${BLUE}是否现在开始部署? (y/n)${NC}"
        read -p "> " START_DEPLOY
        if [ "$START_DEPLOY" = "y" ] || [ "$START_DEPLOY" = "Y" ]; then
            echo -e "${YELLOW}请选择部署模式:${NC}"
            echo -e "${BLUE}1) 极速模式${NC}"
            echo -e "${BLUE}2) 完整模式${NC}"
            read -p "请输入选择 (1/2): " MODE_CHOICE
        else
            echo -e "${GREEN}退出脚本${NC}"
            exit 0
        fi
    fi
    
    if [ "$MODE_CHOICE" != "1" ] && [ "$MODE_CHOICE" != "2" ]; then
        echo -e "${GREEN}退出脚本${NC}"
        exit 0
    fi
elif [ "$MODE_CHOICE" = "4" ]; then
    show_keepalive_status
    exit 0
elif [ "$MODE_CHOICE" = "5" ]; then
    show_realtime_logs
    exit 0
fi

echo -e "${BLUE}检查并安装依赖...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python3...${NC}"
    sudo apt-get update && sudo apt-get install -y python3 python3-pip
fi

if ! python3 -c "import requests" &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python 依赖...${NC}"
    pip3 install requests
fi

PROJECT_DIR="python-xray-argo"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${BLUE}下载完整仓库...${NC}"
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
    
    if [ $? -ne 0 ] || [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}下载失败，请检查网络连接${NC}"
        exit 1
    fi
fi

cd "$PROJECT_DIR"

echo -e "${GREEN}依赖安装完成！${NC}"
echo

if [ ! -f "app.py" ]; then
    echo -e "${RED}未找到app.py文件！${NC}"
    exit 1
fi

cp app.py app.py.backup
echo -e "${YELLOW}已备份原始文件为 app.py.backup${NC}"

if [ "$MODE_CHOICE" = "1" ]; then
    echo -e "${BLUE}=== 极速模式 ===${NC}"
    echo
    
    echo -e "${YELLOW}当前UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)${NC}"
    read -p "请输入新的 UUID (留空自动生成): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID_INPUT=$(generate_uuid)
        echo -e "${GREEN}自动生成UUID: $UUID_INPUT${NC}"
    fi
    
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"
    
    sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', 'joeyblog.net')/" app.py
    echo -e "${GREEN}优选IP已自动设置为: joeyblog.net${NC}"
    echo -e "${GREEN}YouTube分流已自动配置${NC}"
    
    # 询问是否自定义保活URL
    echo
    echo -e "${YELLOW}是否自定义保活URL? (y/n，默认n使用自动检测)${NC}"
    read -p "> " CUSTOM_KEEPALIVE_CHOICE
    
    if [ "$CUSTOM_KEEPALIVE_CHOICE" = "y" ] || [ "$CUSTOM_KEEPALIVE_CHOICE" = "Y" ]; then
        echo -e "${BLUE}请输入自定义保活URL (例如: https://example.com 或 example.com)${NC}"
        read -p "> " CUSTOM_KEEPALIVE_URL
        
        if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
            # 创建保活配置文件
            mkdir -p "$HOME"
            cat > "$HOME/.xray_keepalive_config" << EOF
# Xray节点保活配置
CUSTOM_KEEPALIVE_URL="$CUSTOM_KEEPALIVE_URL"
EOF
            echo -e "${GREEN}自定义保活URL已设置: $CUSTOM_KEEPALIVE_URL${NC}"
        else
            echo -e "${YELLOW}未输入URL，将使用自动检测的节点host${NC}"
        fi
    else
        echo -e "${BLUE}将使用自动检测的节点host进行保活${NC}"
    fi
    
    echo
    echo -e "${GREEN}极速配置完成！正在启动服务...${NC}"
    echo
    
else
    echo -e "${BLUE}=== 完整配置模式 ===${NC}"
    echo
    
    echo -e "${YELLOW}当前UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)${NC}"
    read -p "请输入新的 UUID (留空自动生成): " UUID_INPUT
    if [ -z "$UUID_INPUT" ]; then
        UUID_INPUT=$(generate_uuid)
        echo -e "${GREEN}自动生成UUID: $UUID_INPUT${NC}"
    fi
    sed -i "s/UUID = os.environ.get('UUID', '[^']*')/UUID = os.environ.get('UUID', '$UUID_INPUT')/" app.py
    echo -e "${GREEN}UUID 已设置为: $UUID_INPUT${NC}"

    echo -e "${YELLOW}当前节点名称: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)${NC}"
    read -p "请输入节点名称 (留空保持不变): " NAME_INPUT
    if [ -n "$NAME_INPUT" ]; then
        sed -i "s/NAME = os.environ.get('NAME', '[^']*')/NAME = os.environ.get('NAME', '$NAME_INPUT')/" app.py
        echo -e "${GREEN}节点名称已设置为: $NAME_INPUT${NC}"
    fi

    echo -e "${YELLOW}当前服务端口: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)${NC}"
    read -p "请输入服务端口 (留空保持不变): " PORT_INPUT
    if [ -n "$PORT_INPUT" ]; then
        sed -i "s/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or [0-9]*)/PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or $PORT_INPUT)/" app.py
        echo -e "${GREEN}端口已设置为: $PORT_INPUT${NC}"
    fi

    echo -e "${YELLOW}当前优选IP: $(grep "CFIP = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入优选IP/域名 (留空使用默认 joeyblog.net): " CFIP_INPUT
    if [ -z "$CFIP_INPUT" ]; then
        CFIP_INPUT="joeyblog.net"
    fi
    sed -i "s/CFIP = os.environ.get('CFIP', '[^']*')/CFIP = os.environ.get('CFIP', '$CFIP_INPUT')/" app.py
    echo -e "${GREEN}优选IP已设置为: $CFIP_INPUT${NC}"

    echo -e "${YELLOW}当前优选端口: $(grep "CFPORT = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入优选端口 (留空保持不变): " CFPORT_INPUT
    if [ -n "$CFPORT_INPUT" ]; then
        sed -i "s/CFPORT = int(os.environ.get('CFPORT', '[^']*'))/CFPORT = int(os.environ.get('CFPORT', '$CFPORT_INPUT'))/" app.py
        echo -e "${GREEN}优选端口已设置为: $CFPORT_INPUT${NC}"
    fi

    echo -e "${YELLOW}当前Argo端口: $(grep "ARGO_PORT = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入 Argo 端口 (留空保持不变): " ARGO_PORT_INPUT
    if [ -n "$ARGO_PORT_INPUT" ]; then
        sed -i "s/ARGO_PORT = int(os.environ.get('ARGO_PORT', '[^']*'))/ARGO_PORT = int(os.environ.get('ARGO_PORT', '$ARGO_PORT_INPUT'))/" app.py
        echo -e "${GREEN}Argo端口已设置为: $ARGO_PORT_INPUT${NC}"
    fi

    echo -e "${YELLOW}当前订阅路径: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)${NC}"
    read -p "请输入订阅路径 (留空保持不变): " SUB_PATH_INPUT
    if [ -n "$SUB_PATH_INPUT" ]; then
        sed -i "s/SUB_PATH = os.environ.get('SUB_PATH', '[^']*')/SUB_PATH = os.environ.get('SUB_PATH', '$SUB_PATH_INPUT')/" app.py
        echo -e "${GREEN}订阅路径已设置为: $SUB_PATH_INPUT${NC}"
    fi

    echo
    echo -e "${YELLOW}是否配置高级选项? (y/n)${NC}"
    read -p "> " ADVANCED_CONFIG

    if [ "$ADVANCED_CONFIG" = "y" ] || [ "$ADVANCED_CONFIG" = "Y" ]; then
        echo -e "${YELLOW}当前上传URL: $(grep "UPLOAD_URL = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入上传URL (留空保持不变): " UPLOAD_URL_INPUT
        if [ -n "$UPLOAD_URL_INPUT" ]; then
            sed -i "s|UPLOAD_URL = os.environ.get('UPLOAD_URL', '[^']*')|UPLOAD_URL = os.environ.get('UPLOAD_URL', '$UPLOAD_URL_INPUT')|" app.py
            echo -e "${GREEN}上传URL已设置${NC}"
        fi

        echo -e "${YELLOW}当前项目URL: $(grep "PROJECT_URL = " app.py | cut -d"'" -f4)${NC}"
        read -p "请输入项目URL (留空保持不变): " PROJECT_URL_INPUT
        if [ -n "$PROJECT_URL_INPUT" ]; then
            sed -i "s|PROJECT_URL = os.environ.get('PROJECT_URL', '[^']*')|PROJECT_URL = os.environ.get('PROJECT_URL', '$PROJECT_URL_INPUT')|" app.py
            echo -e "${GREEN}项目URL已设置${NC}"
        fi

        echo -e "${YELLOW}注意: 自动保活功能已移至脚本管理，请使用选项4进行配置${NC}"

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
    
    echo -e "${GREEN}YouTube分流已自动配置${NC}"

    # 询问是否自定义保活URL
    echo
    echo -e "${YELLOW}是否自定义保活URL? (y/n，默认n使用自动检测)${NC}"
    read -p "> " CUSTOM_KEEPALIVE_CHOICE
    
    if [ "$CUSTOM_KEEPALIVE_CHOICE" = "y" ] || [ "$CUSTOM_KEEPALIVE_CHOICE" = "Y" ]; then
        echo -e "${BLUE}请输入自定义保活URL (例如: https://example.com 或 example.com)${NC}"
        read -p "> " CUSTOM_KEEPALIVE_URL
        
        if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
            # 创建保活配置文件
            mkdir -p "$HOME"
            cat > "$HOME/.xray_keepalive_config" << EOF
# Xray节点保活配置
CUSTOM_KEEPALIVE_URL="$CUSTOM_KEEPALIVE_URL"
EOF
            echo -e "${GREEN}自定义保活URL已设置: $CUSTOM_KEEPALIVE_URL${NC}"
        else
            echo -e "${YELLOW}未输入URL，将使用自动检测的节点host${NC}"
        fi
    else
        echo -e "${BLUE}将使用自动检测的节点host进行保活${NC}"
    fi

    echo
    echo -e "${GREEN}完整配置完成！${NC}"
fi

echo -e "${YELLOW}=== 当前配置摘要 ===${NC}"
echo -e "UUID: $(grep "UUID = " app.py | head -1 | cut -d"'" -f2)"
echo -e "节点名称: $(grep "NAME = " app.py | head -1 | cut -d"'" -f4)"
echo -e "服务端口: $(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)"
echo -e "优选IP: $(grep "CFIP = " app.py | cut -d"'" -f4)"
echo -e "优选端口: $(grep "CFPORT = " app.py | cut -d"'" -f4)"
echo -e "订阅路径: $(grep "SUB_PATH = " app.py | cut -d"'" -f4)"
echo -e "${YELLOW}========================${NC}"
echo

echo -e "${BLUE}正在启动服务...${NC}"
echo -e "${YELLOW}当前工作目录：$(pwd)${NC}"
echo

# 修改Python文件添加YouTube分流到xray配置，并增加80端口节点
echo -e "${BLUE}正在添加YouTube分流功能和80端口节点...${NC}"
cat > youtube_patch.py << 'EOF'
# 读取app.py文件
with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 找到原始配置并替换为包含YouTube分流的配置
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

python3 youtube_patch.py
rm youtube_patch.py

echo -e "${GREEN}YouTube分流和80端口节点已集成${NC}"

# 先清理可能存在的进程
pkill -f "python3 app.py" > /dev/null 2>&1
sleep 2

# 启动服务并获取PID
python3 app.py > app.log 2>&1 &
APP_PID=$!

# 验证PID获取成功
if [ -z "$APP_PID" ] || [ "$APP_PID" -eq 0 ]; then
    echo -e "${RED}获取进程PID失败，尝试直接启动${NC}"
    nohup python3 app.py > app.log 2>&1 &
    sleep 2
    APP_PID=$(pgrep -f "python3 app.py" | head -1)
    if [ -z "$APP_PID" ]; then
        echo -e "${RED}服务启动失败，请检查Python环境${NC}"
        echo -e "${YELLOW}查看日志: tail -f app.log${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}服务已在后台启动，PID: $APP_PID${NC}"
echo -e "${YELLOW}日志文件: $(pwd)/app.log${NC}"

echo -e "${BLUE}等待服务启动...${NC}"
sleep 8

# 检查服务是否正常运行
if ! ps -p "$APP_PID" > /dev/null 2>&1; then
    echo -e "${RED}服务启动失败，请检查日志${NC}"
    echo -e "${YELLOW}查看日志: tail -f app.log${NC}"
    echo -e "${YELLOW}检查端口占用: netstat -tlnp | grep :3000${NC}"
    exit 1
fi

echo -e "${GREEN}服务运行正常${NC}"

SERVICE_PORT=$(grep "PORT = int" app.py | grep -o "or [0-9]*" | cut -d" " -f2)
CURRENT_UUID=$(grep "UUID = " app.py | head -1 | cut -d"'" -f2)
SUB_PATH_VALUE=$(grep "SUB_PATH = " app.py | cut -d"'" -f4)

echo -e "${BLUE}等待节点信息生成...${NC}"
echo -e "${YELLOW}正在等待Argo隧道建立和节点生成，请耐心等待...${NC}"

# 循环等待节点信息生成，最多等待10分钟
MAX_WAIT=600  # 10分钟
WAIT_COUNT=0
NODE_INFO=""

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if [ -f ".cache/sub.txt" ]; then
        NODE_INFO=$(cat .cache/sub.txt 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}节点信息已生成！${NC}"
            break
        fi
    elif [ -f "sub.txt" ]; then
        NODE_INFO=$(cat sub.txt 2>/dev/null)
        if [ -n "$NODE_INFO" ]; then
            echo -e "${GREEN}节点信息已生成！${NC}"
            break
        fi
    fi
    
    # 每30秒显示一次等待提示
    if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
        MINUTES=$((WAIT_COUNT / 60))
        SECONDS=$((WAIT_COUNT % 60))
        echo -e "${YELLOW}已等待 ${MINUTES}分${SECONDS}秒，继续等待节点生成...${NC}"
        echo -e "${BLUE}提示: Argo隧道建立需要时间，请继续等待${NC}"
    fi
    
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 5))
done

# 检查是否成功获取到节点信息
if [ -z "$NODE_INFO" ]; then
    echo -e "${RED}等待超时！节点信息未能在10分钟内生成${NC}"
    echo -e "${YELLOW}可能原因：${NC}"
    echo -e "1. 网络连接问题"
    echo -e "2. Argo隧道建立失败"
    echo -e "3. 服务配置错误"
    echo
    echo -e "${BLUE}建议操作：${NC}"
    echo -e "1. 查看日志: ${YELLOW}tail -f $(pwd)/app.log${NC}"
    echo -e "2. 检查服务: ${YELLOW}ps aux | grep python3${NC}"
    echo -e "3. 重新运行脚本"
    echo
    echo -e "${YELLOW}服务信息：${NC}"
    echo -e "进程PID: ${BLUE}$APP_PID${NC}"
    echo -e "服务端口: ${BLUE}$SERVICE_PORT${NC}"
    echo -e "日志文件: ${YELLOW}$(pwd)/app.log${NC}"
    exit 1
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}           部署完成！                   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo

echo -e "${YELLOW}=== 服务信息 ===${NC}"
echo -e "服务状态: ${GREEN}运行中${NC}"
echo -e "进程PID: ${BLUE}$APP_PID${NC}"
echo -e "服务端口: ${BLUE}$SERVICE_PORT${NC}"
echo -e "UUID: ${BLUE}$CURRENT_UUID${NC}"
echo -e "订阅路径: ${BLUE}/$SUB_PATH_VALUE${NC}"
echo

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

echo -e "${YELLOW}=== 节点信息 ===${NC}"
DECODED_NODES=$(echo "$NODE_INFO" | base64 -d 2>/dev/null || echo "$NODE_INFO")

echo -e "${GREEN}节点配置:${NC}"
echo "$DECODED_NODES"
echo

echo -e "${GREEN}订阅链接:${NC}"
echo "$NODE_INFO"
echo

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

=== 分流说明 ===
- 已集成YouTube分流优化到xray配置
- YouTube相关域名自动走专用线路
- 无需额外配置，透明分流"

echo "$SAVE_INFO" > "$NODE_INFO_FILE"
echo -e "${GREEN}节点信息已保存到 $NODE_INFO_FILE${NC}"
echo -e "${YELLOW}使用脚本选择选项3可随时查看节点信息${NC}"

echo -e "${YELLOW}=== 重要提示 ===${NC}"
echo -e "${GREEN}部署已完成，节点信息已成功生成${NC}"
echo -e "${GREEN}可以立即使用订阅地址添加到客户端${NC}"
echo -e "${GREEN}YouTube分流已集成到xray配置，无需额外设置${NC}"
echo -e "${GREEN}服务将持续在后台运行${NC}"
echo

echo -e "${YELLOW}=== 保活功能说明 ===${NC}"
echo -e "${GREEN}新增智能保活功能，支持自定义URL和自动检测${NC}"
echo -e "${BLUE}使用方法:${NC}"
echo -e "  1. 运行脚本选择选项4查看保活状态"
echo -e "  2. 选择选项5查看实时日志"
echo -e "  3. 保活功能自动启动，无需手动配置"
echo -e "  4. 优先使用自定义URL，否则自动检测节点host"
echo -e "  5. 每2分钟执行一次HTTP/HTTPS请求"
echo -e "  6. 显示HTTP状态码，支持日志记录和状态监控"
echo

echo -e "${GREEN}部署完成！感谢使用！${NC}"

# 自动启动保活服务
echo -e "${BLUE}正在启动保活服务...${NC}"
if [ -f "$HOME/xray_keepalive.sh" ]; then
    # 停止可能存在的保活进程
    pkill -f "xray_keepalive.sh" > /dev/null 2>&1
    sleep 2
    
    # 启动保活服务
    nohup "$HOME/xray_keepalive.sh" > /dev/null 2>&1 &
    KEEPALIVE_PID=$!
    
    if [ -n "$KEEPALIVE_PID" ] && ps -p "$KEEPALIVE_PID" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 保活服务已启动，PID: $KEEPALIVE_PID${NC}"
        echo -e "${BLUE}保活服务将每2分钟自动curl请求节点host${NC}"
    else
        echo -e "${YELLOW}⚠️  保活服务启动失败，请手动检查${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  保活脚本未找到，正在创建...${NC}"
    create_keepalive_script
    
    # 启动保活服务
    nohup "$HOME/xray_keepalive.sh" > /dev/null 2>&1 &
    KEEPALIVE_PID=$!
    
    if [ -n "$KEEPALIVE_PID" ] && ps -p "$KEEPALIVE_PID" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 保活服务已启动，PID: $KEEPALIVE_PID${NC}"
        echo -e "${BLUE}保活服务将每2分钟自动curl请求节点host${NC}"
    else
        echo -e "${YELLOW}⚠️  保活服务启动失败${NC}"
    fi
fi

echo
echo -e "${GREEN}🎉 所有
