#!/bin/bash
apt update

#获取架构类型
architecture=$(uname -m)

# 检测eth0的IP
ip_address=$(ip addr show eth0 | grep -oP 'inet \K[\d.]+')

#获取信息
echo "请输入对端IP："
read remoteip

#安装必要组件
apt install wget unzip gzip -y

#下载Gost
if [ "$architecture" == "x86_64" ]; then
    file_url="https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz"
elif [ "$architecture" == "aarch64" ]; then
    file_url="https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-armv8-2.11.5.gz"
else
    echo "不支持您的系统架构 目前只支持x86_64与arm64 当前架构为: $architecture"
    exit 1
fi
wget "$file_url" || {
    echo "文件下载失败"
    exit 1
}
for file in gost*; do
    if [ -f "$file" ]; then
        gunzip "$file"
    fi
done
for file in gost*; do
    if [ -f "$file" ]; then
        mv "$file" gost
    fi
done

#安装Gost
chmod u+x gost
cp gost /usr/local/bin
mkdir /etc/gost
tee /etc/gost/gost.json <<EOF
{
    "Debug": false,
    "Retries": 2,
    "ServeNodes": [
        "udp://:65535"
    ],
    "ChainNodes": [
        "relay+tls://$remoteip:56789"
    ]
}
EOF
tee /etc/systemd/system/gost.service > /dev/null <<EOF
[Unit]
Description=GOST-Server of GO simple tunnel
Documentation=https://gost.run/
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -C /etc/gost/gost.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

#开启转发
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
sysctl -p

#开机自启
systemctl start gost.service
systemctl enable gost.service

#完成安装
echo "安装完成"
echo "请使用$ip_address:56789来连接对端WireGuard"
