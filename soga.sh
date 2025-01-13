#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi: ${plain} Vui lòng cấp quyền truy cập root！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "armbian"; then
    release="armbian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "armbian"; then
    release="armbian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Hệ thống hiện tại không hỗ trợ！${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Yêu cầu CentOS 6 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Yêu cầu Ubuntu 16 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Yêu cầu Debian 8 trở lên！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Mặc định$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "KHởi động lại soga" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Enter để quay lại: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/soga/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Nhập phiên bản(mặc định mới nhất)
: " && read version
    else
        version=$2
    fi
#    confirm "Cài đặt phiên bản mới giữ nguyên dữ liệu?" "n"
#    if [[ $? != 0 ]]; then
#        echo -e "${red}Đã hủy${plain}"
#        if [[ $1 != 0 ]]; then
#            before_show_menu
#        fi
#        return 0
#    fi
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/soga/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Cài đặt hoàn tất, soga sẽ tự động chạy${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    soga-tool $*
}

uninstall() {
    confirm "Bạn có chắc muốn gỡ soga không?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop soga
    systemctl disable soga
    rm /etc/systemd/system/soga.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/soga/ -rf
    rm /usr/local/soga/ -rf

    echo ""
    echo -e "Gỡ cài đặt thành công, để xóa sạch vui lòng chạy ${green}rm /usr/bin/soga -f${plain} để xóa"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}soga đang chạy, không cần phải khởi động lại${plain}"
    else
        systemctl reset-failed soga
        systemctl start soga
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}soga chạy thành công, sử dụng soga log để xem nhật ký${plain}"
        else
            echo -e "${red}soga không thể chạy, sử dụng soga log để xem nhật ký${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop soga
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}soga Đã dừng${plain}"
    else
        echo -e "${red}soga không thể dừng, vui lòng xem nhật ký${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl reset-failed soga
    systemctl restart soga
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}soga đã khởi động lại，Sử dụng soga log để xem nhật ký${plain}"
    else
        echo -e "${red}soga không thể khởi động lại, sử dụng soga log để xem nhật ký${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable soga
    if [[ $? == 0 ]]; then
        echo -e "${green}soga thiết lập tự khởi động thành công${plain}"
    else
        echo -e "${red}soga thiết lập không tự khởi động${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable soga
    if [[ $? == 0 ]]; then
        echo -e "${green}soga Đã hủy khởi động${plain}"
    else
        echo -e "${red}soga Không thể hủy khởi động${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    n="$2"
    if [[ $2 == "" ]]; then
        n="1000"
    fi
    journalctl -u soga.service -e --no-pager -f -n "${n}"
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

update_shell() {
    wget -O /usr/bin/soga -N --no-check-certificate https://github.com/vaxilu/soga/raw/master/soga.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Không thể nâng cấp tập lệnh, kiểm tra kết nối tới Github Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/soga
        echo -e "${green}Nâng cấp tập lệnh thành công${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/soga.service ]]; then
        return 2
    fi
    temp=$(systemctl status soga | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled soga)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}soga đã được cài đặt, không cần cài đặt lại${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Vui lòng cài đặt soga${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "soga: ${green}đang chạy${plain}"
            show_enable_status
            ;;
        1)
            echo -e "soga: ${yellow}không chạy${plain}"
            show_enable_status
            ;;
        2)
            echo -e "soga: ${red}chưa được cài đặt${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Có tự khởi động soga không: ${green}Có${plain}"
    else
        echo -e "Có tự khởi động soga: ${red}Không${plain}"
    fi
}

show_soga_version() {
    echo -n "Phiên bản soga："
    /usr/local/soga/soga -v
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
    echo "LỆNH QUẢN LÝ SOGA: "
    echo "------------------------------------------"
    echo "soga                    - Hiển thị menu quản lý"
    echo "soga start              - Bắt đầu soga"
    echo "soga stop               - Dừng soga"
    echo "soga restart            - Khởi động lại soga"
    echo "soga enable             - Khởi động cùng hệ thống"
    echo "soga disable            - Dừng khởi động cùng hệ thống"
    echo "soga log                - Nhật ký soga"
    echo "soga update             - Cập nhật soga"
    echo "soga update x.x.x       - Cập nhật soga x.x.x"
    echo "soga config             - Thiết lập cấu hình soga"
    echo "soga config xx=xx yy=yy - Thiết lập cấu hình chi tiết"
    echo "soga install            - Cài đặt soga"
    echo "soga uninstall          - Gỡ cài đặt soga"
    echo "soga version            - Phiên bản soga"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}soga Lệnh quản lý soga，${plain}${red}không áp dụng cho docker${plain}

  ${green}0.${plain} Thoát
————————————————
  ${green}1.${plain} Cài đặt soga
  ${green}2.${plain} Cập nhật soga
  ${green}3.${plain} Gỡ cài đặt soga
————————————————
  ${green}4.${plain} Bắt đầu soga
  ${green}5.${plain} Dừng soga
  ${green}6.${plain} Khởi động lại soga
  ${green}7.${plain} Xem nhật ký soga
————————————————
  ${green}8.${plain} Thiết lập soga tự khởi động
  ${green}9.${plain} Hủy thiết lập soga tự khởi động
————————————————
 ${green}10.${plain} Xem phiên bản soga
 "
    show_status
    echo && read -p "Nhập lựa chọn [0-10]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && show_log
        ;;
        8) check_install && enable
        ;;
        9) check_install && disable
        ;;
        10) check_install && show_soga_version
        ;;
        *) echo -e "${red}Vui lòng nhập lại [0-10]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0 $2
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_soga_version 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
