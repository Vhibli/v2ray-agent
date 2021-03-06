#!/usr/bin/env bash

installType='yum -y install'
removeType='yum -y remove'
upgrade="yum -y update"
echoType='echo -e'

# echo颜色方法
echoContent(){
    case $1 in
        # 红色
        "red")
            ${echoType} "\033[31m$2 \033[0m"
        ;;
        # 天蓝色
        "skyBlue")
            ${echoType} "\033[36m$2 \033[0m"
        ;;
        # 绿色
        "green")
            ${echoType} "\033[32m$2 \033[0m"
        ;;
        # 白色
        "white")
            ${echoType} "\033[37m$2 \033[0m"
        ;;
        "magenta")
            ${echoType} "\033[31m$2 \033[0m"
        ;;
        "skyBlue")
            ${echoType} "\033[36m$2 \033[0m"
        ;;
        # 黄色
        "yellow")
            ${echoType} "\033[33m$2 \033[0m"
        ;;
    esac
}
fixBug(){
    if [[ "${release}" = "ubuntu" ]]
    then
        cd /var/lib/dpkg/

    fi
}
# 安装工具包
installTools(){
    # echo "export LC_ALL=en_US.UTF-8"  >>  /etc/profile
    # source /etc/profile
    echoContent yellow "删除Nginx、V2Ray、acme"
    if [[ ! -z `find /usr/sbin/ -name nginx` ]]
    then
        if [[ ! -z `ps -ef|grep nginx|grep -v grep`  ]]
        then
            nginx -s stop
        fi

        if [[ "${release}" = "ubuntu" ]] || [[ "${release}" = "debian" ]]
        then
            dpkg --get-selections | grep nginx|awk '{print $1}'|xargs sudo apt --purge remove -y > /dev/null
        else
            removeLog=`${removeType} nginx`
        fi
        rm -rf /etc/nginx/nginx.conf
        rm -rf /usr/share/nginx/html.zip
    fi

    if [[ ! -z `find /usr/bin/ -name "v2ray*"` ]]
    then
        if [[ ! -z `ps -ef|grep v2ray|grep -v grep`  ]]
        then
            ps -ef|grep v2ray|grep -v grep|awk '{print $2}'|xargs kill -9
        fi
        rm -rf  /usr/bin/v2ray
    fi

    if [[ ! -z `cat /root/.bashrc|grep -n acme` ]]
    then
        acmeBashrcLine=`cat /root/.bashrc|grep -n acme|awk -F "[:]" '{print $1}'|head -1`
        sed -i "${acmeBashrcLine}d" /root/.bashrc
    fi
    rm -rf /etc/systemd/system/v2ray.service
    systemctl daemon-reload

    rm -rf ~/.acme.sh > /dev/null
    echoContent green "  删除完成"

    echoContent skyBlue "检查、安装工具包："

    echoContent green "  更新中，请等待"
    ${upgrade} > /dev/null
    rm -rf /var/run/yum.pid
    echoContent green "更新完毕"

    echoContent yellow "检查、安装wget--->"
    progressTool wget &
    ${installType} wget > /dev/null

    echoContent yellow "检查、安装unzip--->"
    progressTool unzip &
    ${installType} unzip > /dev/null

    # echoContent yellow "检查、安装qrencode--->"
    # progressTool qrencode &
    # ${installType} qrencode > /dev/null

    echoContent yellow "检查、安装socat--->"
    progressTool socat &
    ${installType} socat > /dev/null

    echoContent yellow "检查、安装crontabs--->"
    progressTool crontabs &
    if [[ "${release}" = "ubuntu" ]]
    then
        ${installType} cron > /dev/null
    else
        ${installType} crontabs > /dev/null
    fi

    echoContent yellow "检查、安装jq--->"
    progressTool jq &
    ${installType} jq > /dev/null

    # echoContent skyBlue "检查、安装bind-utils--->"
    # progressTool bind-utils
    # 关闭防火墙

}
# 安装Nginx tls证书
installNginx(){
    echoContent skyBlue "检查、安装Nginx、TLS："
    echoContent yellow  "请输入要配置的域名 例：worker.v2ray-agent.com --->"
    rm -rf /etc/nginx/nginx.conf
    read domain
    if [[ -z ${domain} ]]
    then
        echoContent red "  域名不可为空--->"
        installNginx
    else
        # 安装nginx
        echoContent yellow "  检查、安装Nginx--->"
        progressTool nginx &
        ${installType} nginx > /dev/null

        if [[ ! -z `ps -ef|grep -v grep|grep nginx` ]]
        then
            nginx -s stop
        fi

        # 修改配置
        echoContent yellow "修改配置文件--->"


        touch /etc/nginx/conf.d/alone.conf
        # installLine=`cat /etc/nginx/nginx.conf|grep -n root|awk -F "[:]" '{print $1+1}'|head -1`
        # ${installLine}
        # ${domain}
        echo "server {listen 80;server_name ${domain};root /usr/share/nginx/html;location ~ /.well-known {allow all;}location /test {return 200 'fjkvymb6len';}}" > /etc/nginx/conf.d/alone.conf
        # sed -i "1i 1" /etc/nginx/conf.d/alone.conf
        # installLine=`expr ${installLine} + 1`
        # sed -i "${installLine}i location /test {return 200 'fjkvymb6len';}" /etc/nginx/nginx.conf
        # 启动nginx
        nginx

        # 测试nginx
        echoContent yellow "检查Nginx是否正常访问，请等待--->"
        # ${domain}
        domainResult=`curl -s ${domain}/test|grep fjkvymb6len`
        if [[ ! -z ${domainResult} ]]
        then
            echoContent green "  Nginx访问成功--->"
            nginx -s stop
            installTLS ${domain}
            installV2Ray ${domain}
        else
            echoContent red "    无法正常访问服务器，请检查域名的DNS解析是否正确--->"
            exit 0;
        fi
    fi
}
# 安装TLS
installTLS(){

    if [[ -z `find /tmp -name "$1*"` ]]
    then
        echoContent yellow "安装TLS证书--->"
        echoContent yellow "  安装acme--->"
        curl -s https://get.acme.sh | sh > /dev/null
        echoContent green  "  acme安装完毕--->"
        echoContent yellow "生成TLS证书中，请等待--->"
        sudo ~/.acme.sh/acme.sh --issue -d $1 --standalone -k ec-256 >/dev/null
        ~/.acme.sh/acme.sh --installcert -d $1 --fullchainpath /etc/nginx/$1.crt --keypath /etc/nginx/$1.key --ecc >/dev/null
        if [[ -z `cat /etc/nginx/$1.crt` ]]
        then
            echoContent red "    TLS安装失败，请检查acme日志--->"
            exit 0
        elif [[ -z `cat /etc/nginx/$1.key` ]]
        then
            echoContent red "    TLS安装失败，请检查acme日志--->"
            exit 0
        fi
        echoContent green "  TLS生成成功--->"
        mkdir -p /tmp/tls
        cp -R /etc/nginx/$1.crt /tmp/tls/$1.crt
        cp -R /etc/nginx/$1.key /tmp/tls/$1.key
        echoContent green "  TLS证书备份成功，证书位置：/tmp/tls--->"
    elif  [[ -z `cat /tmp/tls/$1.crt` ]] || [[ -z `cat /tmp/tls/$1.key` ]]
    then
        echoContent red "    检测到错误证书，需重新生成，重新生成中--->"
        rm -rf /tmp/tls
        installTLS $1
    else
        echoContent yellow "检测到备份证书，如需重新生成，请执行 【rm -rf /tmp/tls】，然后重新执行脚本--->"
        cp -R /tmp/tls/$1.crt /etc/nginx/$1.crt
        cp -R /tmp/tls/$1.key /etc/nginx/$1.key
    fi

    # nginxInstallLine=`cat /etc/nginx/nginx.conf|grep -n "}"|awk -F "[:]" 'END{print $1-1}'`
    # sed -i "${nginxInstallLine}i server {listen 443 ssl;server_name $1;root /usr/share/nginx/html;ssl_certificate /etc/nginx/$1.crt;ssl_certificate_key /etc/nginx/$1.key;ssl_protocols TLSv1 TLSv1.1 TLSv1.2;ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;ssl_prefer_server_ciphers on;location / {} location /alone { proxy_redirect off;proxy_pass http://127.0.0.1:31299;proxy_http_version 1.1;proxy_set_header Upgrade \$http_upgrade;proxy_set_header Connection "upgrade";proxy_set_header X-Real-IP \$remote_addr;proxy_set_header Host \$host;proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;}}" /etc/nginx/nginx.conf
    echo "server {listen 443 ssl;server_name $1;root /usr/share/nginx/html;ssl_certificate /etc/nginx/$1.crt;ssl_certificate_key /etc/nginx/$1.key;ssl_protocols TLSv1 TLSv1.1 TLSv1.2;ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;ssl_prefer_server_ciphers on;location / {} location /alone { proxy_redirect off;proxy_pass http://127.0.0.1:31299;proxy_http_version 1.1;proxy_set_header Upgrade \$http_upgrade;proxy_set_header Connection "upgrade";proxy_set_header X-Real-IP \$remote_addr;proxy_set_header Host \$host;proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;}}" > /etc/nginx/conf.d/alone.conf
    rm -rf /usr/share/nginx/html
    wget -q -P /usr/share/nginx https://raw.githubusercontent.com/mack-a/v2ray-agent/master/blog/unable/html.zip >> /dev/null
    unzip  /usr/share/nginx/html.zip -d /usr/share/nginx/html > /dev/null
    nginx
    if [[ -z `ps -ef|grep -v grep|grep nginx` ]]
    then
        echoContent red "  Nginx启动失败，请检查日志--->"
        exit 0
    fi
    echoContent green "  Nginx启动成功，TLS配置成功--->"
}
# V2Ray
installV2Ray(){
    if [[ -z `find /tmp -name "v2ray*"` ]]
    then
        if [[ -z `find /usr/bin/ -name "v2ray*"` ]]
        then
            echoContent yellow "安装V2Ray--->"
            version=`curl -s https://github.com/v2ray/v2ray-core/releases|grep /v2ray/v2ray-core/releases/tag/|head -1|awk -F "[/]" '{print $6}'|awk -F "[V]" '{print $2}'|awk -F "[<]" '{print $1}'`
            mkdir -p /tmp/v2ray
            mkdir -p /usr/bin/v2ray/
            wget -q -P /tmp/v2ray https://github.com/v2ray/v2ray-core/releases/download/v${version}/v2ray-linux-64.zip
            unzip /tmp/v2ray/v2ray-linux-64.zip -d /tmp/v2ray > /dev/null
            cp /tmp/v2ray/v2ray /usr/bin/v2ray/
            cp /tmp/v2ray/v2ctl /usr/bin/v2ray/
            rm -rf /tmp/v2ray/v2ray-linux-64.zip
        fi
        echoContent green "  V2Ray安装成功--->"
    else
         echoContent yellow "检测到V2Ray安装程序，如需重新安装，请执行【rm -rf /tmp/v2ray】,然后重新执行脚本--->"
         mkdir -p /usr/bin/v2ray/
         cp /tmp/v2ray/v2ray /usr/bin/v2ray/ && cp /tmp/v2ray/v2ctl /usr/bin/v2ray/
    fi
    installV2RayService
    initV2RayConfig
    systemctl daemon-reload
    systemctl enable v2ray.service
    systemctl start  v2ray.service
    if [[ -z `ps -ef|grep v2ray|grep -v grep` ]]
    then
        echoContent red "    V2Ray启动失败，请检查日志后，重新执行脚本--->"
        exit 0;
    fi
    echoContent green "  V2Ray启动成功--->"
    echoContent yellow "V2Ray日志目录："
    echoContent green "  access:  /tmp/v2ray/v2ray_access_ws_tls.log"
    echoContent green "  error:  /tmp/v2ray/v2ray_error_ws_tls.log"

    # 验证整个服务是否可用
    echoContent yellow "验证服务是否可用--->"
    if [[ `curl -s -L https://$1/alone` = "Bad Request" ]]
    then
        echoContent green "  服务可用--->"
    else
        echoContent red "  服务不可用，请检查Cloudflare->域名->SSL/TLS->Overview->Your SSL/TLS encryption mode is 是否是Full--->"
        exit 0
    fi
    echoContent yellow "客户端链接--->"
    qrEncode $1
    echoContent yellow "监听V2Ray日志，如有日志出现则证明线路可用，Ctrl+c停止--->"
    tail -f /tmp/v2ray/v2ray_access_ws_tls.log
}
# 开机自启
installV2RayService(){
    echoContent skyBlue "  配置V2Ray开机自启--->"
    rm -rf /etc/systemd/system/v2ray.service
    touch /etc/systemd/system/v2ray.service

    echo '[Unit]' >> /etc/systemd/system/v2ray.service
    echo 'Description=V2Ray - A unified platform for anti-censorship' >> /etc/systemd/system/v2ray.service
    echo 'Documentation=https://v2ray.com https://guide.v2fly.org' >> /etc/systemd/system/v2ray.service
    echo 'After=network.target nss-lookup.target' >> /etc/systemd/system/v2ray.service
    echo 'Wants=network-online.target' >> /etc/systemd/system/v2ray.service
    echo '' >> /etc/systemd/system/v2ray.service
    echo '[Service]' >> /etc/systemd/system/v2ray.service
    echo 'Type=simple' >> /etc/systemd/system/v2ray.service
    echo 'User=root' >> /etc/systemd/system/v2ray.service
    echo 'CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW' >> /etc/systemd/system/v2ray.service
    echo 'NoNewPrivileges=yes' >> /etc/systemd/system/v2ray.service
    echo 'ExecStart=/usr/bin/v2ray/v2ray -config /etc/v2ray/config.json' >> /etc/systemd/system/v2ray.service
    echo 'Restart=on-failure' >> /etc/systemd/system/v2ray.service
    echo 'RestartPreventExitStatus=23' >> /etc/systemd/system/v2ray.service
    echo '' >> /etc/systemd/system/v2ray.service
    echo '' >> /etc/systemd/system/v2ray.service
    echo '[Install]' >> /etc/systemd/system/v2ray.service
    echo 'WantedBy=multi-user.target' >> /etc/systemd/system/v2ray.service
    echoContent green "  配置V2Ray开机自启成功--->"
}
# 初始化V2Ray 配置文件
initV2RayConfig(){
    mkdir -p /etc/v2ray/
    touch /etc/v2ray/config.json
    uuid=`/usr/bin/v2ray/v2ctl uuid`
    echo '{"log":{"access":"/tmp/v2ray/v2ray_access_ws_tls.log","error":"/tmp/v2ray/v2ray_error_ws_tls.log","loglevel":"debug"},"stats":{},"api":{"services":["StatsService"],"tag":"api"},"policy":{"levels":{"1":{"handshake":4,"connIdle":300,"uplinkOnly":2,"downlinkOnly":5,"statsUserUplink":false,"statsUserDownlink":false}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}},"allocate":{"strategy":"always","refresh":5,"concurrency":3},"inbounds":[{"port":31299,"protocol":"vmess","settings":{"clients":[{"id":"654765fe-5fb1-271f-7c3f-18ed82827f72","alterId":64,"level":1,"email":"test@v2ray.com"}]},"streamSettings":{"network":"ws","wsSettings":{"path":"/alone"}}}],"outbounds":[{"protocol":"freedom","settings":{"OutboundConfigurationObject":{"domainStrategy":"AsIs","userLevel":0}}}],"routing":{"settings":{"rules":[{"inboundTag":["api"],"outboundTag":"api","type":"field"}]},"strategy":"rules"},"dns":{"servers":["8.8.8.8","8.8.4.4"],"tag":"dns_inbound"}}' > /etc/v2ray/config.json
    sed -i "s/654765fe-5fb1-271f-7c3f-18ed82827f72/${uuid}/g" `grep 654765fe-5fb1-271f-7c3f-18ed82827f72 -rl /etc/v2ray/config.json`
}
qrEncode(){
    user=`cat /etc/v2ray/config.json|jq .inbounds[0]`
    ps="$1"
    id=`echo ${user}|jq .settings.clients[0].id`
    aid=`echo ${user}|jq .settings.clients[0].alterId`
    host="$1"
    path=`echo ${user}|jq .streamSettings.wsSettings.path`
    qrCodeBase64=`echo -n '{"port":"443","ps":"'${ps}'","tls":"tls","id":'"${id}"',"aid":"64","v":"2","host":"'${host}'","type":"none","path":'${path}',"net":"ws","add":"'${host}'"}'|sed 's#/#\\\/#g'|base64`
    qrCodeBase64=`echo ${qrCodeBase64}|sed 's/ //g'`
    echoContent green "  通用链接--->"
    echoContent green vmess://${qrCodeBase64}
    # | qrencode -t UTF8
    # echo ${qrCodeBase64}
}
# 查看dns解析ip
checkDNS(){
    echo '' > /tmp/pingLog
    ping -c 3 $1 >> /tmp/pingLog
    serverStatus=`ping -c 3 $1|head -1|awk -F "[service]" '{print $1}'`
    pingLog=`ping -c 3 $1|tail -n 5|head -1|awk -F "[ ]" '{print $4 $7}'`
    echoContent skyBlue "DNS解析ip:"${pingLog}
}
# 查看本机ip
checkDomainIP(){
    currentIP=`curl -s ifconfig.me|awk '{print}'`
    echoContent skyBlue ${currentIP}
}
progressTool(){
    #
    i=0
    toolName=$1
    sp='/-\|'
    n=${#sp}
    printf ' '
    if [[ "${toolName}" = "crontabs" ]]
    then
        toolName="crontab"
    fi
    while true; do
        status=
        if [[ -z `find /usr/bin/ -name ${toolName}` ]] && [[ -z `find /usr/sbin/ -name ${toolName}` ]]
        then
            printf '\b%s' "${sp:i++%n:1}"
        else
            break;
        fi
        sleep 0.1
    done
    echoContent green "  $1已安装--->"
}

init(){

    echoContent white "==============================="
    echoContent skyBlue "欢迎使用v2ray-agent，Cloudflare+WS+TLS+Nginx自动化脚本，如有使用问题欢迎加入TG群【https://t.me/v2rayAgent】，Github【https://github.com/mack-a/v2ray-agent】"
    echoContent yellow "注意事项："
    echoContent red "    1.脚本适合新机器，会删除、卸载已经安装的应用，包括V2Ray、Nginx"
    echoContent red "    2.如果有使用此脚本生成TLS证书、V2Ray，会继续使用上次生成、安装的内容。"
    echoContent red "    3.脚本会检查并安装工具包"
    echoContent red "    4.会自动关闭防火墙"
    echoContent white "==============================="
    echoContent red "请输入【1】确认执行脚本、Ctrl+c退出脚本："
    read installStatus
    if [[ "${installStatus}" = "1" ]]
    then
        installTools
        installNginx
    else
        echoContent yellow "输入有误请重新输入--->\n"
        init
    fi
}
checkSystem(){

	if [[ ! -z `find /etc -name "redhat-release"` ]] || [[ ! -z `cat /proc/version | grep -i "centos" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "red hat" | grep -v grep ` ]] || [[ ! -z `cat /proc/version | grep -i "redhat" | grep -v grep ` ]]
	then
		release="centos"
		installType='yum -y install'
		removeType='yum -y remove'
		upgrade="yum update -y"
	elif [[ ! -z `cat /etc/issue | grep -i "debian" | grep -v grep` ]] || [[ ! -z `cat /proc/version | grep -i "debian" | grep -v grep` ]]
    then
		release="debian"
		installType='apt -y install'
		upgrade="apt update -y"
		removeType='apt -y autoremove'
	elif [[ ! -z `cat /etc/issue | grep -i "ubuntu" | grep -v grep` ]] || [[ ! -z `cat /proc/version | grep -i "ubuntu" | grep -v grep` ]]
	then
		release="ubuntu"
		installType='apt -y install'
		upgrade="apt update -y"
		removeType='apt --purge remove'

    fi
    if [[ -z ${release} ]]
    then
        echoContent red "本脚本不支持此系统，请将下方日志反馈给开发者"
        cat /etc/issue
        cat /proc/version
        exit 0;
    fi
}
checkSystem
init
