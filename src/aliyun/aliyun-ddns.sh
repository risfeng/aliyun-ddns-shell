#!/bin/bash

#版本信息
build_date="20200307"
build_version="v1.0.0"

#当前时间 格式：2020-03-12 14:36:31
NOW_DATE=$(date "+%Y-%m-%d %H:%M:%S")

#当前时间
echo "=========== $(date) ==========="

#定义字体颜色
color_black_start="\033[30m"
color_red_start="\033[31m"
color_green_start="\033[32m"
color_yellow_start="\033[33m"
color_blue_start="\033[34m"
color_purple_start="\033[35m"
color_sky_blue_start="\033[36m"
color_white_start="\033[37m"
color_end="\033[0m"

#提示信息级别定义
message_info_tag="${color_sky_blue_start}[Info]    ${NOW_DATE} ${color_end}"
message_warning_tag="${color_yellow_start}[Warning] ${NOW_DATE} ${color_end}"
message_error_tag="${color_red_start}[Error]   ${NOW_DATE} ${color_end}"
message_success_tag="${color_green_start}[Success] ${NOW_DATE} ${color_end}"
message_fail_tag="${color_red_start}[Failed]  ${NOW_DATE} ${color_end}"

#功能、版本信息描述输出
function fun_show_version_info(){
echo -e "${color_green_start}
#############################################################
# Aliyun Domain DNS Update Shell Script
#
# Dynamic DNS Update Using Aliyun API
#
# Version: ${build_version}
# BuildDate: ${build_date}
# Author: risfeng<risfeng@gmail.com>
# GitHub: https://github.com/risfeng/aliyun-ddns-shell
#
# Usage: please refer to https://github.com/risfeng/aliyun-ddns-shell/blob/master/README.md
#
#############################################################
${color_end}"
}

fun_show_version_info

#全局变量定义

#操作系统发行名常量
MAC_OS_RELEASE="Darwin"
CENT_OS_RELEASE="centos"
UBUNTU_OS_RELEASE="ubuntu"
DEBIAN_OS_RELEASE="debian"

# 配置、日志文件存放目录
FILE_SAVE_DIR=""
# 目录前缀
FILE_DIR_PREFIX="aliyun-ddns"
#配置文件路径
CONFIG_FILE_PATH=""
# 配置文件名
CONFIG_FILE_NAME="config.cfg"
#日志储存目录
LOG_FILE_PATH=""
# 日志文件名
LOG_FILE_NAME="log-info.log"

#当前时间戳
var_now_timestamp=""

#是否root权限执行
var_is_root_execute=false
#是否支持sudo执行
var_is_support_sudo=false
#是否已安装curl组件
var_is_installed_curl=false
#是否已安装openssl组件
var_is_installed_openssl=false
#是否已安装nslookup组件
var_is_installed_nslookup=false
#当前操作系统发行版本
var_os_release=`uname  -a`
#当前网络是否通外网
var_is_online=false
#是否存在配置文件
var_is_exist_config_file=false
#检测外网是否通地址 默认:www.baidu.com
var_check_online_url=""
#检测外网是否通重试次数 默认:3
var_check_online_retry_times=""

#阿里云Dns动态更新配置变量定义

#一级域名 例如:example.com
var_first_level_domain=""
#二级域名 例如:testddns
var_second_level_domain=""
# 域名解析类型：A、NS、MX、TXT、CNAME、SRV、AAAA、CAA、REDIRECT_URL、FORWARD_URL
var_domain_record_type=""
#域名生效时间,默认:600 单位:秒
var_domain_ttl=""
#域名线路,默认为默认
var_domain_line=""
#阿里云授权Key
var_access_key_id=""
#阿里云授权Key Secret
var_access_key_secret=""
#阿里云更新域名Api Host 默认:https://alidns.aliyuncs.com
var_aliyun_ddns_api_host="https://alidns.aliyuncs.com"
#获取本机外网IP的shell命令,不能带有双引号 默认:"curl -s http://members.3322.org/dyndns/getip"
var_local_wan_ip=""
#获取ddns域名当前的解析记录的shell命令,支持数组,不能带有双引号  默认:使用nslookup获取
var_domain_server_ip=""
#域名解析记录Id
var_domain_record_id=""

#消息推送配置,使用阿里钉钉

#是否启用消息推送
var_enable_message_push=false
#推送地址
var_push_message_api="https://oapi.dingtalk.com/robot/send"
#加签密钥
var_push_message_secret=""
#消息推送token
var_push_message_access_token=""

#==================函数====================

# ping地址是否通
function fun_ping() {
    if ping -c 1 $1 >/dev/null; then
        # ping通
        echo true
    else
        # 不通
        echo false
    fi
}

# 检测是否通外网
function fun_check_online(){
    for((i=1;i<=$var_check_online_retry_times;i++)); do
        fun_wirte_log "${message_info_tag}正在尝试检测外网:ping ${var_check_online_url}${color_red_start} $i ${color_end}times......"
        var_is_online=$(fun_ping ${var_check_online_url})
        if [[ ${var_is_online} = true ]]; then
            fun_wirte_log "${message_success_tag}检测外网成功!"
            break
        else
            fun_wirte_log "${message_fail_tag}外网不通，ping ${var_check_online_url} fail."
        fi
    done
    if [[ ${var_is_online} = false ]]; then
        fun_wirte_log "${message_error_tag}检测当前无外网环境,重试${$var_check_online_retry_times}次ping ${var_check_online_url}都失败,程序终止执行."
        exit 1
    fi
}

# 检测root权限
function fun_check_root(){
    if [[ "`id -u`" != "0" ]]; then
        var_is_root_execute=false
    else
        var_is_root_execute=true
    fi
}

