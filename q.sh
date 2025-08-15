1) 自动保活隧道域名 (推荐)
2) 自定义保活地址
3) 不启用保活
请选择 (1/2/3): 1
将自动保活隧道域名        echo -e "${RED}未找到节点信息文件${NC}"
        echo -e "${YELLOW}请先运行部署脚本生成节点信息${NC}"
    fi
}

# 函数：获取隧道域名
get_tunnel_domain() {
    local tunnel_domain=""
    
    # 方法1: 从节点信息文件获取
    if [ -f "$NODE_INFO_FILE" ]; then
        tunnel_domain=$(grep -o "host=[^&]*" "$NODE_INFO_FILE" | head -1 | cut -d"=" -f2 | sed 's/%2F/\//g')
        if [ -n "$tunnel_domain" ]; then
            echo "$tunnel_domain"
            return 0
        fi
    fi
    
    # 方法2: 从cache目录的文件获取
    if [ -f ".cache/list.txt" ]; then
        tunnel_domain=$(grep -o "host=[^&]*" .cache/list.txt | head -1 | cut -d"=" -f2)
        if [ -n "$tunnel_domain" ]; then
            echo "$tunnel_domain"
            return 0
        fi
    fi
    
    # 方法3: 从当前目录的list.txt获取
    if [ -f "list.txt" ]; then
        tunnel_domain=$(grep -o "host=[^&]*" list.txt | head -1 | cut -d"=" -f2)
        if [ -n "$tunnel_domain" ]; then
            echo "$tunnel_domain"
            return 0
        fi
    fi
    
    # 方法4: 从base64解码的订阅内容获取
    if [ -f ".cache/sub.txt" ]; then
        local sub_content=$(cat .cache/sub.txt | base64 -d 2>/dev/null)
        if [ -n "$sub_content" ]; then
            tunnel_domain=$(echo "$sub_content" | grep -o "host=[^&]*" | head -1 | cut -d"=" -f2)
            if [ -n "$tunnel_domain" ]; then
                echo "$tunnel_domain"
                return 0
            fi
        fi
    fi
    
    return 1
}

