#!/bin/bash
apt update

#获取架构类型
architecture=$(uname -m)

# 检测eth0的IP
ip_address=$(ip addr show eth0 | grep -oP 'inet \K[\d.]+')

#获取信息
echo "请输入WireGuard本端IP："
read wgip

echo "请输入WireGuard对端IP："
read wgdip

echo "请输入WireGuard本端端口："
read wgport

echo "请输入WireGuard本端私钥："
read privateKey

echo "请输入WireGuard对端公钥："
read publicKey

echo "请输入路由ID：(推荐WireGuard本地IP)"
read routeid

#安装必要组件
apt install wireguard wget curl make iptables bird2 iptables-persistent unzip gzip git -y

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
        "relay+tls://:65534/$wgip:$wgport"
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

#配置WireGuard服务信息
tee /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $wgip/24
ListenPort = $wgport
PrivateKey = $privateKey
Table = off
MTU = 1412

[Peer]
PublicKey = $publicKey
AllowedIPs = $wgdip/32, 224.0.0.5/32
EOF

#配置OSPF服务
git clone https://github.com/dndx/nchnroutes.git
mv /root/nchnroutes/Makefile /root/nchnroutes/Makefile.orig
tee /root/nchnroutes/Makefile <<EOF
produce:
	git pull
	curl -o delegated-apnic-latest https://ftp.apnic.net/stats/apnic/delegated-apnic-latest
	curl -o china_ip_list.txt https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt
	python3 produce.py --next eth0 --exclude $ip_address/32
	mv routes4.conf /etc/bird/routes4.conf
	# sudo mv routes6.conf /etc/bird/routes6.conf
	# sudo birdc configure
	# sudo birdc6 configure
EOF
make -C /root/nchnroutes

#配置Bird2服务
mv /etc/bird/bird.conf /etc/bird/bird.conf.orig
tee /etc/bird/bird.conf <<EOF
router id $routeid;
protocol device {
}

protocol static {
        ipv4;
        include "routes4.conf";
}

protocol ospf v2 {
        ipv4 {
                export all;
                import none;
        };
        area 0.0.0.0 {
                interface "wg*" {
                        type ptp;
                        hello 10;
                        dead 40;
                };
        };
}
EOF
#防火墙配置持久化
tee /etc/iptables/rules.v4 <<EOF
*nat
:PREROUTING ACCEPT
:INPUT ACCEPT
:OUTPUT ACCEPT
:POSTROUTING ACCEPT
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT

*filter
:INPUT ACCEPT
:FORWARD ACCEPT
:OUTPUT ACCEPT
-A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
COMMIT

*mangle
:PREROUTING ACCEPT
:INPUT ACCEPT
:FORWARD ACCEPT
:OUTPUT ACCEPT
:POSTROUTING ACCEPT
-A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
COMMIT
EOF
update-alternatives --set iptables /usr/sbin/iptables-legacy
iptables-restore < /etc/iptables/rules.v4

#启动服务
wg-quick up wg0
systemctl start gost.service
birdc c

#开机自启
systemctl enable wg-quick@wg0
systemctl enable gost.service

#完成安装
echo "安装完成"
echo "请执行 crontab -e 并在末尾添加 0 0 * * 0 make -C /root/nchnroutes"