# 设置配置、日志文件保存目录
function fun_setting_file_save_dir(){
    fun_check_root
    if [ "${FILE_SAVE_DIR}" = "" ]; then
        if [[ "${var_os_release}" =~ "${MAC_OS_RELEASE}" ]]; then
            FILE_SAVE_DIR="./${FILE_DIR_PREFIX}"
        else
            if [ "${var_is_root_execute}" = true ]; then
                FILE_SAVE_DIR="/etc/${FILE_DIR_PREFIX}"
            else
                FILE_SAVE_DIR=~/"${FILE_DIR_PREFIX}"
            fi
        fi
    fi

    if [ ! -d "$FILE_SAVE_DIR" ]; then
        mkdir -p ${FILE_SAVE_DIR}
    fi

    if [ "${CONFIG_FILE_PATH}" = "" ]; then
        CONFIG_FILE_PATH="${FILE_SAVE_DIR}/${CONFIG_FILE_NAME}"
    fi

    if [ "${LOG_FILE_PATH}" = "" ]; then
        LOG_FILE_PATH="${FILE_SAVE_DIR}/${LOG_FILE_NAME}"
    fi
}

# 检测运行环境
function fun_check_run_environment(){
    if [[ -f "/usr/bin/sudo" ]]; then
        var_is_support_sudo=true
    else
        var_is_support_sudo=false
    fi
    if [[ -f "/usr/bin/curl" ]]; then
        var_is_installed_curl=true
    else
        var_is_installed_curl=false
    fi
    if [[ -f "/usr/bin/openssl" ]]; then
        var_is_installed_openssl=true
    else
        var_is_installed_openssl=false
    fi
    if [[ -f "/usr/bin/nslookup" ]]; then
        var_is_installed_nslookup=true
    else
        var_is_installed_nslookup=false
    fi
    if [ -f "/etc/redhat-release" ]; then
        var_os_release="centos"
    elif [ -f "/etc/lsb-release" ]; then
        var_os_release="ubuntu"
    elif [ -f "/etc/debian_version" ]; then
        var_os_release="debian"
    fi
}

# 获取本机外网IP
function fun_get_local_wan_ip(){
    fun_wirte_log "${message_info_tag}正在获取本机外网ip......"
    if [[ "${var_local_wan_ip}" = "" ]]; then
        fun_wirte_log "${message_error_tag}获取外网ip配置项为空或无效."
        fun_wirte_log "${message_fail_tag}程序终止执行......"
        exit 1
    fi
    var_local_wan_ip=`${var_local_wan_ip}`
    if [[ "${var_local_wan_ip}" = "" ]]; then
        fun_wirte_log "${message_error_tag}获取外网ip失败,请检查var_local_wan_ip配置项命令是否正确."
        fun_wirte_log "${message_fail_tag}程序终止执行......"
        exit 1
    else
        fun_wirte_log "${message_info_tag}本机外网ip:${var_local_wan_ip}"
    fi
}

# 获取DDNS域名当前解析记录IP
function fun_get_domain_server_ip(){
    fun_wirte_log "${message_info_tag}正在获取${var_second_level_domain}.${var_first_level_domain}的ip......"
    if [[ "${var_domain_server_ip}" = "nslookup" ]]; then
        var_domain_server_ip=`nslookup -sil ${var_second_level_domain}.${var_first_level_domain} ns2.alidns.com 2>/dev/null | grep Address: | sed 1d | sed s/Address://g | sed 's/ //g'`
    else
        var_domain_server_ip=`${var_domain_server_ip} | sed 's/;/ /g'`
    fi
    fun_wirte_log "${message_info_tag}域名${var_second_level_domain}.${var_first_level_domain}的当前ip:${var_domain_server_ip}"
}

# 判断当前外网ip与域名到服务ip是否相同
function fun_is_wan_ip_and_domain_ip_same(){
    if [[ "${var_domain_server_ip}" != "" ]]; then
        if [[ "${var_domain_server_ip}" =~ "${var_local_wan_ip}" ]]; then
            fun_wirte_log "${message_info_tag}当前外网ip:[${var_local_wan_ip}]与${var_second_level_domain}.${var_first_level_domain}($var_domain_server_ip)的ip相同."
            fun_wirte_log "${message_success_tag}本地ip与域名解析ip未发生任何变动,无需更改,程序退出."
            exit 0
        fi
    fi
}

# 安装运行必需组件
function fun_install_run_environment(){
    if [[ ${var_is_installed_curl} = false ]] || [[ ${var_is_installed_openssl} = false ]] || [[ ${var_is_installed_nslookup} = false ]]; then
        fun_wirte_log "${message_warning_tag}检测到缺少运行必需组件,正在尝试安装......"
        # 有root权限
        if [[ "${var_is_root_execute}" = true ]]; then
            if [[ "${var_os_release}" = "${CENT_OS_RELEASE}" ]]; then
                fun_wirte_log "${message_info_tag}检测到当前系统发行版本为:${CENT_OS_RELEASE}"
                fun_wirte_log "${message_info_tag}正在安装必需组件......"
                yum install curl openssl bind-utils -y
                elif [[ "${var_os_release}" = "${UBUNTU_OS_RELEASE}" ]];then
                fun_wirte_log "${message_info_tag}检测到当前系统发行版本为:${UBUNTU_OS_RELEASE}"
                fun_wirte_log "${message_info_tag}正在安装必需组件......"
                apt-get install curl openssl bind-utils -y
                elif [[ "${var_os_release}" = "${DEBIAN_OS_RELEASE}" ]]; then
                fun_wirte_log "${message_info_tag}检测到当前系统发行版本为:${DEBIAN_OS_RELEASE}"
                fun_wirte_log "${message_info_tag}正在安装必需组件......"
                apt-get install curl openssl bind-utils -y
            else
                fun_wirte_log "${message_warning_tag}当前系统是:${var_os_release},不支持自动安装必需组件,建议手动安装【curl、openssl、bind-utils】"
            fi
            if [[ -f "/usr/bin/curl" ]]; then
                var_is_installed_curl=true
            else
                var_is_installed_curl=false
                fun_wirte_log "${message_error_tag}curl组件自动安装失败!可能会影响到程序运行,建议手动安装!"
            fi
            if [[ -f "/usr/bin/openssl" ]]; then
                var_is_installed_openssl=true
            else
                var_is_installed_openssl=false
                fun_wirte_log "${message_error_tag}openssl组件自动安装失败!可能会影响到程序运行,建议手动安装!"
            fi
            if [[ -f "/usr/bin/nslookup" ]]; then
                var_is_installed_nslookup=true
            else
                var_is_installed_nslookup=false
                fun_wirte_log "${message_error_tag}nslokkup组件自动安装失败!可能会影响到程序运行,建议手动安装!"
            fi
        elif [[ -f "/usr/bin/sudo" ]]; then
            fun_wirte_log "${message_warning_tag}当前脚本未以root权限执行,正在尝试以sudo命令安装必需组件......"
           if [[ "${var_os_release}" = "${CENT_OS_RELEASE}" ]]; then
                fun_wirte_log "${message_info_tag}检测到当前系统发行版本为:${CENT_OS_RELEASE}"
                fun_wirte_log "${message_info_tag}正在以sudo安装必需组件......"
                sudo yum install curl openssl bind-utils -y
                elif [[ "${var_os_release}" = "${UBUNTU_OS_RELEASE}" ]];then
                fun_wirte_log "${message_info_tag}检测到当前系统发行版本为:${UBUNTU_OS_RELEASE}"
                fun_wirte_log "${message_info_tag}正在以sudo安装必需组件......"
                sudo apt-get install curl openssl bind-utils -y
                elif ["${var_os_release}" = "${DEBIAN_OS_RELEASE}" ]; then
                fun_wirte_log "${message_info_tag}检测到当前系统发行版本为:${DEBIAN_OS_RELEASE}"
                fun_wirte_log "${message_info_tag}正在以sudo安装必需组件......"
                sudo apt-get install curl openssl bind-utils -y
            else
                fun_wirte_log "${message_warning_tag}当前系统是:${var_os_release},不支持自动安装必需组件,建议手动安装【curl、openssl、bind-utils】"
            fi
        else
            fun_wirte_log "${message_error_tag}系统缺少必需组件且无法自动安装,建议手动安装."
        fi
    fi
}

