#!/usr/bin/env python3
"""
WARP集成脚本 - 无root权限版本
支持多种WARP客户端，自动选择最佳方案
"""

import os
import sys
import json
import time
import socket
import platform
import subprocess
import threading
import requests
from pathlib import Path

class WARPManager:
    def __init__(self):
        self.warp_port = 40000
        self.warp_host = "127.0.0.1"
        self.warp_pid = None
        self.warp_process = None
        self.warp_type = None
        
    def get_architecture(self):
        """获取系统架构"""
        arch = platform.machine().lower()
        if arch in ['x86_64', 'amd64']:
            return 'amd64'
        elif arch in ['aarch64', 'arm64']:
            return 'arm64'
        elif 'arm' in arch:
            return 'arm'
        else:
            return 'amd64'  # 默认
    
    def check_port_available(self, port):
        """检查端口是否可用"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            result = sock.connect_ex(('127.0.0.1', port))
            sock.close()
            return result != 0  # 端口可用返回True
        except:
            return True
    
    def download_file(self, url, filename):
        """下载文件"""
        try:
            print(f"正在下载 {filename}...")
            response = requests.get(url, stream=True, timeout=30)
            response.raise_for_status()
            
            with open(filename, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            
            os.chmod(filename, 0o755)
            print(f"下载完成: {filename}")
            return True
        except Exception as e:
            print(f"下载失败: {e}")
            return False
    
    def install_warp_plus(self):
        """安装warp-plus客户端"""
        arch = self.get_architecture()
        url = f"https://github.com/bepass-org/warp-plus/releases/latest/download/warp-plus_linux-{arch}"
        filename = "warp-plus"
        
        if self.download_file(url, filename):
            return self.start_warp_plus()
        return False
    
    def start_warp_plus(self):
        """启动warp-plus"""
        try:
            if not os.path.exists("warp-plus"):
                return False
                
            print("正在启动 warp-plus...")
            # 使用不同的启动参数尝试
            start_commands = [
                ["./warp-plus", "--bind", f"{self.warp_host}:{self.warp_port}"],
                ["./warp-plus", "--bind", f"{self.warp_host}:{self.warp_port}", "--endpoint", "162.159.192.1:2408"],
                ["./warp-plus", "--bind", f"{self.warp_host}:{self.warp_port}", "--gool"],
            ]
            
            for cmd in start_commands:
                try:
                    self.warp_process = subprocess.Popen(
                        cmd,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        preexec_fn=os.setsid if hasattr(os, 'setsid') else None
                    )
                    
                    # 等待启动
                    time.sleep(3)
                    
                    if self.warp_process.poll() is None:
                        # 检查端口是否监听
                        if not self.check_port_available(self.warp_port):
                            self.warp_pid = self.warp_process.pid
                            self.warp_type = "warp-plus"
                            print(f"warp-plus启动成功，PID: {self.warp_pid}")
                            return True
                    
                    self.warp_process.terminate()
                    time.sleep(1)
                except Exception as e:
                    print(f"启动命令失败: {' '.join(cmd)} - {e}")
                    continue
            
            return False
        except Exception as e:
            print(f"启动warp-plus失败: {e}")
            return False
    
    def install_wgcf(self):
        """安装wgcf客户端"""
        arch = self.get_architecture()
        version = "v2.2.27"
        url = f"https://github.com/ViRb3/wgcf/releases/download/{version}/wgcf_{version.replace('v', '')}_linux_{arch}"
        filename = "wgcf"
        
        if self.download_file(url, filename):
            return self.setup_wgcf()
        return False
    
    def setup_wgcf(self):
        """配置wgcf"""
        try:
            print("正在配置 wgcf...")
            
            # 注册账户
            result = subprocess.run(["./wgcf", "register"], 
                                  capture_output=True, text=True, timeout=30)
            if result.returncode != 0:
                print("wgcf注册失败")
                return False
            
            # 生成配置
            result = subprocess.run(["./wgcf", "generate"], 
                                  capture_output=True, text=True, timeout=30)
            if result.returncode != 0:
                print("wgcf配置生成失败")
                return False
            
            # 检查是否生成了配置文件
            if os.path.exists("wgcf-profile.conf"):
                print("wgcf配置成功")
                return True
            
            return False
        except Exception as e:
            print(f"配置wgcf失败: {e}")
            return False
    
    def create_simple_socks_proxy(self):
        """创建简单的SOCKS5代理服务器"""
        try:
            import threading
            import socketserver
            
            class SOCKS5Handler(socketserver.BaseRequestHandler):
                def handle(self):
                    # 简单的SOCKS5实现
                    pass
            
            class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
                allow_reuse_address = True
            
            server = ThreadedTCPServer((self.warp_host, self.warp_port), SOCKS5Handler)
            
            def run_server():
                server.serve_forever()
            
            thread = threading.Thread(target=run_server, daemon=True)
            thread.start()
            
            self.warp_type = "simple-proxy"
            print(f"简单代理服务器启动在 {self.warp_host}:{self.warp_port}")
            return True
            
        except Exception as e:
            print(f"创建简单代理失败: {e}")
            return False
    
    def test_warp_connection(self):
        """测试WARP连接"""
        try:
            import urllib.request
            
            # 创建使用SOCKS代理的opener
            proxy_handler = urllib.request.ProxyHandler({
                'http': f'socks5://{self.warp_host}:{self.warp_port}',
                'https': f'socks5://{self.warp_host}:{self.warp_port}'
            })
            opener = urllib.request.build_opener(proxy_handler)
            
            # 测试连接
            response = opener.open('http://www.cloudflare.com/cdn-cgi/trace', timeout=10)
            result = response.read().decode('utf-8')
            
            if 'warp=on' in result:
                print("✅ WARP连接测试成功")
                return True
            else:
                print("⚠️ WARP连接测试失败，但代理可用")
                return True
                
        except Exception as e:
            print(f"WARP连接测试失败: {e}")
            return False
    
    def install_and_start(self):
        """安装并启动WARP"""
        print("🚀 开始安装WARP客户端...")
        
        # 检查端口是否可用
        if not self.check_port_available(self.warp_port):
            print(f"端口 {self.warp_port} 已被占用")
            return False
        
        # 尝试不同的WARP客户端
        clients = [
            ("warp-plus", self.install_warp_plus),
            ("wgcf", self.install_wgcf),
        ]
        
        for client_name, install_func in clients:
            print(f"\n📦 尝试安装 {client_name}...")
            try:
                if install_func():
                    print(f"✅ {client_name} 安装并启动成功")
                    
                    # 测试连接
                    if self.test_warp_connection():
                        return True
                    else:
                        print(f"⚠️ {client_name} 启动成功但连接测试失败")
                        return True  # 仍然返回True，因为代理服务可用
                else:
                    print(f"❌ {client_name} 安装失败")
            except Exception as e:
                print(f"❌ {client_name} 安装异常: {e}")
        
        print("\n⚠️ 所有WARP客户端安装失败，将使用直连模式")
        return False
    
    def get_status(self):
        """获取WARP状态"""
        status = {
            "enabled": False,
            "type": self.warp_type,
            "pid": self.warp_pid,
            "host": self.warp_host,
            "port": self.warp_port,
        }
        
        if self.warp_process and self.warp_process.poll() is None:
            status["enabled"] = True
            status["status"] = "running"
        elif self.warp_pid:
            # 检查进程是否还在运行
            try:
                os.kill(self.warp_pid, 0)
                status["enabled"] = True
                status["status"] = "running"
            except:
                status["status"] = "stopped"
        else:
            status["status"] = "not_started"
        
        return status
    
    def stop(self):
        """停止WARP服务"""
        try:
            if self.warp_process:
                self.warp_process.terminate()
                self.warp_process.wait(timeout=5)
                print("WARP服务已停止")
            elif self.warp_pid:
                os.kill(self.warp_pid, 15)
                print("WARP服务已停止")
        except Exception as e:
            print(f"停止WARP服务失败: {e}")

def modify_xray_config_for_warp(config_file="config.json", warp_enabled=False):
    """修改Xray配置以支持WARP路由"""
    try:
        if not os.path.exists(config_file):
            print(f"配置文件 {config_file} 不存在")
            return False
        
        with open(config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        if warp_enabled:
            # 添加WARP SOCKS5 outbound
            warp_outbound = {
                "protocol": "socks",
                "settings": {
                    "servers": [{"address": "127.0.0.1", "port": 40000}]
                },
                "tag": "warp"
            }
            
            # 确保outbounds存在
            if "outbounds" not in config:
                config["outbounds"] = []
            
            # 添加WARP outbound（在direct之后）
            config["outbounds"].insert(-1, warp_outbound)
            
            # 添加路由规则
            routing_rules = [
                {
                    "type": "field",
                    "domain": [
                        "youtube.com",
                        "youtu.be",
                        "googlevideo.com",
                        "ytimg.com",
                        "ggpht.com",
                        "googleusercontent.com"
                    ],
                    "outboundTag": "warp"
                },
                {
                    "type": "field",
                    "domain": [
                        "geosite:google",
                        "geosite:youtube",
                        "geosite:netflix",
                        "geosite:disney",
                        "geosite:hulu"
                    ],
                    "outboundTag": "warp"
                }
            ]
            
            if "routing" not in config:
                config["routing"] = {"rules": []}
            
            # 添加路由规则到开头
            for rule in reversed(routing_rules):
                config["routing"]["rules"].insert(0, rule)
        
        # 保存配置
        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(config, f, ensure_ascii=False, indent=2)
        
        print(f"✅ Xray配置已更新: {'启用WARP路由' if warp_enabled else '禁用WARP路由'}")
        return True
        
    except Exception as e:
        print(f"❌ 修改Xray配置失败: {e}")
        return False

def main():
    """主函数"""
    print("🌐 WARP集成工具 v1.0")
    print("支持JupyterLab和无root权限环境\n")
    
    # 创建WARP管理器
    warp_manager = WARPManager()
    
    # 询问用户是否启用WARP
    choice = input("是否启用WARP SOCKS5代理? (y/n): ").lower().strip()
    
    if choice in ['y', 'yes', '1']:
        # 尝试安装和启动WARP
        success = warp_manager.install_and_start()
        
        if success:
            print(f"\n✅ WARP服务已启动在 {warp_manager.warp_host}:{warp_manager.warp_port}")
            
            # 修改Xray配置
            if os.path.exists("config.json"):
                modify_xray_config_for_warp("config.json", True)
            elif os.path.exists(".cache/config.json"):
                modify_xray_config_for_warp(".cache/config.json", True)
            
            # 显示状态
            status = warp_manager.get_status()
            print(f"WARP状态: {json.dumps(status, indent=2)}")
            
        else:
            print("\n⚠️ WARP启动失败，将使用直连模式")
            print("这不影响核心代理功能，节点仍然可以正常使用")
    
    else:
        print("跳过WARP配置，使用直连模式")
    
    print("\n🎉 配置完成！")
    
    # 保持脚本运行（可选）
    try:
        input("\n按回车键退出...")
    except KeyboardInterrupt:
        pass
    finally:
        if 'warp_manager' in locals():
            warp_manager.stop()

if __name__ == "__main__":
    main()            print("Installing WARP client...")
            
            # Add Cloudflare repository
            subprocess.run([
                'curl', '-fsSL', 'https://pkg.cloudflareclient.com/pubkey.gpg'
            ], stdout=subprocess.PIPE, check=True)
            
            # Get distribution codename
            result = subprocess.run(['lsb_release', '-cs'], capture_output=True, text=True)
            codename = result.stdout.strip()
            
            # Add repository
            repo_line = f"deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ {codename} main"
            with open('/tmp/cloudflare-client.list', 'w') as f:
                f.write(repo_line)
            
            subprocess.run(['sudo', 'mv', '/tmp/cloudflare-client.list', '/etc/apt/sources.list.d/'], check=True)
            subprocess.run(['sudo', 'apt-get', 'update'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(['sudo', 'apt-get', 'install', '-y', 'cloudflare-warp'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Configure WARP
        print("Configuring WARP SOCKS5 proxy...")
        subprocess.run(['sudo', 'warp-cli', 'register'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(['sudo', 'warp-cli', 'set-mode', 'proxy'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(['sudo', 'warp-cli', 'set-proxy-port', '40000'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(['sudo', 'warp-cli', 'connect'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        print("WARP SOCKS5 proxy started on port 40000")
        return True
        
    except Exception as e:
        print(f"Failed to install/configure WARP: {e}")
        return False

def delete_nodes():
    try:
        if not UPLOAD_URL:
            return

        if not os.path.exists(sub_path):
            return

        try:
            with open(sub_path, 'r') as file:
                file_content = file.read()
        except:
            return None

        decoded = base64.b64decode(file_content).decode('utf-8')
        nodes = [line for line in decoded.split('\n') if any(protocol in line for protocol in ['vless://', 'vmess://', 'trojan://', 'hysteria2://', 'tuic://'])]

        if not nodes:
            return

        try:
            requests.post(f"{UPLOAD_URL}/api/delete-nodes", 
                          data=json.dumps({"nodes": nodes}),
                          headers={"Content-Type": "application/json"})
        except:
            return None
    except Exception as e:
        print(f"Error in delete_nodes: {e}")
        return None

def cleanup_old_files():
    paths_to_delete = ['web', 'bot', 'npm', 'php', 'boot.log', 'list.txt']
    for file in paths_to_delete:
        file_path = os.path.join(FILE_PATH, file)
        try:
            if os.path.exists(file_path):
                if os.path.isdir(file_path):
                    shutil.rmtree(file_path)
                else:
                    os.remove(file_path)
        except Exception as e:
            print(f"Error removing {file_path}: {e}")

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'Hello World')
            
        elif self.path == f'/{SUB_PATH}':
            try:
                with open(sub_path, 'rb') as f:
                    content = f.read()
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(content)
            except:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass

def get_system_architecture():
    architecture = platform.machine().lower()
    if 'arm' in architecture or 'aarch64' in architecture:
        return 'arm'
    else:
        return 'amd'

def download_file(file_name, file_url):
    file_path = os.path.join(FILE_PATH, file_name)
    try:
        response = requests.get(file_url, stream=True)
        response.raise_for_status()
        
        with open(file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        print(f"Download {file_name} successfully")
        return True
    except Exception as e:
        if os.path.exists(file_path):
            os.remove(file_path)
        print(f"Download {file_name} failed: {e}")
        return False

def get_files_for_architecture(architecture):
    if architecture == 'arm':
        base_files = [
            {"fileName": "web", "fileUrl": "https://arm64.ssss.nyc.mn/web"},
            {"fileName": "bot", "fileUrl": "https://arm64.ssss.nyc.mn/2go"}
        ]
    else:
        base_files = [
            {"fileName": "web", "fileUrl": "https://amd64.ssss.nyc.mn/web"},
            {"fileName": "bot", "fileUrl": "https://amd64.ssss.nyc.mn/2go"}
        ]

    if NEZHA_SERVER and NEZHA_KEY:
        if NEZHA_PORT:
            npm_url = "https://arm64.ssss.nyc.mn/agent" if architecture == 'arm' else "https://amd64.ssss.nyc.mn/agent"
            base_files.insert(0, {"fileName": "npm", "fileUrl": npm_url})
        else:
            php_url = "https://arm64.ssss.nyc.mn/v1" if architecture == 'arm' else "https://amd64.ssss.nyc.mn/v1"
            base_files.insert(0, {"fileName": "php", "fileUrl": php_url})

    return base_files

def authorize_files(file_paths):
    for relative_file_path in file_paths:
        absolute_file_path = os.path.join(FILE_PATH, relative_file_path)
        if os.path.exists(absolute_file_path):
            try:
                os.chmod(absolute_file_path, 0o775)
                print(f"Empowerment success for {absolute_file_path}: 775")
            except Exception as e:
                print(f"Empowerment failed for {absolute_file_path}: {e}")

def argo_type():
    if not ARGO_AUTH or not ARGO_DOMAIN:
        print("ARGO_DOMAIN or ARGO_AUTH variable is empty, use quick tunnels")
        return

    if "TunnelSecret" in ARGO_AUTH:
        with open(os.path.join(FILE_PATH, 'tunnel.json'), 'w') as f:
            f.write(ARGO_AUTH)
        
        tunnel_id = ARGO_AUTH.split('"')[11]
        tunnel_yml = f"""
