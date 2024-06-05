#!/bin/bash
while true; do
    echo "-------------------"
    echo "请选择要执行的操作:"
    echo "-------------------"
    echo ""
    echo "1. GOST ( 客户端 )"
    echo ""
    echo "2. GOST + WireGuard + OSPF ( 服务端 )"
    echo ""
    echo "3. 退出"
    echo ""
    read -p "请输入操作编号： " option

    case "$option" in
        1)  wget https://raw.githubusercontent.com/Hamster-Prime/ospf-wg-gost/main/install_gost.sh && chmod +x install_gost.sh && ./install_gost.sh
            ;;
        2)  wget https://raw.githubusercontent.com/Hamster-Prime/ospf-wg-gost/main/install_ospf_ws_gost.sh && chmod +x install_ospf_ws_gost.sh && ./install_ospf_ws_gost.sh
            ;;
        3)  echo "退出脚本"
            exit 0
            ;;
        *)  echo "无效选项，请重新选择"
            continue
            ;;
    esac
done
