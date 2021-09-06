# 阿里云域名动态IP解析Shell小脚本
当你手里面有一个闲置的域名，有一个漂浮不定的外网ip，你又想在外网ip变更后自动解析到域名上，此情此景此脚本可能会帮上你。
# 更新日志
- 2020-09-29 支持IPV6解析（支持设置解析记录类型：A、NS、MX、TXT、CNAME、SRV、AAAA、CAA、REDIRECT_URL、FORWARD_URL）
- 2021-09-06 支持设置解析线路
---
## 使用步骤：
- 在阿里云域名管理中解析自己的域名
    - 记录类型：A
    - 主机记录：按你需要输入
    - 解析路线：默认（随你）
    - 记录值：随便输入一个Ip地址（运行脚本后会自动更新到正确的）
    - TTL值：10分钟
- 需要通过阿里云域名解析Api操作，所以需要申请阿里云的Acesskeys
    - 登录阿里云 控制台 https://account.aliyun.com/login/login.htm
    - 新建子账号（随你，用主账号也行）https://ram.console.aliyun.com/users
    - 创建新的AccessKey https://ram.console.aliyun.com/users/domian
    - 给子账号授权：权限管理-个人权限 权限策略名称：AliyunDNSFullAccess
- 运行自动解析域名脚本
    - git clone https://github.com/risfeng/aliyun-ddns-shell.git
    - 给aliyun-ddns.sh脚本赋可执行权：`chmod +x aliyun-ddns-shell/src/aliyun/aliyun-ddns.sh`
    - 运行脚本，根据提示进行配置（第一次运行需要配置）
    - 如需要使用钉钉自定义机器人推送成功失败消息，请新建自定义钉钉机器人，配置access_token和消息加签密钥
    - 脚本支持2种运行方式：
        - 直接运行脚本根据提示选择需要使用的功能
        ```
        > aliyun-ddns.sh (mac: > bash aliyun-ddns.sh)
        1.配置并执行脚本
        2.仅配置
        3.仅执行脚本
        4.恢复出厂设置
        5.清理日志文件
        0.退出
        ```
        - 带参数运行：
        ```
        aliyun-ddns.sh -config -run     配置并执行脚
        aliyun-ddns.sh -run             执行脚本（前提需要有配置文件）
        aliyun-ddns.sh -config          仅配置信息
        aliyun-ddns.sh -restore         恢复出厂设置（会清除配置文件等）
        aliyun-ddns.sh -clearn          清理日志文件
        aliyun-ddns.sh -version         显示脚本说明及版本信息
        ```
- 实时监听外网IP变更后自动解析到域名
    - 利用定时任务服务：crond
    - 检测是否安装：`crond -V` 有输出版本号即已安装。
    - 如未安装：`yum install vixie-cron crontabs -y` 如有疑问请自行查找资料解决
    - crond服务常用命令
    ```
    service crond status   # 查看服务运行状态  
    service crond start    # 启动服务
    service crond stop     # 停止服务 
    service crond restart  # 重启服务  
    service crond reload   # 不中断服务,重新载入配置 
    crontab -e             # 编辑配置文件 
    crontab -l             # 列出某个用户的任务计划
    ```
    - 配置任务定时任务
        - 建议不要把任务执行频率设置小于等10，因为域名解析记录生效时间最短理论上是10分钟，往往都会超过10分，建议15-20分钟。
        - 开始配置
        ```
        crontab -e
        # 按i进入标记模式
        # 输入：
        */20 * * * * XXXXXX/aliyun-ddns-shell/src/aliyun/aliyun-ddns.sh -run >> XXXX/aliyun-ddns-shell/src/aliyun/crontab-log.log
        # 说明：
        # */20 * * * * ：每20分钟执行一次 需要执行都脚本全路径 >> 执行日志输出位置全路径
        # 按 esc 后 输入:wq 回车 保存并退出
        ```
        - 重新加载配置：`service crond reload`
        - 注意观察任务是否成功执行，如有疑问请自行百度
## 效果图
![启动页面](https://raw.githubusercontent.com/risfeng/aliyun-ddns-shell/master/src/aliyun/screenshot/ss1.jpg)
![配置页面](https://raw.githubusercontent.com/risfeng/aliyun-ddns-shell/master/src/aliyun/screenshot/ss2.jpg)
![运行页面](https://raw.githubusercontent.com/risfeng/aliyun-ddns-shell/master/src/aliyun/screenshot/ss3.jpg)
## 欢迎star给予支持