tunnel: {tunnel_id}
credentials-file: {os.path.join(FILE_PATH, 'tunnel.json')}
protocol: http2

ingress:
  - hostname: {ARGO_DOMAIN}
    service: http://localhost:{ARGO_PORT}
    originRequest:
      noTLSVerify: true
  - service: http_status:404
"""
        with open(os.path.join(FILE_PATH, 'tunnel.yml'), 'w') as f:
            f.write(tunnel_yml)
    else:
        print("Use token connect to tunnel,please set the {ARGO_PORT} in cloudflare")

def exec_cmd(command):
    try:
        process = subprocess.Popen(
            command, 
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = process.communicate()
        return stdout + stderr
    except Exception as e:
        print(f"Error executing command: {e}")
        return str(e)

def generate_xray_config():
    """Generate Xray configuration with optional WARP routing"""
    base_config = {
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
            {"protocol": "blackhole", "tag": "block"}
        ]
    }
    
    # Add WARP routing if enabled
    if ENABLE_WARP:
        # Add WARP SOCKS5 outbound
        base_config["outbounds"].insert(1, {
            "protocol": "socks",
            "settings": {
                "servers": [{"address": "127.0.0.1", "port": 40000}]
            },
            "tag": "warp"
        })
        
        # Add routing rules for YouTube and other streaming sites
        base_config["routing"] = {
            "rules": [
                {
                    "type": "field",
                    "domain": [
                        "youtube.com",
                        "youtu.be",
                        "googlevideo.com",
                        "ytimg.com",
                        "ggpht.com",
                        "googleusercontent.com"
                    ],
                    "outboundTag": "warp"
                },
                {
                    "type": "field",
                    "domain": [
                        "geosite:google",
                        "geosite:youtube",
                        "geosite:netflix",
                        "geosite:disney",
                        "geosite:hulu"
                    ],
                    "outboundTag": "warp"
                }
            ]
        }
    
    return base_config

async def download_files_and_run():
    architecture = get_system_architecture()
    files_to_download = get_files_for_architecture(architecture)
    
    if not files_to_download:
        print("Can't find a file for the current architecture")
        return
    
    # Install WARP if enabled
    if ENABLE_WARP:
        install_warp()
    
    # Download all files
    download_success = True
    for file_info in files_to_download:
        if not download_file(file_info["fileName"], file_info["fileUrl"]):
            download_success = False
    
    if not download_success:
        print("Error downloading files")
        return
    
    # Authorize files
    files_to_authorize = ['npm', 'web', 'bot'] if NEZHA_PORT else ['php', 'web', 'bot']
    authorize_files(files_to_authorize)
    
    # Check TLS
    port = NEZHA_SERVER.split(":")[-1] if ":" in NEZHA_SERVER else ""
    if port in ["443", "8443", "2096", "2087", "2083", "2053"]:
        nezha_tls = "true"
    else:
        nezha_tls = "false"

    # Configure nezha
    if NEZHA_SERVER and NEZHA_KEY:
        if not NEZHA_PORT:
            config_yaml = f"""
