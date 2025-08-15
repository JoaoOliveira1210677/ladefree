#!/usr/bin/env python3
import requests
import time
import sys
from datetime import datetime

def log_message(message):
    """打印带时间戳的消息"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"{timestamp} - {message}")

def make_request(url):
    """发起HTTP请求"""
    try:
        response = requests.get(url, timeout=30)
        status_code = response.status_code
        response_time = response.elapsed.total_seconds()
        
        if status_code == 200:
            log_message(f"✓ 请求成功 | URL: {url} | 状态码: {status_code} | 响应时间: {response_time:.2f}s")
        else:
            log_message(f"⚠ 请求异常 | URL: {url} | 状态码: {status_code}")
            
    except Exception as e:
        log_message(f"✗ 请求失败 | URL: {url} | 错误: {str(e)}")

def main():
    # 默认URL，可以通过命令行参数修改
    url = sys.argv[1] if len(sys.argv) > 1 else "https://www.google.com"
    interval = 120  # 2分钟
    
    log_message(f"开始定时请求服务")
    log_message(f"目标URL: {url}")
    log_message(f"请求间隔: {interval}秒")
    log_message(f"按 Ctrl+C 停止服务")
    
    count = 0
    
    try:
        while True:
            count += 1
            log_message(f"--- 第 {count} 次请求 ---")
            
            make_request(url)
            
            log_message(f"等待 {interval} 秒...")
            time.sleep(interval)
            
    except KeyboardInterrupt:
        log_message("服务已停止")

if __name__ == "__main__":
    main()        except Exception as e:
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
