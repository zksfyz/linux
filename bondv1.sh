#!/bin/bash
#-------bond setup---------------

function check()
{
  ifconfig -a |awk -F '[ ]' '{print $1}' |grep -Ev "^$" |grep -Ev 'lo'  | grep 'bond0'
  bond_status=`echo $?` 
  if [ $bond_status -eq "0" ];then
    echo "已经配置bond！！！"
    exit 0
  else
    echo -e "\033[32m-----------检查网卡配置信息--------------\033[0m"
    ifconfig -a |awk -F '[ ]' '{print $1}' |grep -Ev "^$" |grep -Ev 'lo' >./ethernet.info
    touch ./sucess_ethernet.info
    sh /dev/null >./sucess_ethernet.info
    for i in `cat ./ethernet.info`
    do
    status=`ethtool $i |grep 'Link detected:' |awk -F ' ' '{print $3}'`
    if [ $status == 'yes' ];then
	 echo $status "$i" "网卡已经开启"
    elif [ $status == 'no' ];then
	echo "'$i'网卡未开启"
	read -p "是否要开启网卡 y|n 直接回车等于 'n':" word
	if [ "$word" == 'y' ];then
	    ifup $i
	    ifup_status=`echo $?`
	    if [ $ifup_status -eq '0' ];then
	        echo $status "$i" '网卡开启正常'
	    elif [ $ifup_status -ne '0' ];then
	        echo "无网卡信息，需要重新配置后开启"
	        cat ./ethinfo >>/etc/sysconfig/network-scripts/ifcfg-$i
	        sed -i "s/eth1/$i/g" /etc/sysconfig/network-scripts/ifcfg-$i
		echo "网卡信息配置完成"
	        ifup $i
	        echo $status "----网卡未开启----稍等-----"
		echo "网卡开启成功！"
	    fi
	elif [ -z "$word" -o "$word" == 'n' ];then
	    echo -e "\033[31m网卡"$i"未启用！\033[0m"
	    continue
	fi
    fi
    ethtool $i |grep 'Link detected: yes' >> /dev/null
    sucess_status=`echo $?`
    if [ $sucess_status -eq '0' ];then
	echo $i>>./sucess_ethernet.info
    elif [ $sucess_status -ne '0' ];then
	echo "该网卡未接线"
    fi
    done
    echo -e "\033[32m-----------完成检查网卡配置信息-OK-------------\033[0m"
  fi
}

function bond()
{	
    echo -e "\033[32m----------开始配置bond-------------\033[0m"
    touch /etc/modprobe.d/bonding.conf
    echo 'alias bond0 bonding' >/etc/modprobe.d/bonding.conf
    echo -e "\033[32m---------所有网卡名称信息如下-------\033[0m"
    cat ./ethernet.info
    echo -e "\033[32m---------已经接线的网卡名称信息如下--------\033[0m"
    cat ./sucess_ethernet.info
    echo -e "\033[32m---------请确认需要绑定的网卡名称--------\033[0m"   
    for n in `cat ./ethernet.info`
    do
    cat /etc/sysconfig/network-scripts/ifcfg-$n |grep '^IPADDR='
    echo -e "\033[31m注意：如果网卡包括所需要的IP，必须选择配置为bond信息，其他网卡根据实际情况选择！'$n'\033[0m"
    echo -e "\033[32m网卡名称为：'$n'\033[0m"
    read -p "是否要绑定该网卡 y|n 直接回车等于'n' :" eth
    if [ "$eth" == "y" ];then
    cat /etc/sysconfig/network-scripts/ifcfg-$n |grep '^IPADDR='
    status1=`echo $?`
    if [ $status1 -eq '0' ];then
	cp /etc/sysconfig/network-scripts/ifcfg-$n /root/ #ethernet profile info
	cp /etc/sysconfig/network-scripts/ifcfg-$n /etc/sysconfig/network-scripts/ifcfg-bond0 #bond info
	cat ./bondinfo >/etc/sysconfig/network-scripts/ifcfg-bond0
	cat /etc/sysconfig/network-scripts/ifcfg-$n |grep 'IPADDR=' >>/etc/sysconfig/network-scripts/ifcfg-bond0
	cat /etc/sysconfig/network-scripts/ifcfg-$n |grep 'NETMASK=' >>/etc/sysconfig/network-scripts/ifcfg-bond0
	cat /etc/sysconfig/network-scripts/ifcfg-$n |grep 'GATEWAY=' >>/etc/sysconfig/network-scripts/ifcfg-bond0
	cat ./eth_bond > /etc/sysconfig/network-scripts/ifcfg-$n
	sed -i "s/eth1/$n/g" /etc/sysconfig/network-scripts/ifcfg-$n
	echo -e "\033[32m主网卡bond信息配置完成！\033[0m"
    elif [ $status1 -ne '0' ];then
	cat ./eth_bond > /etc/sysconfig/network-scripts/ifcfg-$n
        sed -i "s/eth1/$n/g" /etc/sysconfig/network-scripts/ifcfg-$n
	echo -e "\033[32m配置该网卡有关bond信息完成\033[0m"
    fi
    elif [ "$eth" == "n" -o -z "$eth" ];then
	echo "此'$n'网卡不做聚合"
	continue
    fi
    done
    echo -e "\033[32m-----------完成bond配置信息-OK-------------\033[0m"
}

function set_info_check()
{   
    echo -e "\033[32m-----------检查所有网卡包括(bond)配置信息-OK-------------\033[0m"
    echo "bond0网卡配置信息"
    cat /etc/sysconfig/network-scripts/ifcfg-bond0
    for n in `cat ./ethernet.info`
    do
	echo "网卡"$n"配置信息"
	cat /etc/sysconfig/network-scripts/ifcfg-$n
    done 
    echo -e "\033[32m-----------完成检查所有的网卡配置信息-OK-------------\033[0m"
}
check
echo "等待3秒执行bond配置"
sleep 3
bond
echo "等待3秒执行配置完成后检查"
sleep 3
set_info_check
echo "等待5秒重启网卡"
sleep 5
read -p "确定重启网卡  y|n 直接回车等于选择 'n'" eth_restart
if [ "$eth_restart" == "y" ];then
    service network restart
    echo -e "\033[32m-----------重启网卡成功-OK-------------\033[0m"
elif [ -z "$eth_restart" -o "$eth_restart" == "n" ];then
    echo "退出网卡重启"
    exit 0
fi
