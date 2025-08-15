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
main
