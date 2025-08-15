#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
定时请求脚本
每两分钟请求一次指定的URL，支持后台运行
默认请求谷歌网站
"""

import requests
import time
import sys
import signal
import logging
from datetime import datetime
import argparse
import os

class PeriodicRequester:
    def __init__(self, url="https://www.google.com", interval=120):
        self.url = url
        self.interval = interval  # 间隔时间（秒）
        self.running = True
        self.session = requests.Session()
        
        # 设置请求头，模拟浏览器
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
        
        # 设置日志
        self.setup_logging()
        
    def setup_logging(self):
        """设置日志配置"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('request_log.txt', encoding='utf-8'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def signal_handler(self, signum, frame):
        """处理退出信号"""
        self.logger.info(f"接收到信号 {signum}，准备退出...")
        self.running = False
    
    def make_request(self):
        """发起HTTP请求"""
        try:
            response = self.session.get(self.url, timeout=30)
            status_code = response.status_code
            response_time = response.elapsed.total_seconds()
            
            if status_code == 200:
                self.logger.info(f"✓ 请求成功 | URL: {self.url} | 状态码: {status_code} | 响应时间: {response_time:.2f}s")
            else:
                self.logger.warning(f"⚠ 请求异常 | URL: {self.url} | 状态码: {status_code} | 响应时间: {response_time:.2f}s")
                
        except requests.exceptions.RequestException as e:
            self.logger.error(f"✗ 请求失败 | URL: {self.url} | 错误: {str(e)}")
        except Exception as e:
            self.logger.error(f"✗ 未知错误 | {str(e)}")
    
    def run(self):
        """主运行循环"""
        # 注册信号处理器
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
        
        self.logger.info(f"开始定时请求服务")
        self.logger.info(f"目标URL: {self.url}")
        self.logger.info(f"请求间隔: {self.interval}秒")
        self.logger.info(f"按 Ctrl+C 停止服务")
        
        request_count = 0
        
        while self.running:
            try:
                request_count += 1
                self.logger.info(f"--- 第 {request_count} 次请求 ---")
                
                # 发起请求
                self.make_request()
                
                # 等待指定间隔时间
                if self.running:
                    self.logger.info(f"等待 {self.interval} 秒后进行下次请求...")
                    time.sleep(self.interval)
                    
            except KeyboardInterrupt:
                break
            except Exception as e:
                self.logger.error(f"运行时错误: {str(e)}")
                if self.running:
                    time.sleep(5)  # 出错后等待5秒再继续
        
        self.logger.info("定时请求服务已停止")

def main():
    parser = argparse.ArgumentParser(description='定时HTTP请求脚本')
    parser.add_argument('-u', '--url', 
                       default='https://www.google.com',
                       help='要请求的URL地址 (默认: https://www.google.com)')
    parser.add_argument('-i', '--interval', 
                       type=int, 
                       default=120,
                       help='请求间隔时间（秒） (默认: 120秒)')
    parser.add_argument('-d', '--daemon', 
                       action='store_true',
                       help='后台运行模式')
    
    args = parser.parse_args()
    
    if args.daemon:
        # 后台运行模式
        print(f"启动后台服务，请求URL: {args.url}，间隔: {args.interval}秒")
        print("日志将保存到 request_log.txt 文件")
        
        # 简单的后台运行实现
        pid = os.fork()
        if pid > 0:
            print(f"后台进程已启动，PID: {pid}")
            print(f"可以使用 'kill {pid}' 命令停止服务")
            sys.exit(0)
        
        # 子进程继续执行
        os.setsid()
        
        # 重定向标准输入输出到 /dev/null
        with open('/dev/null', 'r') as f:
            os.dup2(f.fileno(), sys.stdin.fileno())
        with open('/dev/null', 'w') as f:
            os.dup2(f.fileno(), sys.stdout.fileno())
            os.dup2(f.fileno(), sys.stderr.fileno())
    
    # 创建并启动请求器
    requester = PeriodicRequester(args.url, args.interval)
    requester.run()

if __name__ == "__main__":
    main()                      -H "User-Agent: Mozilla/5.0 (Linux; request-script)" \
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