# 检测配置文件
function fun_check_config_file(){
    fun_setting_file_save_dir
    if [[ -f "${CONFIG_FILE_PATH}" ]]; then
       fun_wirte_log "${message_info_tag}检测到配置文件,自动加载现有配置信息。可通过菜单选项【恢复出厂设置】重置."
        #加载配置文件
        source ${CONFIG_FILE_PATH}
        if [[ "${var_first_level_domain}" = "" ]] || [[ "${var_second_level_domain}" = "" ]] || [[ "${var_domain_ttl}" = "" ]] \
		|| [[ "${var_domain_line}" = "" ]] \
        || [[ "${var_access_key_id}" = "" ]] || [[ "${var_access_key_secret}" = "" ]] || [[ "${var_local_wan_ip}" = "" ]] \
        || [[ "${var_domain_server_ip}" = "" ]] || [[ "${var_check_online_url}" = "" ]] || [[ "${var_check_online_retry_times}" = "" ]] \
        || [[ "${var_aliyun_ddns_api_host}" = "" ]] \
        || [[ "${var_enable_message_push}" = true && "${var_push_message_access_token}" = "" && "${var_push_message_secret}" = "" ]] \
        || [[ "${var_check_online_url}" = "" ]] \
        || [[ "${var_domain_record_type}" = "" ]] \
        || [[ "${var_check_online_retry_times}" = "" ]] ; then
            fun_wirte_log "${message_error_tag}配置文件有误,请检查配置文件,建议清理后重新配置!程序退出执行."
            exit 1
        fi
        var_is_exist_config_file=true
    else
        var_is_exist_config_file=fasle
    fi
}

