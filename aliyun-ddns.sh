#!/bin/bash

#############################################################
# Aliyun Domain DNS Update  Script v1.0.0
#
# Dynamic DNS  Update Using Aliyun API
#
# Author: risfeng<risfeng@gamil.com>
# GitHub: https://github.com/risfeng/aliyun-ddns-shell
#
# Usage: please refer to https://github.com/risfeng/aliyun-ddns-shell/blob/master/README.md
#
#############################################################

#阿里云基础配置
access_key_id=LTA******************r
access_key_secret=Yx*******************KE

#定义是否ping通标识
is_ping=false

#定义一个函数检测ping 成功一次则标识通过
function test_ping() {
    if ping -c 1 $ip >/dev/null; then
        echo "ping" $ip "success!"
        is_ping=true
        continue
    fi
}

#将ping 的域名放到数组
PING_DOMAIN_LIST="baidu.com1"

#遍历ping域名列表 最多检测三次ping成功返回true 反之返回 false
for ip in $PING_DOMAIN_LIST; do
    echo "ping" $ip "1 times..."
    test_ping
    echo "ping" $ip "2 times..."
    test_ping
    echo "ping" $ip "3 times..."
    test_ping
    echo "ping" $ip "fail!"
    is_ping=false
done

#获取当前运行环境的外网IP
wan_ip=""
function get_wan_ip() {
    wan_ip=$(curl -s http://members.3322.org/dyndns/getip)
    echo "get wan ip : "$wan_ip
}

#hmac-sha1 签名
function string_to_sign() {
    #todo
    return $string | openssl dgst -hmac $key -sha1 -binary | base64
}

#调用阿里云DNS更新接口
function update_doamin_dns() {
    get_wan_ip
    #todo:
    sign=$(string_to_sign "" "")
    echo "qim==>>>>>  "$sign
    echo "update domian dns success!!"
}

#主逻辑
if $is_ping; then
    echo "ping success! current wan ip no change,no need update domain dns."
else
    echo "ping fail!"
    echo "update domian dns start ....."
    update_doamin_dns
    echo "Update domian dns end ....."
fi