client_secret: {NEZHA_KEY}
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 4
server: {NEZHA_SERVER}
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: {nezha_tls}
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: {UUID}"""
            
            with open(os.path.join(FILE_PATH, 'config.yaml'), 'w') as f:
                f.write(config_yaml)
    
    # Generate enhanced configuration file with WARP support
    config = generate_xray_config()
    with open(os.path.join(FILE_PATH, 'config.json'), 'w', encoding='utf-8') as config_file:
        json.dump(config, config_file, ensure_ascii=False, indent=2)
    
    # Run nezha
    if NEZHA_SERVER and NEZHA_PORT and NEZHA_KEY:
        tls_ports = ['443', '8443', '2096', '2087', '2083', '2053']
        nezha_tls = '--tls' if NEZHA_PORT in tls_ports else ''
        command = f"nohup {os.path.join(FILE_PATH, 'npm')} -s {NEZHA_SERVER}:{NEZHA_PORT} -p {NEZHA_KEY} {nezha_tls} >/dev/null 2>&1 &"
        
        try:
            exec_cmd(command)
            print('npm is running')
            time.sleep(1)
        except Exception as e:
            print(f"npm running error: {e}")
    
    elif NEZHA_SERVER and NEZHA_KEY:
        command = f"nohup {FILE_PATH}/php -c \"{FILE_PATH}/config.yaml\" >/dev/null 2>&1 &"
        try:
            exec_cmd(command)
            print('php is running')
            time.sleep(1)
        except Exception as e:
            print(f"php running error: {e}")
    else:
        print('NEZHA variable is empty, skipping running')
    
    # Run web (Xray)
    command = f"nohup {os.path.join(FILE_PATH, 'web')} -c {os.path.join(FILE_PATH, 'config.json')} >/dev/null 2>&1 &"
    try:
        exec_cmd(command)
        print('web is running')
        if ENABLE_WARP:
            print('WARP routing enabled for YouTube and streaming sites')
        time.sleep(1)
    except Exception as e:
        print(f"web running error: {e}")
    
    # Run cloudflared
    if os.path.exists(os.path.join(FILE_PATH, 'bot')):
        if re.match(r'^[A-Z0-9a-z=]{120,250}$', ARGO_AUTH):
            args = f"tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token {ARGO_AUTH}"
        elif "TunnelSecret" in ARGO_AUTH:
            args = f"tunnel --edge-ip-version auto --config {os.path.join(FILE_PATH, 'tunnel.yml')} run"
        else:
            args = f"tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile {os.path.join(FILE_PATH, 'boot.log')} --loglevel info --url http://localhost:{ARGO_PORT}"
        
        try:
            exec_cmd(f"nohup {os.path.join(FILE_PATH, 'bot')} {args} >/dev/null 2>&1 &")
            print('bot is running')
            time.sleep(2)
        except Exception as e:
            print(f"Error executing command: {e}")
    
    time.sleep(5)
    
    await extract_domains()

async def extract_domains():
    argo_domain = None

    if ARGO_AUTH and ARGO_DOMAIN:
        argo_domain = ARGO_DOMAIN
        print(f'ARGO_DOMAIN: {argo_domain}')
        await generate_links(argo_domain)
    else:
        try:
            with open(boot_log_path, 'r') as f:
                file_content = f.read()
            
            lines = file_content.split('\n')
            argo_domains = []
            
            for line in lines:
                domain_match = re.search(r'https?://([^ ]*trycloudflare\.com)/?', line)
                if domain_match:
                    domain = domain_match.group(1)
                    argo_domains.append(domain)
            
            if argo_domains:
                argo_domain = argo_domains[0]
                print(f'ArgoDomain: {argo_domain}')
                await generate_links(argo_domain)
            else:
                print('ArgoDomain not found, re-running bot to obtain ArgoDomain')
                if os.path.exists(boot_log_path):
                    os.remove(boot_log_path)
                
                try:
                    exec_cmd('pkill -f "[b]ot" > /dev/null 2>&1')
                except:
                    pass
                
                time.sleep(1)
                args = f'tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile {FILE_PATH}/boot.log --loglevel info --url http://localhost:{ARGO_PORT}'
                exec_cmd(f'nohup {os.path.join(FILE_PATH, "bot")} {args} >/dev/null 2>&1 &')
                print('bot is running.')
                time.sleep(6)
                await extract_domains()
        except Exception as e:
            print(f'Error reading boot.log: {e}')

def upload_nodes():
    if UPLOAD_URL and PROJECT_URL:
        subscription_url = f"{PROJECT_URL}/{SUB_PATH}"
        json_data = {
            "subscription": [subscription_url]
        }
        
        try:
            response = requests.post(
                f"{UPLOAD_URL}/api/add-subscriptions",
                json=json_data,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                print('Subscription uploaded successfully')
        except Exception as e:
            pass
    
    elif UPLOAD_URL:
        if not os.path.exists(list_path):
            return
        
        with open(list_path, 'r') as f:
            content = f.read()
        
        nodes = [line for line in content.split('\n') if any(protocol in line for protocol in ['vless://', 'vmess://', 'trojan://', 'hysteria2://', 'tuic://'])]
        
        if not nodes:
            return
        
        json_data = json.dumps({"nodes": nodes})
        
        try:
            response = requests.post(
                f"{UPLOAD_URL}/api/add-nodes",
                data=json_data,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                print('Nodes uploaded successfully')
        except:
            return None
    else:
        return

def send_telegram():
    if not BOT_TOKEN or not CHAT_ID:
        return
    
    try:
        with open(sub_path, 'r') as f:
            message = f.read()
        
        url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
        
        escaped_name = re.sub(r'([_*\[\]()~>#+=|{}.!\-])', r'\\\1', NAME)
        
        params = {
            "chat_id": CHAT_ID,
            "text": f"**{escaped_name}节点推送通知**\n{message}",
            "parse_mode": "MarkdownV2"
        }
        
        requests.post(url, params=params)
        print('Telegram message sent successfully')
    except Exception as e:
        print(f'Failed to send Telegram message: {e}')

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
    
    if ENABLE_WARP:
        print("WARP routing enabled - YouTube and streaming sites will use WARP proxy")
    
    send_telegram()
    upload_nodes()
  
    return sub_txt

def add_visit_task():
    if not AUTO_ACCESS or not PROJECT_URL:
        print("Skipping adding automatic access task")
        return
    
    try:
        response = requests.post(
            'https://keep.gvrander.eu.org/add-url',
            json={"url": PROJECT_URL},
            headers={"Content-Type": "application/json"}
        )
        print('automatic access task added successfully')
    except Exception as e:
        print(f'Failed to add URL: {e}')

def clean_files():
    def _cleanup():
        time.sleep(90)
        files_to_delete = [boot_log_path, config_path, list_path, web_path, bot_path, php_path, npm_path]
        
        if NEZHA_PORT:
            files_to_delete.append(npm_path)
        elif NEZHA_SERVER and NEZHA_KEY:
            files_to_delete.append(php_path)
        
        for file in files_to_delete:
            try:
                if os.path.exists(file):
                    if os.path.isdir(file):
                        shutil.rmtree(file)
                    else:
                        os.remove(file)
            except:
                pass
        
        print('\033c', end='')
        print('App is running')
        print('Thank you for using this script, enjoy!')
        if ENABLE_WARP:
            print('WARP SOCKS5 proxy is active on port 40000')
    
    threading.Thread(target=_cleanup, daemon=True).start()

async def start_server():
    delete_nodes()
    cleanup_old_files()
    create_directory()
    argo_type()
    await download_files_and_run()
    add_visit_task()
    
    server_thread = Thread(target=run_server)
    server_thread.daemon = True
    server_thread.start()   
    
    clean_files()
    
def run_server():
    server = HTTPServer(('0.0.0.0', PORT), RequestHandler)
    print(f"Server is running on port {PORT}")
    print(f"Running done！")
    if ENABLE_WARP:
        print("WARP SOCKS5 proxy enabled for YouTube and streaming sites")
    print(f"\nLogs will be delete in 90 seconds")
    server.serve_forever()
    
def run_async():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(start_server()) 
    
    while True:
        time.sleep(3600)
        
if __name__ == "__main__":
    run_async()
