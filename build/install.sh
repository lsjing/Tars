#!/bin/bash

PWD_DIR=`pwd`
MachineIp=`ip addr | grep 'inet ' | grep -v 127 | awk '{print $2}' | awk -F'/' '{print $1}'`
MachineName=`hostname`
MysqlIncludePath=
MysqlLibPath=

BaseDir='/xuef/github/Tars'

#git clone --recursive https://github.com/TarsCloud/Tars.git
#cd ${BaseDir}

#git submodule update --init --recursive framework
#git submodule update --init --recursive web
#
#cd framework
#git submodule update --init --recursive tarscpp
#
#cd tarscpp
#git submodule update --init --recursive servant/protocol


yum install -y glibc-devel git gcc gcc-c++ wget flex bison ncurses-devel zlib-devel libprotobuf-dev protobuf-compiler protobuf-devel ntpdate

cp -arf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
ntpdate 1.pool.ntp.org

cd ${BaseDir}/build/

wget http://v2.xue135.com/lsjing-video/weibo/201809/resin-4.0.49.tar.gz
wget http://v2.xue135.com/lsjing-video/weibo/201809/mysql-5.6.26.tar.gz
wget http://v2.xue135.com/lsjing-video/weibo/201809/jdk-8u111-linux-x64.tar.gz
wget http://v2.xue135.com/lsjing-video/weibo/201809/cmake-2.8.8.tar.gz
wget http://v2.xue135.com/lsjing-video/weibo/201809/apache-maven-3.3.9-bin.tar.gz
wget http://v2.xue135.com/lsjing-video/weibo/201809/htop-1.0.2.tar.gz


tar zxvf cmake-2.8.8.tar.gz
cd cmake-2.8.8
./bootstrap
make -j`grep processor /proc/cpuinfo | wc -l`
make install

cd ${BaseDir}/

if [   ! -n "$MysqlIncludePath"  ] 
  then
	cd ${BaseDir}/build/
	tar zxvf mysql-5.6.26.tar.gz
	cd mysql-5.6.26
	cmake . -DCMAKE_INSTALL_PREFIX=/usr/local/mysql-5.6.26 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DMYSQL_USER=mysql -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci
	make
	make install
	ln -s /usr/local/mysql-5.6.26 /usr/local/mysql
  else
  	sed -i "s@/usr/local/mysql/include@${MysqlIncludePath}@g" ../framework/CMakeLists.txt
  	sed -i "s@/usr/local/mysql/lib@${MysqlLibPath}@g" ../framework/CMakeLists.txt
  	sed -i "s@/usr/local/mysql/include@${MysqlIncludePath}@g" ../framework/tarscpp/CMakeLists.txt
  	sed -i "s@/usr/local/mysql/lib@${MysqlLibPath}@g" ../framework/tarscpp/CMakeLists.txt

fi


yum install -y perl
cd /usr/local/mysql
useradd mysql
rm -rf /usr/local/mysql/data
mkdir -p /data/mysql-data
ln -s /data/mysql-data /usr/local/mysql/data
chown -R mysql:mysql /data/mysql-data /usr/local/mysql/data
cp support-files/mysql.server /etc/init.d/mysql

yum install -y perl-Module-Install.noarch

sed -i "s/192.168.2.131/${MachineIp}/g" `grep 192.168.2.131 -lir ${BaseDir}/build/conf/*`
cp -arf /xuef/github/Tars/build/conf/my.cnf /usr/local/mysql/

./scripts/mysql_install_db --datadir=/usr/local/mysql/data --user=mysql
mkdir /var/run/mysqld
mkdir /var/log/mariadb
chown mysql:mysql /var/run/mysqld
chown mysql:mysql /var/log/mariadb