# 设置配置文件
function fun_set_config(){
    # 检测外网畅通ping等域名地址,默认:www.baidu.com
    if [[ "${var_check_online_url}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_check_online_url]请输入外网检测Ping地址:"
        read -p "(默认:www.baidu.com,如有疑问请输入“-h”查看帮助):" var_check_online_url
        [[ "${var_check_online_url}" = "-h" ]] && fun_help_document "var_check_online_url" && echo -e "${message_info_tag}[var_check_online_url]请输入外网检测Ping地址:" && read -p "(默认:www.baidu.com):" var_check_online_url
        [[ -z "${var_check_online_url}" ]] && echo -e "${message_info_tag}输入为空值,已设置为:“www.baidu.com”" && var_check_online_url="www.baidu.com"
    fi
     # 检测外网畅通失败重试次数,默认:3
    if [[ "${var_check_online_retry_times}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_check_online_retry_times]请输入外网检测失败后重试次数:"
        read -p "(默认:3,如有疑问请输入“-h”查看帮助):" var_check_online_retry_times
        [[ "${var_check_online_retry_times}" = "-h" ]] && fun_help_document "var_check_online_retry_times" && echo -e "${message_info_tag}[var_check_online_retry_times]请输入外网检测失败后重试次数:" && read -p "(默认:3):" var_check_online_retry_times
        [[ -z "${var_check_online_retry_times}" ]] && echo -e "${message_info_tag}输入为空值,已设置为:“3”" && var_check_online_retry_times=3
    fi
    # 一级域名
    if [[ "${var_first_level_domain}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_first_level_domain]请输入一级域名(示例 demo.com)${color_red_start}(*)${color_end}"
        read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_first_level_domain
        [[ "${var_first_level_domain}" = "-h" ]] && fun_help_document "var_first_level_domain" && echo -e "${message_info_tag}[var_first_level_domain]请输入一级域名 (示例 demo.com)" && read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_first_level_domain
        while [[ "${var_first_level_domain}" = "" || "${var_first_level_domain}" = "-h" ]]
        do
            if [[ "${var_first_level_domain}" = "" ]]; then
                echo -e "${message_error_tag}此项不可为空,请重新输入!"
                echo -e "${message_info_tag}[var_first_level_domain]请输入一级域名(示例 demo.com)${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_first_level_domain
                elif [[ "${var_first_level_domain}" = "-h"  ]]; then
                fun_help_document "var_first_level_domain"
                echo -e "${message_info_tag}[var_first_level_domain]请输入一级域名(示例 demo.com)${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_first_level_domain
            fi
        done
    fi
    # 二级域名
    if [[ "${var_second_level_domain}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_second_level_domain]请输入二级域名(示例 test)${color_red_start}(*)${color_end}"
        read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_second_level_domain
        [[ "${var_second_level_domain}" = "-h" ]] && fun_help_document "var_second_level_domain" && echo -e "${message_info_tag}[var_second_level_domain]请输入二级域名 (示例 test)" && read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_second_level_domain
        while [[ "${var_second_level_domain}" = "" || "${var_second_level_domain}" = "-h" ]]
        do
            if [[ "${var_second_level_domain}" = "" ]]; then
                echo -e "${message_error_tag}此项不可为空,请重新输入!"
                echo -e "${message_info_tag}[var_second_level_domain]请输入二级域名(示例 test)${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_second_level_domain
                elif [[ "${var_second_level_domain}" = "-h"  ]]; then
                fun_help_document "var_second_level_domain"
                echo -e "${message_info_tag}[var_second_level_domain]请输入二级域名(示例 test)${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_second_level_domain
            fi
        done
    fi
    # 域名解析类型：A、NS、MX、TXT、CNAME、SRV、AAAA、CAA、REDIRECT_URL、FORWARD_URL
    if [[ "${var_domain_record_type}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_domain_record_type]请输入解析类型(示例 A)${color_red_start}(*)${color_end}"
        read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_domain_record_type
        [[ "${var_domain_record_type}" = "-h" ]] && fun_help_document "var_domain_record_type" && echo -e "${message_info_tag}[var_domain_record_type]请输入解析类型(示例 A)" && read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_domain_record_type
        while [[ "${var_domain_record_type}" = "" || "${var_domain_record_type}" = "-h" ]]
        do
            if [[ "${var_domain_record_type}" = "" ]]; then
                echo -e "${message_error_tag}此项不可为空,请重新输入!"
                echo -e "${message_info_tag}[var_domain_record_type]请输入解析类型(示例 A)${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_domain_record_type
                elif [[ "${var_domain_record_type}" = "-h"  ]]; then
                fun_help_document "var_domain_record_type"
                echo -e "${message_info_tag}[var_domain_record_type]请输入解析类型(示例 A)${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_domain_record_type
            fi
        done
    fi
    # 域名生效时间,默认:600
    if [[ "${var_domain_ttl}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_domain_ttl]请输入域名解析记录生效时间(TTL Time-To-Live)秒:"
        read -p "(默认600,如有疑问请输入“-h”查看帮助):" var_domain_ttl
        [[ "${var_domain_ttl}" = "-h" ]] && fun_help_document "var_domain_ttl" && echo -e "${message_info_tag}[var_domain_ttl]请输入域名解析记录生效时间(TTL Time-To-Live)秒:" && read -p "(默认600):" var_domain_ttl
        [[ -z "${var_domain_ttl}" ]] && echo -e "${message_info_tag}输入为空值,已设置TTL值为:“600”" && var_domain_ttl="600"
    fi
	# 域名线路,默认:默认
    if [[ "${var_domain_line}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_domain_line]请输入域名解析线路:"
        read -p "(默认默认,如有疑问请输入“-h”查看帮助):" var_domain_line
        [[ "${var_domain_line}" = "-h" ]] && fun_help_document "var_domain_line" && echo -e "${message_info_tag}[var_domain_line]请输入域名解析线路:" && read -p "(默认-default):" var_domain_line
        [[ -z "${var_domain_line}" ]] && echo -e "${message_info_tag}输入为空值,已设置线路为:“default”" && var_domain_line="default"
    fi
    # 阿里云授权Key
    if [[ "${var_access_key_id}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_access_key_id]请输入阿里云AccessKeyId${color_red_start}(*)${color_end}"
        read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_access_key_id
        [[ "${var_access_key_id}" = "-h" ]] && fun_help_document "var_access_key_id" && echo -e "${message_info_tag}[var_access_key_id]请输入阿里云AccessKeyId" && read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_access_key_id
        while [[ "${var_access_key_id}" = "" || "${var_access_key_id}" = "-h" ]]
        do
            if [[ "${var_access_key_id}" = "" ]]; then
                echo -e "${message_error_tag}此项不可为空,请重新输入!"
                echo -e "${message_info_tag}[var_access_key_id]请输入阿里云AccessKeyId${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_access_key_id
                elif [[ "${var_access_key_id}" = "-h"  ]]; then
                fun_help_document "var_access_key_id"
                echo -e "${message_info_tag}[var_access_key_id]请输入阿里云AccessKeyId${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_access_key_id
            fi
        done
    fi
    # 阿里云授权Key Secret
    if [[ "${var_access_key_secret}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_access_key_secret]请输入阿里云AccessKeySecret${color_red_start}(*)${color_end}"
        read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_access_key_secret
        [[ "${var_access_key_secret}" = "-h" ]] && fun_help_document "var_access_key_secret" && echo -e "${message_info_tag}[var_access_key_secret]请输入阿里云AccessKeySecret" && read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_access_key_secret
        while [[ "${var_access_key_secret}" = "" || "${var_access_key_secret}" = "-h" ]]
        do
            if [[ "${var_access_key_secret}" = "" ]]; then
                echo -e "${message_error_tag}此项不可为空,请重新输入!"
                echo -e "${message_info_tag}[var_access_key_secret]请输入阿里云AccessKeySecret${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_access_key_secret
                elif [[ "${var_access_key_secret}" = "-h"  ]]; then
                fun_help_document "var_access_key_secret"
                echo -e "${message_info_tag}[var_access_key_secret]请输入阿里云AccessKeySecret${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_access_key_secret
            fi
        done
    fi
    # 获取本机外网IP的shell命令
    if [[ "${var_local_wan_ip}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_local_wan_ip]请输入获取本机外网IP使用的命令(默认：只支持ipv4)"
        read -p "(如有疑问请输入“-h”查看帮助):" var_local_wan_ip
        [[ "${var_local_wan_ip}" = "-h" ]] && fun_help_document "var_local_wan_ip" && echo -e "${message_info_tag}[var_local_wan_ip]请输入获取本机外网IP使用的命令(默认：只支持ipv4)" && read -p "(如有疑问请输入“-h”查看帮助):" var_local_wan_ip
        [[ -z "${var_local_wan_ip}" ]] && echo -e "${message_info_tag}输入为空值,已设置执行命令为:“curl -s http://members.3322.org/dyndns/getip”" && var_local_wan_ip="curl -s http://members.3322.org/dyndns/getip"
    fi
    # 获取ddns域名当前的解析记录的shell命令
    if [[ "${var_domain_server_ip}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_domain_server_ip]请输入获取域名当前解析记录的IP使用的命令(建议默认)"
        read -p "(如有疑问请输入“-h”查看帮助):" var_domain_server_ip
        [[ "${var_domain_server_ip}" = "-h" ]] && fun_help_document "var_domain_server_ip" && echo -e "${message_info_tag}[var_domain_server_ip]请输入获取域名当前解析记录的IP使用的命令(建议默认)" && read -p "(如有疑问请输入“-h”查看帮助):" var_domain_server_ip
        [[ -z "${var_domain_server_ip}" ]] && echo -e "${message_info_tag}输入为空值,已设置执行命令为:“nslookup“" && var_domain_server_ip="nslookup"
    fi

    # 是否启用消息推送,默认:false
    if [[ "${var_enable_message_push}" = false ]]; then
        echo -e "\n${message_info_tag}[var_enable_message_push]请输入是否启用消息通知(钉钉机器人)推送(请输入true或false):"
        read -p "(默认false,如有疑问请输入“-h”查看帮助):" var_enable_message_push
        [[ "${var_enable_message_push}" = "-h" ]] && fun_help_document "var_enable_message_push" && echo -e "${message_info_tag}[var_enable_message_push]请输入是否启用消息通知(钉钉机器人)推送(请输入true或false):" && read -p "(默认false):" var_enable_message_push
        [[ -z "${var_enable_message_push}" ]] && echo -e "${message_info_tag}输入为空值,已设置为:false" && var_enable_message_push=false
    fi

    # 消息通知发送token
    if [[ "${var_enable_message_push}" = true && "${var_push_message_access_token}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_push_message_access_token]请输入钉钉机器人推送access_token${color_red_start}(*)${color_end}"
        read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_push_message_access_token
        [[ "${var_push_message_access_token}" = "-h" ]] && fun_help_document "var_push_message_access_token" && echo -e "${message_info_tag}[var_push_message_access_token]请输入钉钉机器人推送access_token" && read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_push_message_access_token
        while [[ "${var_push_message_access_token}" = "" || "${var_push_message_access_token}" = "-h" ]]
        do
            if [[ "${var_push_message_access_token}" = "" ]]; then
                echo -e "${message_error_tag}此项不可为空,请重新输入!"
                echo -e "${message_info_tag}[var_push_message_access_token]请输入钉钉机器人推送access_token${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_push_message_access_token
                elif [[ "${var_push_message_access_token}" = "-h"  ]]; then
                fun_help_document "var_push_message_access_token"
                echo -e "${message_info_tag}[var_push_message_access_token]请输入钉钉机器人推送access_token${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_push_message_access_token
            fi
        done
    fi

    # 消息通知发送secret
    if [[ "${var_enable_message_push}" = true && "${var_push_message_secret}" = "" ]]; then
        echo -e "\n${message_info_tag}[var_push_message_secret]请输入钉钉机器人安全设置的加签(密钥)${color_red_start}(*)${color_end}"
        read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_push_message_secret
        [[ "${var_push_message_secret}" = "-h" ]] && fun_help_document "var_push_message_secret" && echo -e "${message_info_tag}[var_push_message_secret]请输入钉钉机器人安全设置的加签(密钥)" && read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_push_message_secret
        while [[ "${var_push_message_secret}" = "" || "${var_push_message_secret}" = "-h" ]]
        do
            if [[ "${var_push_message_secret}" = "" ]]; then
                echo -e "${message_error_tag}此项不可为空,请重新输入!"
                echo -e "${message_info_tag}[var_push_message_secret]请输入钉钉机器人安全设置的加签(密钥)${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_push_message_secret
                elif [[ "${var_push_message_secret}" = "-h"  ]]; then
                fun_help_document "var_push_message_secret"
                echo -e "${message_info_tag}[var_push_message_secret]请输入钉钉机器人安全设置的加签(密钥)${color_red_start}(*)${color_end}"
                read -p "(此项为必填,如有疑问请输入“-h”查看帮助):" var_push_message_secret
            fi
        done
    fi
}

# 保存配置文件
function fun_save_config(){
    # 写入配置文件
    fun_wirte_log "${message_info_tag}正在保存配置文件......"
    fun_setting_file_save_dir
    rm -f ${CONFIG_FILE_PATH}
    cat>${CONFIG_FILE_PATH}<<EOF
    var_check_online_url="${var_check_online_url}"
    var_check_online_retry_times=${var_check_online_retry_times}
    var_first_level_domain="${var_first_level_domain}"
    var_second_level_domain="${var_second_level_domain}"
    var_domain_record_type="${var_domain_record_type}"
    var_domain_ttl="${var_domain_ttl}"
    var_domain_line="${var_domain_line}"
    var_access_key_id="${var_access_key_id}"
    var_access_key_secret="${var_access_key_secret}"
    var_local_wan_ip="${var_local_wan_ip}"
    var_domain_server_ip="${var_domain_server_ip}"
    var_enable_message_push=${var_enable_message_push}
    var_push_message_access_token="${var_push_message_access_token}"
    var_push_message_secret="${var_push_message_secret}"

EOF
    fun_wirte_log "${message_success_tag}配置文件保存成功."
    fun_wirte_log "${message_info_tag}正在加载配置文件......"
    source ${CONFIG_FILE_PATH}
    fun_wirte_log "${message_success_tag}配置文件加载成功."
}

# 帮助文档
function fun_help_document(){
    help_type="$1"
    case "$help_type" in
        "var_first_level_domain")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]一级域名帮助-说明${color_end}
            此参数决定你要修改的DDNS域名中,一级域名的名称。
            请确保你要配置域名到DNS服务器已转入阿里云解析,也就是状态
            必须为“正常”或者“未设置解析”,不可以为“DNS服务器错误”等错误提示。
            例如:demo.com\n"
            var_first_level_domain=""
        ;;
        "var_second_level_domain")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]二级域名帮助-说明${color_end}
            此参数决定你要修改的DDNS域名中,二级域名的名称。
            二级域名与一级域名最终拼接成:test.demo.com
            例如:test\n"
            var_second_level_domain=""
        ;;
        # 域名解析类型：A、NS、MX、TXT、CNAME、SRV、AAAA、CAA、REDIRECT_URL、FORWARD_URL
        "var_domain_record_type")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]域名解析类型帮助-说明${color_end}
            此参数决定你解析域名的类型。
            可选值：A、NS、MX、TXT、CNAME、SRV、AAAA、CAA、REDIRECT_URL、FORWARD_URL
            每个值具体含义请移步：https://help.aliyun.com/document_detail/29805.html?spm=a2c4g.11186623.2.13.1e201cebcClxSe
            例如:A\n"
            var_domain_record_type=""
        ;;
        "var_domain_ttl")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]域名生效时间TTL-说明${color_end}
            此参数决定你要修改的DDNS记录中,TTL(Time-To-Line)时长。
            越短的TTL,DNS更新生效速度越快 (但也不是越快越好,因情况而定)
            免费版产品可设置为 (600-86400) (即10分钟-1天)
            收费版产品可根据所购买的云解析企业版产品配置设置为 (1-86400) (即1秒-1天)
            请免费版用户不要设置TTL低于600秒,会导致运行报错!\n"
            var_domain_ttl=""
        ;;
        "var_domain_line")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]域名解析线路-说明${color_end}
            此参数决定你要修改的DDNS记录中,解析线路，默认为default\n
				线路值	线路中文说明\n
				default	默认\n\t
				telecom	电信\n\t
				unicom	联通\n\t
				mobile	移动\n\t
				oversea	海外\n\t
				edu	教育网\n\t
				drpeng	鹏博士\n\t
				btvn	广电网\n"
            var_domain_line=""
        ;;
        "var_access_key_id")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]AccessKeyId-说明${color_end}
            此参数决定修改DDNS记录所需要用到的阿里云API信息 (AccessKeyId)。
            获取AccessKeydD和AccessKeySecret请移步:https://usercenter.console.aliyun.com/#/manage/ak
            ${color_red_start}注意:${color_end}请不要泄露你的AccessKeyId/AccessKeySecret给任何人!
            一旦他们获取了你的AccessKeyId/AccessKeySecret,将会直接拥有控制你阿里云账号的能力!"
            var_access_key_id=""
        ;;
        "var_access_key_secret")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]AccessKeySecret-说明${color_end}
            此参数决定修改DDNS记录所需要用到的阿里云API信息 (AccessKeySecret)。
            获取AccessKeydD和AccessKeySecret请移步:https://usercenter.console.aliyun.com/#/manage/ak
            ${color_red_start}注意:${color_end}请不要泄露你的AccessKeyId/AccessKeySecret给任何人!
            一旦他们获取了你的AccessKeyId/AccessKeySecret,将会直接拥有控制你阿里云账号的能力!"
            var_access_key_secret=""
        ;;
        "var_local_wan_ip")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]本地外网IP-说明${color_end}
            此参数决定如何获取到本机的IP地址。
            出于稳定性考虑,默认使用“curl -s http://members.3322.org/dyndns/getip”作为获取本地外网IP的方式,
            你也可以自定义获取IP方式。输入格式为需要执行的命令且不能出现双引号(\")。"
            var_local_wan_ip=""
        ;;
        "var_domain_server_ip")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]域名当前解析IP-说明${color_end}
            此参数决定如何获取到DDNS域名当前的解析记录。
            默认使用“nslookup”作为获取域名当前解析IP的方式,如不了解请使用默认方式。
            你也可以自定义获取域名当前解析IP方式。输入格式为需要执行的命令且不能出现双引号(\")。
            参考:“curl -s http://119.29.29.29/d?dn=\$var_second_level_domain.\$var_first_level_domain”"
            var_domain_server_ip=""
        ;;
         "var_enable_message_push")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]是否启用消息推送-说明${color_end}
            此参数决定是否启用消息通知控制。
            当脚本执行失败或成功将通过钉钉机器人通知。
            更多信息与配置请看https://ding-doc.dingtalk.com/doc#/serverapi2/qf2nxq官方文档。"
            var_enable_message_push=""
        ;;
         "var_push_message_access_token")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]消息推送密钥-说明${color_end}
            此参数为钉钉机器人推送消息的access_token。
            Webhook地址参数access_token=后的值。
            更多信息与配置请看https://ding-doc.dingtalk.com/doc#/serverapi2/qf2nxq官方文档。"
            var_push_message_access_token=""
        ;;
         "var_push_message_secret")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]加签密钥-说明${color_end}
            此参数为钉钉机器人安全设置中的加签密钥消息推送时签名使用
            在机器人设置-安全设置-加签即可找到，以SEC开头。
            更多信息与配置请看https://ding-doc.dingtalk.com/doc#/serverapi2/qf2nxq官方文档。"
            var_push_message_secret=""
        ;;
        "var_check_online_url")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]外网检测Ping地址-说明${color_end}
            此参数为检测当前脚本运行环境与外网是否畅通ping使用的地址
            如不了解，请使用默认值：www.baidu.com"
            var_check_online_url=""
        ;;
         "var_check_online_retry_times")
            echo -e "${message_info_tag}${color_green_start}[${help_type}]外网检测失败后重试次数-说明${color_end}
            此参数为检测当前脚本运行环境与外网是否畅通ping失败后重试次数
            如不了解，请使用默认值：3"
            var_check_online_retry_times=""
        ;;
        *)
            echo "无帮助文档"
    esac

}

