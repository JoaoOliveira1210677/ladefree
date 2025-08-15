#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

NODE_INFO_FILE="$HOME/.xray_nodes_info"
KEEPALIVE_LOG_FILE="$HOME/.xray_keepalive.log"

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

# 如果是-s参数，查看保活状态
if [ "$1" = "-s" ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           保活状态监控               ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    # 检查Python进程是否运行
    PYTHON_PID=$(pgrep -f "python3 app.py" | head -1)
    if [ -n "$PYTHON_PID" ]; then
        echo -e "${GREEN}✓ 服务状态: 运行中 (PID: $PYTHON_PID)${NC}"
        
        # 检查工作目录
        if [ -d "python-xray-argo" ]; then
            cd python-xray-argo
            echo -e "${GREEN}✓ 工作目录: $(pwd)${NC}"
        else
            echo -e "${YELLOW}⚠ 工作目录不存在，尝试查找...${NC}"
            WORK_DIR=$(find $HOME -name "app.py" -path "*/python-xray-argo/*" -exec dirname {} \; 2>/dev/null | head -1)
            if [ -n "$WORK_DIR" ]; then
                cd "$WORK_DIR"
                echo -e "${GREEN}✓ 找到工作目录: $(pwd)${NC}"
            else
                echo -e "${RED}✗ 未找到工作目录${NC}"
                exit 1
            fi
        fi
        
        # 检查配置文件
        if [ -f "app.py" ]; then
            AUTO_ACCESS=$(grep "AUTO_ACCESS = " app.py | grep -o "'[^']*'" | tail -1 | tr -d "'")
            PROJECT_URL=$(grep "PROJECT_URL = " app.py | cut -d"'" -f4)
            UUID=$(grep "UUID = " app.py | head -1 | cut -d"'" -f2)
            
            echo -e "${BLUE}当前配置:${NC}"
            echo -e "  自动保活: ${YELLOW}${AUTO_ACCESS:-未设置}${NC}"
            echo -e "  保活URL: ${YELLOW}${PROJECT_URL:-未设置}${NC}"
            echo -e "  UUID: ${YELLOW}${UUID}${NC}"
            echo
            
            if [ "$AUTO_ACCESS" = "true" ]; then
                echo -e "${GREEN}✓ 保活功能已启用${NC}"
                
                # 确保保活日志文件存在
                if [ ! -f "$KEEPALIVE_LOG_FILE" ]; then
                    touch "$KEEPALIVE_LOG_FILE"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: 保活日志文件初始化" >> "$KEEPALIVE_LOG_FILE"
                    echo -e "${YELLOW}⚠ 保活日志文件不存在，已自动创建${NC}"
                fi
                
                # 检查保活日志
                if [ -f "$KEEPALIVE_LOG_FILE" ]; then
                    echo -e "${BLUE}保活日志位置: ${YELLOW}$KEEPALIVE_LOG_FILE${NC}"
                    
                    # 显示最近的保活记录
                    LOG_LINES=$(wc -l < "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
                    if [ "$LOG_LINES" -gt 1 ]; then
                        echo -e "${BLUE}最近保活记录:${NC}"
                        tail -10 "$KEEPALIVE_LOG_FILE"
                        echo
                        
                        # 统计保活成功率
                        TOTAL_REQUESTS=$(grep -c "保活请求" "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
                        SUCCESS_REQUESTS=$(grep -c "保活成功" "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
                        FAILED_REQUESTS=$(grep -c "保活失败" "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
                        
                        if [ "$TOTAL_REQUESTS" -gt 0 ]; then
                            SUCCESS_RATE=$((SUCCESS_REQUESTS * 100 / TOTAL_REQUESTS))
                            echo -e "${CYAN}保活统计:${NC}"
                            echo -e "  总请求: ${YELLOW}$TOTAL_REQUESTS${NC}"
                            echo -e "  成功: ${GREEN}$SUCCESS_REQUESTS${NC}"
                            echo -e "  失败: ${RED}$FAILED_REQUESTS${NC}"
                            echo -e "  成功率: ${YELLOW}$SUCCESS_RATE%${NC}"
                            echo
                        fi
                        
                        # 显示最后一次保活时间
                        LAST_KEEPALIVE=$(tail -1 "$KEEPALIVE_LOG_FILE" 2>/dev/null | grep -o "^[0-9-]* [0-9:]*")
                        if [ -n "$LAST_KEEPALIVE" ]; then
                            echo -e "${BLUE}最后保活时间: ${YELLOW}$LAST_KEEPALIVE${NC}"
                        fi
                    else
                        echo -e "${YELLOW}⚠ 暂无保活记录${NC}"
                    fi
                
                # 手动测试保活
                echo
                echo -e "${YELLOW}是否手动测试保活功能? (y/n)${NC}"
                read -p "> " TEST_KEEPALIVE
                if [ "$TEST_KEEPALIVE" = "y" ] || [ "$TEST_KEEPALIVE" = "Y" ]; then
                    echo -e "${BLUE}正在测试保活...${NC}"
                    
                    # 多种方式获取隧道域名
                    TUNNEL_DOMAIN=""
                    
                    # 方法1: 从节点信息文件获取
                    if [ -f "$NODE_INFO_FILE" ]; then
                        echo -e "${BLUE}从节点信息文件获取隧道域名...${NC}"
                        # 从vless链接中提取host参数
                        TUNNEL_DOMAIN=$(grep -o "host=[^&]*" "$NODE_INFO_FILE" | head -1 | cut -d"=" -f2 | sed 's/%2F/\//g')
                        if [ -n "$TUNNEL_DOMAIN" ]; then
                            echo -e "${GREEN}✓ 从节点信息获取到域名: ${YELLOW}$TUNNEL_DOMAIN${NC}"
                        fi
                    fi
                    
                    # 方法2: 从cache目录的文件获取
                    if [ -z "$TUNNEL_DOMAIN" ] && [ -f ".cache/list.txt" ]; then
                        echo -e "${BLUE}从cache文件获取隧道域名...${NC}"
                        # 从节点链接中提取host参数
                        TUNNEL_DOMAIN=$(grep -o "host=[^&]*" .cache/list.txt | head -1 | cut -d"=" -f2)
                        if [ -n "$TUNNEL_DOMAIN" ]; then
                            echo -e "${GREEN}✓ 从cache文件获取到域名: ${YELLOW}$TUNNEL_DOMAIN${NC}"
                        fi
                    fi
                    
                    # 方法3: 从当前目录的list.txt获取
                    if [ -z "$TUNNEL_DOMAIN" ] && [ -f "list.txt" ]; then
                        echo -e "${BLUE}从list.txt获取隧道域名...${NC}"
                        TUNNEL_DOMAIN=$(grep -o "host=[^&]*" list.txt | head -1 | cut -d"=" -f2)
                        if [ -n "$TUNNEL_DOMAIN" ]; then
                            echo -e "${GREEN}✓ 从list.txt获取到域名: ${YELLOW}$TUNNEL_DOMAIN${NC}"
                        fi
                    fi
                    
                    # 方法4: 从base64解码的订阅内容获取
                    if [ -z "$TUNNEL_DOMAIN" ] && [ -f ".cache/sub.txt" ]; then
                        echo -e "${BLUE}从订阅文件解码获取隧道域名...${NC}"
                        SUB_CONTENT=$(cat .cache/sub.txt | base64 -d 2>/dev/null)
                        if [ -n "$SUB_CONTENT" ]; then
                            TUNNEL_DOMAIN=$(echo "$SUB_CONTENT" | grep -o "host=[^&]*" | head -1 | cut -d"=" -f2)
                            if [ -n "$TUNNEL_DOMAIN" ]; then
                                echo -e "${GREEN}✓ 从订阅内容获取到域名: ${YELLOW}$TUNNEL_DOMAIN${NC}"
                            fi
                        fi
                    fi
                    
                    # 方法5: 手动输入
                    if [ -z "$TUNNEL_DOMAIN" ]; then
                        echo -e "${YELLOW}⚠ 自动获取隧道域名失败${NC}"
                        echo -e "${BLUE}请手动输入隧道域名 (格式: xxx.trycloudflare.com):${NC}"
                        read -p "> " MANUAL_DOMAIN
                        if [ -n "$MANUAL_DOMAIN" ]; then
                            TUNNEL_DOMAIN="$MANUAL_DOMAIN"
                            echo -e "${GREEN}✓ 使用手动输入的域名: ${YELLOW}$TUNNEL_DOMAIN${NC}"
                        fi
                    fi
                    
                    if [ -n "$TUNNEL_DOMAIN" ]; then
                        echo
                        echo -e "${BLUE}目标隧道域名: ${YELLOW}$TUNNEL_DOMAIN${NC}"
                        echo -e "${BLUE}发送保活请求...${NC}"
                        echo
                        
                        # 发送请求并获取详细信息
                        START_TIME=$(date +%s)
                        RESPONSE=$(curl -s -w "\nHTTP状态码: %{http_code}\n总时间: %{time_total}s\n建立连接: %{time_connect}s\nSSL握手: %{time_appconnect}s\n" "https://$TUNNEL_DOMAIN" --max-time 15 2>&1)
                        END_TIME=$(date +%s)
                        
                        echo -e "${CYAN}=== 保活测试结果 ===${NC}"
                        echo "$RESPONSE"
                        echo
                        
                        HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP状态码:" | cut -d" " -f2)
                        TOTAL_TIME=$(echo "$RESPONSE" | grep "总时间:" | cut -d" " -f2)
                        
                        echo -e "${BLUE}测试时间: ${YELLOW}$(date)${NC}"
                        echo -e "${BLUE}请求耗时: ${YELLOW}$((END_TIME - START_TIME))秒${NC}"
                        
                        if [ "$HTTP_CODE" = "200" ]; then
                            echo -e "${GREEN}✓ 保活测试成功 - 隧道正常响应${NC}"
                        elif [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "400" ]; then
                            echo -e "${GREEN}✓ 保活测试成功 - 隧道连接正常 (预期的错误码)${NC}"
                        elif [ "$HTTP_CODE" = "000" ] || [ -z "$HTTP_CODE" ]; then
                            echo -e "${RED}✗ 保活测试失败 - 连接超时或网络错误${NC}"
                        else
                            echo -e "${YELLOW}⚠ 保活测试部分成功 - 状态码: $HTTP_CODE${NC}"
                        fi
                        
                        # 记录到保活日志
                        if [ -n "$HTTP_CODE" ] && [ "$HTTP_CODE" != "000" ]; then
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 手动测试: 保活请求 https://$TUNNEL_DOMAIN" >> "$KEEPALIVE_LOG_FILE"
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 手动测试: 保活成功 - 状态码 $HTTP_CODE, 响应时间 ${TOTAL_TIME}s" >> "$KEEPALIVE_LOG_FILE"
                        else
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 手动测试: 保活失败 - 连接超时或网络错误" >> "$KEEPALIVE_LOG_FILE"
                        fi
                        
                    else
                        echo -e "${RED}✗ 无法获取隧道域名，请检查：${NC}"
                        echo -e "1. 服务是否正常启动"
                        echo -e "2. 节点信息是否已生成"
                        echo -e "3. Argo隧道是否建立成功"
                        echo
                        echo -e "${YELLOW}调试信息：${NC}"
                        echo -e "工作目录: $(pwd)"
                        echo -e "节点信息文件: $([ -f "$NODE_INFO_FILE" ] && echo "存在" || echo "不存在")"
                        echo -e "Cache文件: $([ -f ".cache/list.txt" ] && echo "存在" || echo "不存在")"
                        echo -e "List文件: $([ -f "list.txt" ] && echo "存在" || echo "不存在")"
                    fi
                fi
                
            else
                echo -e "${YELLOW}⚠ 保活功能未启用${NC}"
            fi
        else
            echo -e "${RED}✗ 配置文件不存在${NC}"
        fi
        
        # 实时日志查看选项
        echo
        echo -e "${YELLOW}是否查看实时运行日志? (y/n)${NC}"
        read -p "> " VIEW_LOG
        if [ "$VIEW_LOG" = "y" ] || [ "$VIEW_LOG" = "Y" ]; then
            if [ -f "app.log" ]; then
                echo -e "${BLUE}实时日志 (按Ctrl+C退出):${NC}"
                echo
                tail -f app.log
            else
                echo -e "${RED}日志文件不存在${NC}"
            fi
        fi
        
    else
        echo -e "${RED}✗ 服务未运行${NC}"
        echo -e "${YELLOW}使用脚本重新部署服务${NC}"
    fi
    exit 0
fi

# 如果是-l参数，查看实时日志
if [ "$1" = "-l" ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           实时日志查看               ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    # 查找工作目录
    if [ -d "python-xray-argo" ]; then
        cd python-xray-argo
    else
        WORK_DIR=$(find $HOME -name "app.py" -path "*/python-xray-argo/*" -exec dirname {} \; 2>/dev/null | head -1)
        if [ -n "$WORK_DIR" ]; then
            cd "$WORK_DIR"
        else
            echo -e "${RED}未找到工作目录${NC}"
            exit 1
        fi
    fi
    
    if [ -f "app.log" ]; then
        echo -e "${BLUE}实时日志 (按Ctrl+C退出):${NC}"
        echo
        tail -f app.log
    else
        echo -e "${RED}日志文件不存在${NC}"
    fi
    exit 0
fi

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
fi

if [ "$MODE_CHOICE" = "4" ]; then
    # 调用保活状态检查
    bash "$0" -s
    exit 0
fi

if [ "$MODE_CHOICE" = "5" ]; then
    # 调用实时日志查看
    bash "$0" -l
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
    
    echo
    echo -e "${YELLOW}保活配置 (每30分钟请求一次保持隧道活跃):${NC}"
    echo -e "${BLUE}1) 自动保活隧道域名 (推荐)${NC}"
    echo -e "${BLUE}2) 自定义保活地址${NC}"
    echo -e "${BLUE}3) 不启用保活${NC}"
    read -p "请选择 (1/2/3): " KEEPALIVE_CHOICE
    
    if [ "$KEEPALIVE_CHOICE" = "1" ]; then
        sed -i "s/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', '[^']*')/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', 'true')/" app.py
        echo -e "${GREEN}将自动保活隧道域名${NC}"
        ENABLE_TUNNEL_KEEPALIVE=true
    elif [ "$KEEPALIVE_CHOICE" = "2" ]; then
        read -p "请输入自定义保活地址: " CUSTOM_KEEPALIVE_URL
        if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
            sed -i "s/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', '[^']*')/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', 'true')/" app.py
            sed -i "s|PROJECT_URL = os.environ.get('PROJECT_URL', '[^']*')|PROJECT_URL = os.environ.get('PROJECT_URL', '$CUSTOM_KEEPALIVE_URL')|" app.py
            echo -e "${GREEN}自定义保活地址已设置为: $CUSTOM_KEEPALIVE_URL${NC}"
            ENABLE_TUNNEL_KEEPALIVE=false
        else
            echo -e "${YELLOW}未输入地址，保活已禁用${NC}"
            ENABLE_TUNNEL_KEEPALIVE=false
        fi
    else
        echo -e "${YELLOW}保活已禁用${NC}"
        ENABLE_TUNNEL_KEEPALIVE=false
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

        echo -e "${YELLOW}当前自动保活状态: $(grep "AUTO_ACCESS = " app.py | grep -o "'[^']*'" | tail -1 | tr -d "'")${NC}"
        echo -e "${YELLOW}是否启用自动保活? (y/n)${NC}"
        read -p "> " AUTO_ACCESS_INPUT
        if [ "$AUTO_ACCESS_INPUT" = "y" ] || [ "$AUTO_ACCESS_INPUT" = "Y" ]; then
            sed -i "s/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', '[^']*')/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', 'true')/" app.py
            
            echo -e "${YELLOW}请选择保活方式:${NC}"
            echo -e "${BLUE}1) 自动保活隧道域名 (推荐)${NC}"
            echo -e "${BLUE}2) 自定义保活地址${NC}"
            read -p "请选择 (1/2): " KEEPALIVE_TYPE
            
            if [ "$KEEPALIVE_TYPE" = "2" ]; then
                read -p "请输入自定义保活地址: " CUSTOM_KEEPALIVE_URL
                if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
                    sed -i "s|PROJECT_URL = os.environ.get('PROJECT_URL', '[^']*')|PROJECT_URL = os.environ.get('PROJECT_URL', '$CUSTOM_KEEPALIVE_URL')|" app.py
                    echo -e "${GREEN}自定义保活地址已设置为: $CUSTOM_KEEPALIVE_URL${NC}"
                    ENABLE_TUNNEL_KEEPALIVE=false
                fi
            else
                echo -e "${GREEN}将自动保活隧道域名${NC}"
                ENABLE_TUNNEL_KEEPALIVE=true
            fi
            
            echo -e "${GREEN}自动保活已启用${NC}"
        elif [ "$AUTO_ACCESS_INPUT" = "n" ] || [ "$AUTO_ACCESS_INPUT" = "N" ]; then
            sed -i "s/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', '[^']*')/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', 'false')/" app.py
            echo -e "${GREEN}自动保活已禁用${NC}"
            ENABLE_TUNNEL_KEEPALIVE=false
        else
            ENABLE_TUNNEL_KEEPALIVE=false
        fi

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

# 添加保活日志记录功能
keepalive_patch = '''
import datetime

# 原始的保活函数修改
def log_keepalive(message, status="INFO"):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_message = f"[{timestamp}] {status}: {message}\\n"
    keepalive_log_file = os.path.expanduser("~/.xray_keepalive.log")
    try:
        with open(keepalive_log_file, "a", encoding="utf-8") as f:
            f.write(log_message)
    except Exception as e:
        print(f"写入保活日志失败: {e}")

# 查找并修改保活请求部分
'''

# 在文件中添加保活日志功能
if 'import datetime' not in content:
    content = content.replace('import asyncio', 'import asyncio\nimport datetime')

# 添加保活日志函数
if 'def log_keepalive' not in content:
    log_function = '''
def log_keepalive(message, status="INFO"):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_message = f"[{timestamp}] {status}: {message}\\n"
    keepalive_log_file = os.path.expanduser("~/.xray_keepalive.log")
    try:
        with open(keepalive_log_file, "a", encoding="utf-8") as f:
            f.write(log_message)
    except Exception as e:
        print(f"写入保活日志失败: {e}")

'''
    # 在适当位置插入日志函数
    content = content.replace('def cleanup():', log_function + 'def cleanup():')

# 修改保活请求部分添加日志记录
if 'requests.get(project_url' in content:
    old_keepalive = 'response = requests.get(project_url, timeout=60)'
    new_keepalive = '''log_keepalive(f"保活请求: {project_url}")
                    try:
                        response = requests.get(project_url, timeout=60)
                        if response.status_code in [200, 404, 400]:
                            log_keepalive(f"保活成功: 状态码 {response.status_code}, 响应时间 {response.elapsed.total_seconds():.2f}s")
                        else:
                            log_keepalive(f"保活异常: 状态码 {response.status_code}", "WARN")
                    except requests.exceptions.Timeout:
                        log_keepalive("保活失败: 请求超时", "ERROR")
                    except requests.exceptions.ConnectionError:
                        log_keepalive("保活失败: 连接错误", "ERROR")
                    except Exception as e:
                        log_keepalive(f"保活失败: {str(e)}", "ERROR")'''
    content = content.replace(old_keepalive, new_keepalive)

# 修改自动保活部分，确保能正确获取隧道域名
if 'argo_domain' in content and 'project_url' in content:
    # 查找自动保活逻辑并改进域名获取
    auto_access_pattern = '''if AUTO_ACCESS == 'true':'''
    if auto_access_pattern in content:
        old_auto_access = '''if AUTO_ACCESS == 'true':
            asyncio.create_task(auto_access())'''
        new_auto_access = '''if AUTO_ACCESS == 'true':
            # 等待隧道域名生成后再启动保活
            asyncio.create_task(delayed_auto_access())'''
        content = content.replace(old_auto_access, new_auto_access)
        
        # 添加延迟保活函数
        delayed_access_function = '''
async def delayed_auto_access():
    """延迟启动自动保活，等待隧道域名生成"""
    await asyncio.sleep(30)  # 等待30秒确保隧道建立
    await auto_access()

async def auto_access():
    """改进的自动保活函数"""
    while True:
        try:
            # 动态获取隧道域名
            tunnel_domain = None
            
            # 尝试从多个位置获取隧道域名
            for file_path in [os.path.join(FILE_PATH, 'list.txt'), 'list.txt']:
                if os.path.exists(file_path):
                    with open(file_path, 'r') as f:
                        content = f.read()
                        # 从vless链接中提取host参数
                        import re
                        host_match = re.search(r'host=([^&%]+)', content)
                        if host_match:
                            tunnel_domain = host_match.group(1)
                            break
            
            if tunnel_domain:
                access_url = f"https://{tunnel_domain}"
            else:
                access_url = PROJECT_URL
            
            if access_url and access_url != "":
                log_keepalive(f"保活请求: {access_url}")
                try:
                    response = requests.get(access_url, timeout=60)
                    if response.status_code in [200, 404, 400]:
                        log_keepalive(f"保活成功: 状态码 {response.status_code}, 响应时间 {response.elapsed.total_seconds():.2f}s")
                    else:
                        log_keepalive(f"保活异常: 状态码 {response.status_code}", "WARN")
                except requests.exceptions.Timeout:
                    log_keepalive("保活失败: 请求超时", "ERROR")
                except requests.exceptions.ConnectionError:
                    log_keepalive("保活失败: 连接错误", "ERROR")
                except Exception as e:
                    log_keepalive(f"保活失败: {str(e)}", "ERROR")
            else:
                log_keepalive("保活跳过: 未配置URL", "WARN")
                
        except Exception as e:
            log_keepalive(f"保活异常: {str(e)}", "ERROR")
        
        await asyncio.sleep(1800)  # 30分钟间隔

'''
        # 查找并替换原有的auto_access函数
        if 'async def auto_access():' in content:
            # 找到函数开始和结束位置进行替换
            lines = content.split('\n')
            new_lines = []
            in_auto_access = False
            indent_level = 0
            
            i = 0
            while i < len(lines):
                line = lines[i]
                if 'async def auto_access():' in line and not in_auto_access:
                    # 开始替换auto_access函数
                    new_lines.append(delayed_access_function.strip())
                    in_auto_access = True
                    indent_level = len(line) - len(line.lstrip())
                    # 跳过原函数内容直到下一个同级或更高级的定义
                    i += 1
                    while i < len(lines):
                        next_line = lines[i]
                        if next_line.strip() == '':
                            i += 1
                            continue
                        next_indent = len(next_line) - len(next_line.lstrip())
                        if next_indent <= indent_level and (next_line.strip().startswith('def ') or next_line.strip().startswith('class ') or next_line.strip().startswith('async def ') or next_line.strip().startswith('if __name__')):
                            break
                        i += 1
                    in_auto_access = False
                    continue
                else:
                    new_lines.append(line)
                i += 1
            
            content = '\n'.join(new_lines)
        else:
            # 如果没找到原函数，直接添加新函数
            content = content.replace('def cleanup():', delayed_access_function + '\ndef cleanup():')

# 写回文件
with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("YouTube分流配置、80端口节点和增强保活日志功能已成功添加")
EOF

python3 youtube_patch.py
rm youtube_patch.py

echo -e "${GREEN}YouTube分流、80端口节点和保活日志功能已集成${NC}"

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
查看节点: bash $0 -v
保活状态: bash $0 -s
实时日志: bash $0 -l

=== 快捷命令说明 ===
$0 -v     # 查看节点信息
$0 -s     # 查看保活状态和统计
$0 -l     # 查看实时日志

=== 分流说明 ===
- 已集成YouTube分流优化到xray配置
- YouTube相关域名自动走专用线路
- 无需额外配置，透明分流
- 已添加保活日志记录功能

=== 保活监控 ===
- 保活日志: $KEEPALIVE_LOG_FILE
- 支持成功率统计和状态监控
- 可手动测试保活功能"

echo "$SAVE_INFO" > "$NODE_INFO_FILE"
echo -e "${GREEN}节点信息已保存到 $NODE_INFO_FILE${NC}"
echo -e "${YELLOW}使用以下命令可随时查看信息:${NC}"
echo -e "${BLUE}  $0 -v${NC}  # 查看节点信息"
echo -e "${BLUE}  $0 -s${NC}  # 查看保活状态"
echo -e "${BLUE}  $0 -l${NC}  # 查看实时日志"

echo -e "${YELLOW}=== 重要提示 ===${NC}"
echo -e "${GREEN}部署已完成，节点信息已成功生成${NC}"
echo -e "${GREEN}可以立即使用订阅地址添加到客户端${NC}"
echo -e "${GREEN}YouTube分流已集成到xray配置，无需额外设置${NC}"
echo -e "${GREEN}保活日志记录功能已启用，可监控连接状态${NC}"
echo -e "${GREEN}服务将持续在后台运行${NC}"
echo

echo -e "${CYAN}=== 新增功能说明 ===${NC}"
echo -e "${YELLOW}1. 保活状态监控:${NC}"
echo -e "   - 实时查看保活请求状态和响应"
echo -e "   - 统计保活成功率和失败次数"
echo -e "   - 手动测试保活功能"
echo -e "   - 显示最后保活时间"
echo
echo -e "${YELLOW}2. 日志实时统计:${NC}"
echo -e "   - 保活日志自动记录到 $KEEPALIVE_LOG_FILE"
echo -e "   - 包含时间戳、状态码、响应时间等详细信息"
echo -e "   - 支持实时查看运行日志"
echo
echo -e "${YELLOW}3. 增强的管理界面:${NC}"
echo -e "   - 新增选项4: 查看保活状态"
echo -e "   - 新增选项5: 查看实时日志"
echo -e "   - 支持命令行参数快速操作"
echo

echo -e "${GREEN}部署完成！感谢使用增强版脚本！${NC}"

# 退出脚本，避免重复执行
exit 0