#service mysql start
/usr/local/mysql-5.6.26/bin/mysqld_safe --datadir=/usr/local/mysql/data --user=mysql --log-error=/tmp/mariadb.log --pid-file=/tmp/mariadb.pid --socket=/tmp/mysql.sock &
echo '/usr/local/mysql-5.6.26/bin/mysqld_safe --datadir=/usr/local/mysql/data --user=mysql --log-error=/tmp/mariadb.log --pid-file=/tmp/mariadb.pid --socket=/tmp/mysql.sock &' >> /etc/rc.local

#chkconfig mysql on

echo "PATH=\$PATH:/usr/local/mysql/bin" >> /etc/profile
source /etc/profile

/usr/local/mysql/bin/mysqladmin -u root password 'root_0'
/usr/local/mysql/bin/mysqladmin -u root -h ${MachineName} password 'root_0'

echo "/usr/local/mysql/lib/" >> /etc/ld.so.conf
ldconfig

cd ${BaseDir}/framework/build/
chmod u+x build.sh
./build.sh all
./build.sh install

cd ${BaseDir}/
/usr/local/mysql/bin/mysql -uroot -proot_0 -e "grant all on *.* to 'tars'@'%' identified by 'tars2015' with grant option;"
/usr/local/mysql/bin/mysql -uroot -proot_0 -e "grant all on *.* to 'tars'@'localhost' identified by 'tars2015' with grant option;"
/usr/local/mysql/bin/mysql -uroot -proot_0 -e "grant all on *.* to 'tars'@'${MachineName}' identified by 'tars2015' with grant option;"
/usr/local/mysql/bin/mysql -uroot -proot_0 -e "flush privileges;"

cd ${BaseDir}/framework/sql/
sed -i "s/192.168.2.131/${MachineIp}/g" `grep 192.168.2.131 -rl ./*`
sed -i "s/db.tars.com/${MachineIp}/g" `grep db.tars.com -rl ./*`
chmod u+x exec-sql.sh
sed -i 's/@appinside/_0/g' ./exec-sql.sh
sed -i 's#mysql#/usr/local/mysql/bin/mysql#g' ./exec-sql.sh
./exec-sql.sh

cd ${BaseDir}/framework/build/
make -j `grep processor /proc/cpuinfo | wc -l` framework-tar

make -j `grep processor /proc/cpuinfo | wc -l` tarsstat-tar
make -j `grep processor /proc/cpuinfo | wc -l` tarsnotify-tar
make -j `grep processor /proc/cpuinfo | wc -l` tarsproperty-tar
make -j `grep processor /proc/cpuinfo | wc -l` tarslog-tar
make -j `grep processor /proc/cpuinfo | wc -l` tarsquerystat-tar
make -j `grep processor /proc/cpuinfo | wc -l` tarsqueryproperty-tar

mkdir -p /usr/local/app/tars/
cd ${BaseDir}/framework/build/
cp framework.tgz /usr/local/app/tars/
cd /usr/local/app/tars
tar xzfv framework.tgz

sed -i "s/192.168.2.131/${MachineIp}/g" `grep 192.168.2.131 -rl ./*`
sed -i "s/db.tars.com/${MachineIp}/g" `grep db.tars.com -rl ./*`
sed -i "s/registry.tars.com/${MachineIp}/g" `grep registry.tars.com -rl ./*`
sed -i "s/web.tars.com/${MachineIp}/g" `grep web.tars.com -rl ./*`

chmod u+x tars_install.sh
./tars_install.sh

./tarspatch/util/init.sh

wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
source ~/.bashrc
nvm install v8.11.3

cd ../
cp -arf /xuef/github/Tars/web /usr/local/app/
cd web/
npm install -g pm2 --registry=https://registry.npm.taobao.org
sed -i "s/registry.tars.com/${MachineIp}/g" `grep registry.tars.com -rl ./config/*`
sed -i "s/db.tars.com/${MachineIp}/g" `grep db.tars.com -rl ./config/*`
npm install --registry=https://registry.npm.taobao.org
npm run prd

cd -

mkdir -p /data/log/tars/

echo 'install done'

