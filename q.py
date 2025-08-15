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
    
    args = parser.parse_args()
    
    # 创建并启动请求器
    requester = PeriodicRequester(args.url, args.interval)
    requester.run()

if __name__ == "__main__":
    main()