# 函数：手动测试保活
test_keepalive() {
    echo -e "${BLUE}正在测试保活...${NC}"
    
    local tunnel_domain=$(get_tunnel_domain)
    
    if [ -z "$tunnel_domain" ]; then
        echo -e "${BLUE}从节点信息文件获取隧道域名...${NC}"
        echo -e "${BLUE}从cache文件获取隧道域名...${NC}"
        echo -e "${BLUE}从list.txt获取隧道域名...${NC}"
        echo -e "${BLUE}从订阅文件解码获取隧道域名...${NC}"
        echo -e "${YELLOW}⚠ 自动获取隧道域名失败${NC}"
        echo -e "${BLUE}请手动输入隧道域名 (格式: xxx.trycloudflare.com):${NC}"
        read -p "> " manual_domain
        if [ -n "$manual_domain" ]; then
            tunnel_domain="$manual_domain"
            echo -e "${GREEN}✓ 使用手动输入的域名: ${YELLOW}$tunnel_domain${NC}"
        fi
    else
        echo -e "${GREEN}✓ 自动获取到隧道域名: ${YELLOW}$tunnel_domain${NC}"
    fi
    
    if [ -n "$tunnel_domain" ]; then
        echo
        echo -e "${BLUE}目标隧道域名: ${YELLOW}$tunnel_domain${NC}"
        echo -e "${BLUE}发送保活请求...${NC}"
        echo
        
        # 发送请求并获取详细信息
        local start_time=$(date +%s)
        local response=$(curl -s -w "\nHTTP状态码: %{http_code}\n总时间: %{time_total}s\n建立连接: %{time_connect}s\nSSL握手: %{time_appconnect}s\n" "https://$tunnel_domain" --max-time 15 2>&1)
        local end_time=$(date +%s)
        
        echo -e "${CYAN}=== 保活测试结果 ===${NC}"
        echo "$response"
        echo
        
        local http_code=$(echo "$response" | grep "HTTP状态码:" | cut -d" " -f2)
        local total_time=$(echo "$response" | grep "总时间:" | cut -d" " -f2)
        
        echo -e "${BLUE}测试时间: ${YELLOW}$(date)${NC}"
        echo -e "${BLUE}请求耗时: ${YELLOW}$((end_time - start_time))秒${NC}"
        
        if [ "$http_code" = "200" ]; then
            echo -e "${GREEN}✓ 保活测试成功 - 隧道正常响应${NC}"
        elif [ "$http_code" = "404" ] || [ "$http_code" = "400" ]; then
            echo -e "${GREEN}✓ 保活测试成功 - 隧道连接正常 (预期的错误码)${NC}"
        elif [ "$http_code" = "000" ] || [ -z "$http_code" ]; then
            echo -e "${RED}✗ 保活测试失败 - 连接超时或网络错误${NC}"
        else
            echo -e "${YELLOW}⚠ 保活测试部分成功 - 状态码: $http_code${NC}"
        fi
        
        # 记录到保活日志
        if [ -n "$http_code" ] && [ "$http_code" != "000" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 手动测试: 保活请求 https://$tunnel_domain" >> "$KEEPALIVE_LOG_FILE"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 手动测试: 保活成功 - 状态码 $http_code, 响应时间 ${total_time}s" >> "$KEEPALIVE_LOG_FILE"
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
}

# 函数：查看保活状态
show_keepalive_status() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           保活状态监控               ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    # 检查Python进程是否运行
    local python_pid=$(pgrep -f "python3 app.py" | head -1)
    if [ -n "$python_pid" ]; then
        echo -e "${GREEN}✓ 服务状态: 运行中 (PID: $python_pid)${NC}"
        
        # 检查工作目录
        if [ -d "python-xray-argo" ]; then
            cd python-xray-argo
            echo -e "${GREEN}✓ 工作目录: $(pwd)${NC}"
        else
            echo -e "${YELLOW}⚠ 工作目录不存在，尝试查找...${NC}"
            local work_dir=$(find $HOME -name "app.py" -path "*/python-xray-argo/*" -exec dirname {} \; 2>/dev/null | head -1)
            if [ -n "$work_dir" ]; then
                cd "$work_dir"
                echo -e "${GREEN}✓ 找到工作目录: $(pwd)${NC}"
            else
                echo -e "${RED}✗ 未找到工作目录${NC}"
                return 1
            fi
        fi
        
        # 检查配置文件
        if [ -f "app.py" ]; then
            local auto_access=$(grep "AUTO_ACCESS = " app.py | grep -o "'[^']*'" | tail -1 | tr -d "'")
            local project_url=$(grep "PROJECT_URL = " app.py | cut -d"'" -f4)
            local uuid=$(grep "UUID = " app.py | head -1 | cut -d"'" -f2)
            
            echo -e "${BLUE}当前配置:${NC}"
            echo -e "  自动保活: ${YELLOW}${auto_access:-未设置}${NC}"
            echo -e "  保活URL: ${YELLOW}${project_url:-未设置}${NC}"
            echo -e "  UUID: ${YELLOW}${uuid}${NC}"
            echo
            
            if [ "$auto_access" = "true" ]; then
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
                    local log_lines=$(wc -l < "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
                    if [ "$log_lines" -gt 1 ]; then
                        echo -e "${BLUE}最近保活记录:${NC}"
                        tail -10 "$KEEPALIVE_LOG_FILE"
                        echo
                        
                        # 统计保活成功率
                        local total_requests=$(grep -c "保活请求" "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
                        local success_requests=$(grep -c "保活成功" "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
                        local failed_requests=$(grep -c "保活失败" "$KEEPALIVE_LOG_FILE" 2>/dev/null || echo "0")
                        
                        if [ "$total_requests" -gt 0 ]; then
                            local success_rate=$((success_requests * 100 / total_requests))
                            echo -e "${CYAN}保活统计:${NC}"
                            echo -e "  总请求: ${YELLOW}$total_requests${NC}"
                            echo -e "  成功: ${GREEN}$success_requests${NC}"
                            echo -e "  失败: ${RED}$failed_requests${NC}"
                            echo -e "  成功率: ${YELLOW}$success_rate%${NC}"
                            echo
                        fi
                        
                        # 显示最后一次保活时间
                        local last_keepalive=$(tail -1 "$KEEPALIVE_LOG_FILE" 2>/dev/null | grep -o "^[0-9-]* [0-9:]*")
                        if [ -n "$last_keepalive" ]; then
                            echo -e "${BLUE}最后保活时间: ${YELLOW}$last_keepalive${NC}"
                        fi
                    else
                        echo -e "${YELLOW}⚠ 暂无保活记录${NC}"
                    fi
                fi
                
                # 手动测试保活
                echo
                echo -e "${YELLOW}是否手动测试保活功能? (y/n)${NC}"
                read -p "> " test_keepalive_choice
                if [ "$test_keepalive_choice" = "y" ] || [ "$test_keepalive_choice" = "Y" ]; then
                    test_keepalive
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
        read -p "> " view_log_choice
        if [ "$view_log_choice" = "y" ] || [ "$view_log_choice" = "Y" ]; then
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
}

# 函数：查看实时日志
show_real_time_logs() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}           实时日志查看               ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    # 查找工作目录
    if [ -d "python-xray-argo" ]; then
        cd python-xray-argo
    else
        local work_dir=$(find $HOME -name "app.py" -path "*/python-xray-argo/*" -exec dirname {} \; 2>/dev/null | head -1)
        if [ -n "$work_dir" ]; then
            cd "$work_dir"
        else
            echo -e "${RED}未找到工作目录${NC}"
            return 1
        fi
    fi
    
    if [ -f "app.log" ]; then
        echo -e "${BLUE}实时日志 (按Ctrl+C退出):${NC}"
        echo
        tail -f app.log
    else
        echo -e "${RED}日志文件不存在${NC}"
    fi
}

# 参数处理
case "$1" in
    "-v")
        show_node_info
        exit 0
        ;;
    "-s")
        show_keepalive_status
        exit 0
        ;;
    "-l")
        show_real_time_logs
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
        show_node_info
        echo -e "${YELLOW}提示: 如需重新部署，请重新运行脚本选择模式1或2${NC}"
        exit 0
        ;;
    "4")
        show_keepalive_status
        exit 0
        ;;
    "5")
        show_real_time_logs
        exit 0
        ;;
    "1"|"2")
        # 继续执行部署流程
        ;;
    *)
        echo -e "${RED}无效选择，退出脚本${NC}"
        exit 1
        ;;
