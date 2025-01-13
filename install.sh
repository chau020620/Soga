#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi：${plain} Vui lòng cấp quyền truy cập root！\n" && exit 1

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
    echo -e "${red}Phiên bản hệ thống hiện tại không hỗ trợ！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}Phiên bản kiến trúc hiện tại không hỗ trợ!: ${arch}${plain}"
fi

echo "Kiến trúc: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Không hỗ trợ phiên bản 32bit, vui lòng sử dụng phiên bản 64bit"
    exit 2
fi

#os_version=""
#
## os version
#if [[ -f /etc/os-release ]]; then
#    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
#fi
#if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
#    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
#fi
#
#if [[ x"${release}" == x"centos" ]]; then
#    if [[ ${os_version} -le 6 ]]; then
#        echo -e "${red}Sử dụng CenteOS 7 trở lên！${plain}\n" && exit 1
#    fi
#elif [[ x"${release}" == x"ubuntu" ]]; then
#    if [[ ${os_version} -lt 16 ]]; then
#        echo -e "${red}Sử dụng Ubuntu 16 trở lên！${plain}\n" && exit 1
#    fi
#elif [[ x"${release}" == x"debian" ]]; then
#    if [[ ${os_version} -lt 8 ]]; then
#        echo -e "${red}Sử dụng Debian 8 trở lên！${plain}\n" && exit 1
#    fi
#fi

function is_cmd_exist() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        return 1
    fi

    which "$cmd" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        return 0
    fi

	  return 2
}

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar crontabs socat tzdata -y
    else
        apt install wget curl tar cron socat tzdata -y
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

install_acme() {
    curl https://get.acme.sh | sh
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

install_soga() {
    cd /usr/local/
    if [[ -e /usr/local/soga/ ]]; then
        rm /usr/local/soga/ -rf
    fi

    if  [ $# == 0 ] ;then
#        last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/soga/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
#        if [[ ! -n "$last_version" ]]; then
#            echo -e "${red}soga Không thể cài đặt，vui lòng chọn phiên bản thủ công${plain}"
#            exit 1
#        fi
        echo -e "Bắt đầu cài soga phiên bản mới nhất"
        wget -N --no-check-certificate -O /usr/local/soga.tar.gz https://github.com/vaxilu/soga/releases/latest/download/soga-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không thể tải soga, vui lòng kiểm tra kết nối đến máy chủ Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/vaxilu/soga/releases/download/${last_version}/soga-linux-${arch}.tar.gz"
        echo -e "Bắt đầu cài đặt soga v$1"
        wget -N --no-check-certificate -O /usr/local/soga.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không tải được soga v$1 Hãy đảm bảo phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    tar zxvf soga.tar.gz
    rm soga.tar.gz -f
    cd soga
    chmod +x soga
    last_version="$(./soga -v)"
    mkdir /etc/soga/ -p
    rm /etc/systemd/system/soga.service -f
    rm /etc/systemd/system/soga@.service -f
    cp -f soga.service /etc/systemd/system/
    cp -f soga@.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop soga
    systemctl enable soga
    echo -e "${green}soga v${last_version}${plain} Cài đặt hoàn tất, tự khởi động được thiết lập"
    if [[ ! -f /etc/soga/soga.conf ]]; then
        cp soga.conf /etc/soga/
        echo -e ""
        echo -e "Vui lòng thiết lập cấu hình cần thiết"
    else
        systemctl start soga
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}soga đã khởi động lại thành công${plain}"
        else
            echo -e "${red}soga có thể không khởi động được, vui lòng xem nhật ký${plain}"
        fi
    fi

    if [[ ! -f /etc/soga/blockList ]]; then
        cp blockList /etc/soga/
    fi
    if [[ ! -f /etc/soga/whiteList ]]; then
        cp whiteList /etc/soga/
    fi
    if [[ ! -f /etc/soga/dns.yml ]]; then
        cp dns.yml /etc/soga/
    fi
    if [[ ! -f /etc/soga/routes.toml ]]; then
        cp routes.toml /etc/soga/
    fi
    curl -o /usr/bin/soga -Ls https://raw.githubusercontent.com/chau020620/Soga/main/soga.sh
    chmod +x /usr/bin/soga
    curl -o /usr/bin/soga-tool -Ls https://raw.githubusercontent.com/vaxilu/soga/master/soga-tool-${arch}
    chmod +x /usr/bin/soga-tool
    echo -e ""
    echo "Các lệnh quán lý soga: "
    echo "------------------------------------------"
    echo "soga                    - Bắt đầu bảng điều khiển soga"
    echo "soga start              - Bắt đầu soga"
    echo "soga stop               - Dừng soga"
    echo "soga restart            - Khởi động lại soga"
    echo "soga status             - Trạng thái soga"
    echo "soga enable             - Khởi động soga cùng hệ thống"
    echo "soga disable            - Dừng khởi động soga cùng hệ thống"
    echo "soga log                - Nhật ký soga"
    echo "soga log n              - Nhật ký soga n"
    echo "soga update             - Cập nhật soga"
    echo "soga update x.x.x       - Cập nhật soga phiên bản"
    echo "soga config             - Cấu hình soga"
    echo "soga config xx=xx yy=yy - Cấu hình soga xxyy"
    echo "soga install            - Cài đặt soga"
    echo "soga uninstall          - Gỡ cài đặt soga"
    echo "soga version            - Phiên bản soga"
    echo "------------------------------------------"
}

is_cmd_exist "systemctl"
if [[ $? != 0 ]]; then
    echo "systemctl không tồn tại, vui lòng sử dụng phiên bản mới hơn của hệ thống."
    exit 1
fi

echo -e "${green}Bắt đầu cài đặt${plain}"
install_base
install_acme
install_soga $1
