#!/usr/bin/env python3
"""
简化版WARP集成脚本
适用于JupyterLab环境
"""

import os
import sys
import json
import time
import subprocess
import platform
import requests

def get_architecture():
    """获取系统架构"""
    arch = platform.machine().lower()
    if arch in ['x86_64', 'amd64']:
        return 'amd64'
    elif arch in ['aarch64', 'arm64']:
        return 'arm64'
    else:
        return 'amd64'

def download_warp_client():
    """下载WARP客户端"""
    arch = get_architecture()
    url = f"https://github.com/bepass-org/warp-plus/releases/latest/download/warp-plus_linux-{arch}"
    filename = "warp-plus"
    
    try:
        print(f"正在下载 WARP 客户端 ({arch})...")
        response = requests.get(url, stream=True, timeout=60)
        response.raise_for_status()
        
        with open(filename, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        os.chmod(filename, 0o755)
        print("✅ WARP客户端下载成功")
        return True
        
    except Exception as e:
        print(f"❌ 下载失败: {e}")
        return False

def start_warp_service():
    """启动WARP服务"""
    if not os.path.exists("warp-plus"):
        print("❌ WARP客户端不存在")
        return False, None
    
    try:
        print("🚀 正在启动 WARP 服务...")
        
        # 启动WARP
        process = subprocess.Popen(
            ["./warp-plus", "--bind", "127.0.0.1:40000"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            preexec_fn=os.setsid if hasattr(os, 'setsid') else None
        )
        
        # 等待启动
        time.sleep(5)
        
        if process.poll() is None:
            print(f"✅ WARP服务启动成功，PID: {process.pid}")
            return True, process.pid
        else:
            stdout, stderr = process.communicate()
            print(f"❌ WARP启动失败: {stderr.decode()}")
            return False, None
            
    except Exception as e:
        print(f"❌ 启动WARP失败: {e}")
        return False, None

def test_warp_connection():
    """测试WARP连接"""
    try:
        import socket
        
        # 简单的端口连通性测试
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        result = sock.connect_ex(('127.0.0.1', 40000))
        sock.close()
        
        if result == 0:
            print("✅ WARP代理端口连通性测试成功")
            return True
        else:
            print("❌ WARP代理端口不可访问")
            return False
            
    except Exception as e:
        print(f"❌ 连接测试失败: {e}")
        return False

def update_xray_config():
    """更新Xray配置以支持WARP"""
    config_files = ["config.json", ".cache/config.json", "python-xray-argo/config.json"]
    
    for config_file in config_files:
        if os.path.exists(config_file):
            try:
                print(f"📝 正在更新配置文件: {config_file}")
                
                with open(config_file, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                
                # 添加WARP outbound
                warp_outbound = {
                    "protocol": "socks",
                    "settings": {
                        "servers": [{"address": "127.0.0.1", "port": 40000}]
                    },
                    "tag": "warp"
                }
                
                if "outbounds" not in config:
                    config["outbounds"] = []
                
                # 检查是否已存在WARP配置
                warp_exists = any(out.get("tag") == "warp" for out in config["outbounds"])
                if not warp_exists:
                    config["outbounds"].insert(1, warp_outbound)
                
                # 添加路由规则
                youtube_rule = {
                    "type": "field",
                    "domain": [
                        "youtube.com",
                        "youtu.be",
                        "googlevideo.com",
                        "ytimg.com"
                    ],
                    "outboundTag": "warp"
                }
                
                if "routing" not in config:
                    config["routing"] = {"rules": []}
                
                # 检查是否已存在YouTube路由规则
                youtube_rule_exists = any(
                    rule.get("outboundTag") == "warp" and 
                    "youtube.com" in rule.get("domain", [])
                    for rule in config["routing"]["rules"]
                )
                
                if not youtube_rule_exists:
                    config["routing"]["rules"].insert(0, youtube_rule)
                
                # 保存配置
                with open(config_file, 'w', encoding='utf-8') as f:
                    json.dump(config, f, ensure_ascii=False, indent=2)
                
                print(f"✅ 配置文件更新成功: {config_file}")
                return True
                
            except Exception as e:
                print(f"❌ 更新配置失败 {config_file}: {e}")
                continue
    
    print("⚠️ 未找到Xray配置文件")
    return False

def main():
    """主函数"""
    print("🌐 WARP集成工具 - 简化版")
    print("适用于JupyterLab和无root权限环境\n")
    
    # 询问用户
    choice = input("是否启用WARP SOCKS5代理? (y/n): ").lower().strip()
    
    if choice not in ['y', 'yes', '1']:
        print("跳过WARP配置")
        return
    
    # 下载WARP客户端
    if not download_warp_client():
        print("❌ WARP客户端下载失败")
        return
    
    # 启动WARP服务
    success, pid = start_warp_service()
    
    if not success:
        print("❌ WARP服务启动失败")
        return
    
    # 测试连接
    if test_warp_connection():
        print("✅ WARP代理测试成功")
    else:
        print("⚠️ WARP代理测试失败，但服务已启动")
    
    # 更新Xray配置
    if update_xray_config():
        print("✅ Xray配置更新成功")
    else:
        print("⚠️ Xray配置更新失败")
    
    print(f"\n🎉 WARP配置完成！")
    print(f"📊 WARP服务PID: {pid}")
    print(f"🌐 代理地址: 127.0.0.1:40000")
    print(f"🎯 YouTube等网站将通过WARP访问")
    
    print(f"\n🔧 管理命令:")
    print(f"  查看WARP进程: ps -p {pid}")
    print(f"  停止WARP: kill {pid}")
    print(f"  重启WARP: kill {pid} && ./warp-plus --bind 127.0.0.1:40000 &")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 用户取消操作")
    except Exception as e:
        print(f"\n❌ 程序执行出错: {e}")