esac

# 检查并安装依赖
echo -e "${BLUE}检查并安装依赖...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python3...${NC}"
    sudo apt-get update && sudo apt-get install -y python3 python3-pip
fi

if ! python3 -c "import requests" &> /dev/null; then
    echo -e "${YELLOW}正在安装 Python 依赖...${NC}"
    pip3 install requests
fi

# 下载项目
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

# 配置模式处理
if [ "$MODE_CHOICE" = "1" ]; then
    # 极速模式
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
    
    case "$KEEPALIVE_CHOICE" in
        "1")
            sed -i "s/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', '[^']*')/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', 'true')/" app.py
            echo -e "${GREEN}将自动保活隧道域名${NC}"
            ;;
        "2")
            read -p "请输入自定义保活地址: " CUSTOM_KEEPALIVE_URL
            if [ -n "$CUSTOM_KEEPALIVE_URL" ]; then
                sed -i "s/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', '[^']*')/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', 'true')/" app.py
                sed -i "s|PROJECT_URL = os.environ.get('PROJECT_URL', '[^']*')|PROJECT_URL = os.environ.get('PROJECT_URL', '$CUSTOM_KEEPALIVE_URL')|" app.py
                echo -e "${GREEN}自定义保活地址已设置为: $CUSTOM_KEEPALIVE_URL${NC}"
            else
                echo -e "${YELLOW}未输入地址，保活已禁用${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}保活已禁用${NC}"
            ;;
    esac
    
    echo
    echo -e "${GREEN}极速配置完成！正在启动服务...${NC}"
    echo

