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

#加载配置信息
source ./config

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

#遍历ping域名列表 最多检测三次ping成功返回true 反之返回 false
for ip in $ping_domain_list; do
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

#计算签名的字符串
function string_to_sign() {
    #todo::
    echo 'todo:::'
}

#hmac-sha1 签名
function get_signature() {
    echo -n $1 | openssl dgst -sha1 -hmac $2 -binary | base64
}

#调用阿里云DNS更新接口
function update_doamin_dns() {
    get_wan_ip
    #todo:
    echo "读取配置文件ApiHost=" $api_host

    #签名Key $access_key_secret'&'
    signature_key='testsecret&'

    #签名消息 todo:::
    signature_message="GET&%2F&AccessKeyId%3Dtestid%26Action%3DDescribeDomainRecords%26DomainName%3Dexample.com%26Format%3DXML%26SignatureMethod%3DHMAC-SHA1%26SignatureNonce%3Df59ed6a9-83fc-473b-9cc6-99c95df3856e%26SignatureVersion%3D1.0%26Timestamp%3D2016-03-24T16%253A41%253A54Z%26Version%3D2015-01-09"

    signature=$(get_signature $signature_message $signature_key)

    echo "============================>>>>>  "$signature
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