# 获取当前时间戳
function fun_get_now_timestamp(){
    var_now_timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`
}

# 获取当前时间戳 毫秒
function fun_get_current_timestamp_ms(){
  echo "$((`date '+%s'`*1000+`date '+%N'`/1000000))"
}

# url编码
function fun_url_encode() {
    out=""
    while read -n1 c
    do
        case ${c} in
            [a-zA-Z0-9._-]) out="$out$c" ;;
            *) out="$out`printf '%%%02X' "'$c"`" ;;
        esac
    done
    echo -n ${out}
}

# url加密函数
function fun_get_url_encryption() {
    echo -n "$1" | fun_url_encode
}

#hmac-sha1 签名 usage: get_signature "签名算法" "加密串" "key"
function get_signature() {
    echo -ne "$2" | openssl dgst -$1 -hmac "$3" -binary | base64
}

# 生成uuid
function fun_get_uuid(){
    echo $(uuidgen | tr '[A-Z]' '[a-z]')
}

# json转换函数 fun_parse_json "json" "key_name"
function fun_parse_json(){
    echo "${1//\"/}" | grep "$2" |  sed "s/.*$2:\([^,}]*\).*/\1/"
}

# 发送请求 eg:fun_send_request "GET" "Action" "动态请求参数（看说明）" "控制是否打印请求响应信息：true false"
fun_send_request() {
    local args="$3"
    local message="$1&$(fun_get_url_encryption "/")&$(fun_get_url_encryption "$args")"
    local key="$var_access_key_secret&"
    local string_to_sign=$(get_signature "sha1" "$message" "$key")
    local signature=$(fun_get_url_encryption "$string_to_sign")
    local request_url="$var_aliyun_ddns_api_host/?$args&Signature=$signature"
    local response=$(curl -s ${request_url})

    fun_wirte_log "${message_info_tag}阿里云$2接口请求返回信息:${response},接口:${request_url}" false

    local code=$(fun_parse_json "$response" "Code")
    local message=$(fun_parse_json "$response" "Message")
	

    # 获取RecordId时需要过滤出id值 需要打印请求响应信息
    if [[ "$4" != "" || "$4" = true ]]; then
        echo $response
	else
	    if [[ "$message" = "" ]]; then
			local message="$response"
		fi
		if [[ "$code" = "" ]]; then
			fun_wirte_log "${message_success_tag}阿里云$2接口请求处理成功,返回消息:${message}"
		 else
			fun_wirte_log "${message_warning_tag}阿里云$2接口请求处理失败,返回代码:${code}消息:${message}"
		fi
    fi
}

# 获取域名解析记录Id正则
function fun_get_record_id_regx() {
    grep -Eo '"RecordId":"[0-9]+"' | cut -d':' -f2 | tr -d '"'
}

# 查询域名解析记录值请求
function fun_query_record_id_send() {
    local query_url="AccessKeyId=$var_access_key_id&Action=DescribeSubDomainRecords&DomainName=$var_first_level_domain&Format=json&SignatureMethod=HMAC-SHA1&SignatureNonce=$(fun_get_uuid)&SignatureVersion=1.0&SubDomain=$var_second_level_domain.$var_first_level_domain&Timestamp=$var_now_timestamp&Version=2015-01-09"
    fun_send_request "GET" "DescribeSubDomainRecords" ${query_url} true
}
# 更新域名解析记录值请求 fun_update_record "record_id"
function fun_update_record_send() {
    local query_url="AccessKeyId=$var_access_key_id&Action=UpdateDomainRecord&Format=json&Line=$var_domain_line&RR=$var_second_level_domain&RecordId=$1&SignatureMethod=HMAC-SHA1&SignatureNonce=$(fun_get_uuid)&SignatureVersion=1.0&TTL=$var_domain_ttl&Timestamp=$var_now_timestamp&Type=$var_domain_record_type&Value=$var_local_wan_ip&Version=2015-01-09"
    fun_send_request "GET" "UpdateDomainRecord" ${query_url}
}

# 更新域名解析记录值
function fun_update_record(){
    fun_wirte_log "${message_info_tag}正在更新域名解析记录值......"
    if [[ "${var_domain_record_id}" = "" ]]; then
        fun_wirte_log "${message_info_tag}正在获取record_id......"
        var_domain_record_id=`fun_query_record_id_send | fun_get_record_id_regx`
        if [[ "${var_domain_record_id}" = "" ]]; then
            fun_wirte_log "${message_warning_tag}获取record_id为空,可能没有获取到有效的解析记录(record_id=$var_domain_record_id)"
        else
            fun_wirte_log "${message_info_tag}获取到到record_id=$var_domain_record_id"
            fun_wirte_log "${message_info_tag}正在更新解析记录:[$var_second_level_domain.$var_first_level_domain]的ip为[$var_local_wan_ip]......"
            fun_update_record_send ${var_domain_record_id}
            fun_wirte_log "${message_info_tag}已经更新record_id=${var_domain_record_id}的记录"
        fi
    fi
    if [[ "${var_domain_record_id}" = "" ]]; then
        # 未能获取到domain_record_id
        fun_wirte_log "${message_fail_tag}域名解析记录更新失败!"
        fun_push_message "[失败]域名解析记录更新失败,获取的record_id为空，请检查域名解析记录是否存在或配置的阿里云access_key_id是否禁用或变更!"
        exit 1
    else
        # 更新成功
        fun_wirte_log "${message_success_tag}域名[$var_second_level_domain.$var_first_level_domain](新IP:$var_local_wan_ip)记录更新成功。"
        fun_push_message "[成功]域名[$var_second_level_domain.$var_first_level_domain](新IP:$var_local_wan_ip)记录更新成功。"
        exit 0
    fi
}

# 写日志到文件并显示 usage：fun_wirte_log "日志内容" “是否输出到console中：true（默认） false”
function fun_wirte_log(){
    fun_setting_file_save_dir
    log_content="$1"
    if [[ "$2" = "" || "$2" = true ]]; then
        echo -e "$log_content"
    fi
    # 处理样式 todo
    echo "${log_content}" >> ${LOG_FILE_PATH}
}

# 消息推送
function fun_push_message(){
    if [[ "${var_enable_message_push}" = true ]]; then
        fun_wirte_log "${message_info_tag}正在推送消息到钉钉......"
        fun_send_message_to_ding_ding "{'msgtype': 'text','text':{'content': '【域名解析服务-${NOW_DATE}】$1'}}"
    fi

}
#发送消息到钉钉 fun_send_message_to_ding_ding "内容"
function fun_send_message_to_ding_ding(){
        local timestamp_ms=$(fun_get_current_timestamp_ms)
        local str_to_sign="$timestamp_ms\n$var_push_message_secret";
        local sign=$(get_signature "sha256" "$str_to_sign" "$var_push_message_secret")
        local encode_sign=$(fun_get_url_encryption "$sign");
        local request_url="$var_push_message_api?access_token=$var_push_message_access_token&timestamp=$timestamp_ms&sign=$encode_sign"
        # 发送请求
        local response=$(curl -s "${request_url}" -H "Content-Type: application/json" -d "$1")
        fun_wirte_log "${message_info_tag}钉钉接口推送返回信息:${response}" false
        # json解析
        local errcode=$(fun_parse_json "$response" "errcode")
        local errmsg=$(fun_parse_json "$response" "errmsg")
        if [[ "$errcode" -eq "0" ]]; then
            fun_wirte_log "${message_success_tag}消息推送成功,返回消息:${errmsg}"
        else
           fun_wirte_log "${message_warning_tag}消息推送失败,返回消息:${errmsg}"
        fi
}

# 恢复出厂设置
function fun_restore_settings(){
    fun_setting_file_save_dir
    rm -f ${CONFIG_FILE_PATH}
    var_is_root_execute=false
    var_is_support_sudo=false
    var_first_level_domain=""
    var_second_level_domain=""
    var_domain_ttl=""
    var_domain_line=""
    var_access_key_id=""
    var_access_key_secret=""
    var_local_wan_ip=""
    var_domain_server_ip=""
    var_enable_message_push=false
    var_push_message_access_token=""
    var_push_message_secret=""
    var_domain_record_type=""
    fun_wirte_log "${message_success_tag}所有配置项重置成功!"
}

# 清除日志文件
function fun_clearn_logs(){
    fun_setting_file_save_dir
    rm -f ${LOG_FILE_PATH}
    echo -e "${message_success_tag}日志文件清理成功!"
}

# 主入口1 配置并运行
function main_fun_config_and_run(){
    fun_check_root
    fun_check_run_environment
    fun_install_run_environment
    fun_check_config_file
    fun_set_config
    fun_save_config
    fun_check_online
    fun_get_local_wan_ip
    fun_get_domain_server_ip
    fun_get_now_timestamp
    fun_is_wan_ip_and_domain_ip_same
    fun_update_record
    exit 0
}
# 主入口2 仅运行
function main_fun_only_run(){
    fun_check_config_file
    if [[ "${var_is_exist_config_file}" != true ]]; then
        fun_wirte_log "${message_error_tag}未检测到配置文件,请直接运行程序配置!"
        exit 1
    fi
    fun_check_run_environment
    fun_install_run_environment
    fun_check_online
    fun_get_local_wan_ip
    fun_get_domain_server_ip
    fun_get_now_timestamp
    fun_is_wan_ip_and_domain_ip_same
    fun_update_record
    exit 0
}

# 主入口3 仅配置
function main_fun_only_config(){
    fun_check_root
    fun_check_run_environment
    fun_install_run_environment
    fun_check_config_file
    fun_set_config
    fun_save_config
    fun_wirte_log "${message_success_tag}配置完成!"
    exit 0
}
# 主入口4 恢复出厂设置
function main_fun_restore_settings(){
    fun_wirte_log "${message_info_tag}正在恢复出厂设置......"
    fun_restore_settings
    fun_wirte_log "${message_success_tag}恢复出厂设置成功,可重新运行程序进行配置。"
    exit 0
}

# 主入口5 清理日志文件
function main_fun_clearn_logs(){
    echo -e "${message_info_tag}正在清理日志文件......"
    fun_clearn_logs
    exit 0
}

# 显示程序说明和版本信息
function main_fun_show_version(){
    fun_show_version_info
    exit 0
}

# 根据输入参数执行对应函数
case "$1" in
    "-config -run")
        main_fun_config_and_run
    ;;
    "-run")
        main_fun_only_run
    ;;
    "-config")
        main_fun_only_config
    ;;
    "-restore")
        main_fun_restore_settings
    ;;
    "-version")
        main_fun_show_version
    ;;
    "-clearn")
        main_fun_clearn_logs
    ;;
    *)
        echo -e "${color_blue_start}===阿里云域名动态IP自动解析小脚本===${color_end}
使用方法 (Usage):
aliyun-ddns.sh -config -run     配置并执行脚本
aliyun-ddns.sh -run             执行脚本（前提需要有配置文件）
aliyun-ddns.sh -config          仅配置信息
aliyun-ddns.sh -restore         恢复出厂设置（会清除配置文件等）
aliyun-ddns.sh -clearn          清理日志文件
aliyun-ddns.sh -version         显示脚本说明及版本信息
        "
    ;;
esac

echo -e "${message_info_tag}选择需要执行的功能"
echo -e "\n 1.配置并执行脚本 \n 2.仅配置 \n 3.仅执行脚本 \n 4.恢复出厂设置 \n 5.清理日志文件 \n 0.退出 \n"
read -p "请输入你的选择（输入数字）:" run_function

if [[ "${run_function}" == "1" ]]; then
    main_fun_config_and_run
    elif [[ "${run_function}" == "2" ]]; then
    main_fun_only_config
    elif [[ "${run_function}" == "3" ]]; then
    main_fun_only_run
    elif [[ "${run_function}" == "4" ]]; then
    main_fun_restore_settings
    elif [[ "${run_function}" == "5" ]]; then
    main_fun_clearn_logs
else
    exit 0
fi