elif [ "$MODE_CHOICE" = "2" ]; then
    # 完整模式
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

    # 端口配置
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

    # 高级选项
    echo
    echo -e "${YELLOW}是否配置高级选项? (y/n)${NC}"
    read -p "> " ADVANCED_CONFIG

    if [ "$ADVANCED_CONFIG" = "y" ] || [ "$ADVANCED_CONFIG" = "Y" ]; then
        # 保活配置
        echo -e "${YELLOW}当前自动保活状态: $(grep "AUTO_ACCESS = " app.py | grep -o "'[^']*'" | tail -1 | tr -d "'")${NC}"
        echo -e "${YELLOW}是否启用自动保活? (y/n)${NC}"
        read -p "> " AUTO_ACCESS_INPUT
        if [ "$AUTO_ACCESS_INPUT" = "y" ] || [ "$AUTO_ACCESS_INPUT" = "Y" ]; then
            sed -i "s/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', '[^']*')/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', 'true')/" app.py
            echo -e "${GREEN}自动保活已启用${NC}"
        else
            sed -i "s/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', '[^']*')/AUTO_ACCESS = os.environ.get('AUTO_ACCESS', 'false')/" app.py
            echo -e "${GREEN}自动保活已禁用${NC}"
        fi
    fi
    
    echo -e "${GREEN}YouTube分流已自动配置${NC}"
    echo
    echo -e "${GREEN}完整配置完成！${NC}"
fi

# 显示配置摘要
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

# 创建补丁脚本
cat > youtube_patch.py << 'EOF'
import re

# 读取app.py文件
with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 添加保活日志功能
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
    # 在cleanup函数前插入日志函数
    if 'def cleanup():' in content:
        content = content.replace('def cleanup():', log_function + 'def cleanup():')
    else:
        # 如果没有cleanup函数，在文件末尾添加
        content += log_function

# 修改xray配置，添加YouTube分流
old_config_pattern = r'config\s*=\s*{[^}]+}'
if re.search(old_config_pattern, content):
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
    content = re.sub(old_config_pattern, new_config, content)

# 修改generate_links函数，添加80端口节点
if 'async def generate_links' in content:
    # 查找并替换generate_links函数
    pattern = r'(async def generate_links\(argo_domain\):.*?)(\n\s*return sub_txt)'
    if re.search(pattern, content, re.DOTALL):
        new_generate_function = '''async def generate_links(argo_domain):
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
        content = re.sub(pattern, new_generate_function + r'\2', content, flags=re.DOTALL)

# 添加增强的保活功能
if 'async def auto_access():' in content:
    enhanced_auto_access = '''async def auto_access():
    """增强的自动保活函数"""
    await asyncio.sleep(60)  # 等待60秒确保隧道建立
    
    while True:
        try:
            # 动态获取隧道域名
            tunnel_domain = None
            
            # 尝试从多个位置获取隧道域名
            for file_path in [os.path.join(FILE_PATH, 'list.txt'), 'list.txt']:
                if os.path.exists(file_path):
                    with open(file_path, 'r') as f:
                        content_data = f.read()
                        # 从vless链接中提取host参数
                        import re
                        host_match = re.search(r'host=([^&%]+)', content_data)
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
        
        await asyncio.sleep(1800)  # 30分钟间隔'''
    
    # 替换原有的auto_access函数
    pattern = r'async def auto_access\(\):.*?(?=\nasync def|\ndef |\nclass |\nif __name__|\Z)'
    content = re.sub(pattern, enhanced_auto_access, content, flags=re.DOTALL)

# 写回文件
with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("YouTube分流配置、80端口节点和增强保活日志功能已成功添加")
EOF

# 运行补丁
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

# 获取配置信息
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

# 部署完成显示
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

# 保存节点信息
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

# 脚本结束
exit 0
