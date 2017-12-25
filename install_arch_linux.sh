#!/bin/bash

# Copyright (c) 2015, Bob Tidey
# All rights reserved.

# Redistribution and use, with or without modification, are permitted provided
# that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Neither the name of the copyright holder nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Description
# This script installs a browser-interface to control the RPi Cam. It can be run
# on any Raspberry Pi with a newly installed raspbian and enabled camera-support.
# RPI_Cam_Web_Interface installer by Silvan Melchior
# Edited by jfarcher to work with github
# Edited by slabua to support custom installation folder
# Additions by btidey, miraaz, gigpi
# Rewritten and split up by Bob Tidey 

#Debug enable next 3 lines
exec 5> install.txt
BASH_XTRACEFD="5"
set -x

cd $(dirname $(readlink -f $0))

if [ $(pacman -Q | grep -c "dialog") -eq 0 ]; then
    echo "Installing the package dialog"
    sudo pacman -S dialog
else
    echo "The package dialog is installed. Moving on."
fi

# Terminal colors
color_red="tput setaf 1"
color_green="tput setaf 2"
color_reset="tput sgr0"

# Version stuff moved out functions as we need it more when one time.
versionfile="./www/config.php"
version=$(cat $versionfile | grep "'APP_VERSION'" | cut -d "'" -f4)
backtitle="Copyright (c) 2015, Bob Tidey. RPi Cam $version"
jpglink="no"
phpversion=7

# Config options located in ./config.txt. In first run script makes that file for you.
if [ ! -e ./config.txt ]; then
      sudo echo "#This is config file for main installer. Put any extra options in here." > ./config.txt
      sudo echo "rpicamdir=\"html\"" >> ./config.txt
      sudo echo "webserver=\"apache\"" >> ./config.txt
      sudo echo "webport=\"80\"" >> ./config.txt
      sudo echo "webroot=\"/var/www\"" >> ./config.txt
      sudo echo "user=\"\"" >> ./config.txt
      sudo echo "webpasswd=\"\"" >> ./config.txt
      sudo echo "autostart=\"yes\"" >> ./config.txt
      sudo echo "jpglink=\"no\"" >> ./config.txt
      sudo echo "phpversion=\"7\"" >> ./config.txt
      sudo echo "" >> ./config.txt
      sudo chmod 664 ./config.txt
fi

source ./config.txt
rpicamdirold=$rpicamdir
if [ ! "${rpicamdirold:0:1}" == "" ]; then
   rpicamdirold=/$rpicamdirold
fi


#Allow for a quiet install
rm exitfile.txt >/dev/null 2>&1
if [ $# -eq 0 ] || [ "$1" != "q" ]; then
   exec 3>&1
   dialog                                         \
   --separate-widget $'\n'                        \
   --title "Configuration Options"    \
   --backtitle "$backtitle"					   \
   --form ""                                      \
   0 0 0                                          \
   "Cam subfolder:"        1 1   "$rpicamdir"            1 32 15 0  \
   "Autostart:(yes/no)"    2 1   "$autostart"            2 32 15 0  \
   "Server:(apache/nginx/lighttpd)" 3 1   "$webserver"   3 32 15 0  \
   "Webport:"              4 1   "$webport"              4 32 15 0  \
   "Webroot:"              5 1   "$webroot"              5 32 15 0  \
   "User:(blank=nologin)"  6 1   "$user"                 6 32 15 0  \
   "Password:"             7 1   "$webpasswd"            7 32 15 0  \
   "jpglink:(yes/no)"      8 1   "$jpglink"              8 32 15 0  \
   "phpversion:(5/7)"      9 1   "$phpversion"           9 32 15 0  \
   2>&1 1>&3 | {
      read -r rpicamdir
      read -r autostart
      read -r webserver
      read -r webport
      read -r webroot
      read -r user
      read -r webpasswd
	  read -r jpglink
	  read -r phpversion
   if [ -n "$webport" ]; then
      sudo echo "#This is edited config file for main installer. Put any extra options in here." > ./config.txt
      sudo echo "rpicamdir=\"$rpicamdir\"" >> ./config.txt
      sudo echo "webserver=\"$webserver\"" >> ./config.txt
      sudo echo "webport=\"$webport\"" >> ./config.txt
      sudo echo "webroot=\"$webroot\"" >> ./config.txt
      sudo echo "user=\"$user\"" >> ./config.txt
      sudo echo "webpasswd=\"$webpasswd\"" >> ./config.txt
      sudo echo "autostart=\"$autostart\"" >> ./config.txt
      sudo echo "jpglink=\"$jpglink\"" >> ./config.txt
      sudo echo "phpversion=\"$phpversion\"" >> ./config.txt
      sudo echo "" >> ./config.txt
   else
      echo "exit" > ./exitfile.txt
   fi
   }
   exec 3>&-

   if [ -e exitfile.txt ]; then
      rm exitfile.txt
      exit
   fi

   source ./config.txt
fi

if [ ! "${rpicamdir:0:1}" == "" ]; then
   rpicamdir=/$rpicamdir
   rpicamdirEsc=${rpicamdir//\//\\\/}
else
   rpicamdirEsc=""
fi

webrootEsc=${webroot//\//\\\/}

fn_stop ()
{ # This is function stop
        sudo killall raspimjpeg 2>/dev/null
        sudo killall php 2>/dev/null
        sudo killall motion 2>/dev/null
}

fn_reboot ()
{ # This is function reboot system
  dialog --title "Start camera system now" --backtitle "$backtitle" --yesno "Start now?" 5 33
  response=$?
    case $response in
      0) ./start.sh;;
      1) dialog --title 'Start or Reboot message' --colors --infobox "\Zb\Z1"'Manually run ./start.sh or reboot!' 4 28 ; sleep 2;;
      255) dialog --title 'Start or Reboot message' --colors --infobox "\Zb\Z1"'Manually run ./start.sh or reboot!' 4 28 ; sleep 2;;
    esac
}

fn_php ()
{
    # Arch Linux : Need to disable open_basedir in php.ini
    echo "Modify open_basedir in php.ini"
    sed -i "s/^open_basedir/;open_basedir/g" /etc/php/php.ini 
}

fn_apache ()
{
    aconf="etc/httpd/conf/raspicam.conf"
    cp $aconf.1 $aconf
    if [ -e "\/$aconf" ]; then
	sudo rm "\/$aconf"
    fi
    if [ -e /etc/httpd/conf-available/other-vhosts-access-log.conf ]; then
	aotherlog="/etc/httpd/conf-available/other-vhosts-access-log.conf"
    else
	aotherlog="/etc/httpd/conf/other-vhosts-access-log"
    fi
    tmpfile=$(mktemp)
    sudo awk '/NameVirtualHost \*:/{c+=1}{if(c==1){sub("NameVirtualHost \*:.*","NameVirtualHost *:'$webport'",$0)};print}' /etc/httpd/ports.conf > "$tmpfile" && sudo mv "$tmpfile" /etc/httpd/ports.conf
    sudo awk '/Listen/{c+=1}{if(c==1){sub("Listen.*","Listen '$webport'",$0)};print}' /etc/httpd/ports.conf > "$tmpfile" && sudo mv "$tmpfile" /etc/httpd/ports.conf
    awk '/<VirtualHost \*:/{c+=1}{if(c==1){sub("<VirtualHost \*:.*","<VirtualHost *:'$webport'>",$0)};print}' $aconf > "$tmpfile" && sudo mv "$tmpfile" $aconf
    sudo sed -i "s/<Directory\ $webrootEsc\/.*/<Directory\ $webrootEsc$rpicamdirEsc>/g" $aconf
    if [ "$user" == "" ]; then
	sudo sed -i "s/AllowOverride\ .*/AllowOverride None/g" $aconf
    else
	sudo htpasswd -b -B -c /usr/local/.htpasswd $user $webpasswd
	sudo sed -i "s/AllowOverride\ .*/AllowOverride All/g" $aconf
	if [ ! -e $webroot$rpicamdir/.htaccess ]; then
	    sudo bash -c "cat > $webroot$rpicamdir/.htaccess" << EOF
AuthName "RPi Cam Web Interface Restricted Area"
AuthType Basic
AuthUserFile /usr/local/.htpasswd
Require valid-user
EOF
	    sudo chown -R http:http $webroot$rpicamdir/.htaccess
	fi
    fi
    sudo mv $aconf /$aconf
    if [ ! -e /etc/httpd/conf/raspicam.conf ]; then
	sudo ln -sf /$aconf /etc/httpd/conf/raspicam.conf
    fi
    sudo sed -i "s/^CustomLog/#CustomLog/g" $aotherlog
    sudo a2dissite 000-default.conf >/dev/null 2>&1
    sudo systemctl restart httpd.service 
}

fn_nginx ()
{
    aconf="etc/nginx/sites-available/rpicam"
    cp $aconf.1 $aconf
    if [ -e "\/$aconf" ]; then
	sudo rm "\/$aconf"
    fi
    #uncomment next line if wishing to always access by http://ip as the root
    #sudo sed -i "s:root $webroot;:root $webroot$rpicamdirEsc;:g" $aconf 
    sudo mv /etc/nginx/sites-available/*default* etc/nginx/sites-available/ >/dev/null 2>&1

    if [ "$user" == "" ]; then
	sed -i "s/auth_basic\ .*/auth_basic \"Off\";/g" $aconf
	sed -i "s/\ auth_basic_user_file/#auth_basic_user_file/g" $aconf
    else
	sudo htpasswd -b -B -c /usr/local/.htpasswd $user $webpasswd
	sed -i "s/auth_basic\ .*/auth_basic \"Restricted\";/g" $aconf
	sed -i "s/#auth_basic_user_file/\ auth_basic_user_file/g" $aconf
    fi
    if [[ "$phpversion" == "7" ]]; then
	sed -i "s/\/var\/run\/php5-fpm\.sock;/\/run\/php\/php7.0-fpm\.sock;/g" $aconf
    fi
    sudo mv $aconf /$aconf
    sudo chmod 644 /$aconf
    if [ ! -e /etc/nginx/sites-enabled/rpicam ]; then
	sudo ln -sf /$aconf /etc/nginx/sites-enabled/rpicam
    fi

    # Update nginx main config file
    sudo sed -i "s/worker_processes 4;/worker_processes 2;/g" /etc/nginx/nginx.conf
    sudo sed -i "s/worker_connections 768;/worker_connections 128;/g" /etc/nginx/nginx.conf
    sudo sed -i "s/gzip on;/gzip off;/g" /etc/nginx/nginx.conf
    if [ "$NGINX_DISABLE_LOGGING" != "" ]; then
	sudo sed -i "s:access_log /var/log/nginx/nginx/access.log;:access_log /dev/null;:g" /etc/nginx/nginx.conf
    fi

    # Configure php-apc
    if [[ "$phpversion" == "7" ]]; then
	phpnv=/etc/php/7.0
    else
	phpnv=/etc/php5
    fi
    sudo sh -c "echo \"cgi.fix_pathinfo = 0;\" >> $phpnv/fpm/php.ini"
    sudo mkdir $phpnv/conf.d >/dev/null 2>&1
    sudo cp etc/php5/apc.ini $phpnv/conf.d/20-apc.ini
    sudo chmod 644 $phpnv/conf.d/20-apc.ini
    sudo service nginx restart
}

fn_lighttpd ()
{
    sudo lighty-enable-mod fastcgi-php
    sudo sed -i "s/^server.document-root.*/server.document-root  = \"$webrootEsc$rpicamdirEsc\"/g" /etc/lighttpd/lighttpd.conf
    sudo sed -i "s/^server.port.*/server.port  = $webport/g" /etc/lighttpd/lighttpd.conf
    #sudo service lighttpd restart  
    sudo /etc/init.d/lighttpd force-reload
 }

fn_motion ()
{
    sudo sed -i "s/^daemon.*/daemon on/g" /etc/motion/motion.conf		
    sudo sed -i "s/^logfile.*/;logfile \/tmp\/motion.log /g" /etc/motion/motion.conf		
    sudo sed -i "s/^; netcam_url.*/netcam_url/g" /etc/motion/motion.conf		
    sudo sed -i "s/^netcam_url.*/netcam_url http:\/\/localhost:$webport$rpicamdirEsc\/cam_pic.php/g" /etc/motion/motion.conf		
    if [ "$user" == "" ]; then
	sudo sed -i "s/^netcam_userpass.*/; netcam_userpass value/g" /etc/motion/motion.conf		
    else
	sudo sed -i "s/^; netcam_userpass.*/netcam_userpass/g" /etc/motion/motion.conf		
	sudo sed -i "s/^netcam_userpass.*/netcam_userpass $user:$webpasswd/g" /etc/motion/motion.conf		
    fi
    sudo sed -i "s/^; on_event_start.*/on_event_start/g" /etc/motion/motion.conf		
    sudo sed -i "s/^on_event_start.*/on_event_start echo -n \'1\' >$webroot$rpicamdirEsc\/FIFO1/g" /etc/motion/motion.conf		
    sudo sed -i "s/^; on_event_end.*/on_event_end/g" /etc/motion/motion.conf		
    sudo sed -i "s/^on_event_end.*/on_event_end echo -n \'0\' >$webroot$rpicamdirEsc\/FIFO1/g" /etc/motion/motion.conf		
    sudo sed -i "s/control_port.*/control_port 6642/g" /etc/motion/motion.conf		
    sudo sed -i "s/control_html_output.*/control_html_output off/g" /etc/motion/motion.conf		
    sudo sed -i "s/^output_pictures.*/output_pictures off/g" /etc/motion/motion.conf		
    sudo sed -i "s/^ffmpeg_output_movies on/ffmpeg_output_movies off/g" /etc/motion/motion.conf		
    sudo sed -i "s/^ffmpeg_cap_new on/ffmpeg_cap_new off/g" /etc/motion/motion.conf		
    sudo sed -i "s/^stream_port.*/stream_port 0/g" /etc/motion/motion.conf		
    sudo sed -i "s/^webcam_port.*/webcam_port 0/g" /etc/motion/motion.conf		
    sudo sed -i "s/^process_id_file/; process_id_file/g" /etc/motion/motion.conf
    sudo sed -i "s/^videodevice/; videodevice/g" /etc/motion/motion.conf
    sudo sed -i "s/^event_gap 60/event_gap 3/g" /etc/motion/motion.conf
    sudo chown motion:http /etc/motion/motion.conf
    sudo chmod 664 /etc/motion/motion.conf
}

fn_autostart ()
{
    sudo bash -c "cat > /usr/local/sbin/start_raspimjpeg_service.sh" << EOF
#!/bin/bash
#START RASPIMJPEG SECTION     
mkdir -p /dev/shm/mjpeg	      
chown http:http /dev/shm/mjpeg
chmod 777 /dev/shm/mjpeg
sleep 4;su -c 'raspimjpeg > /dev/null 2>&1 &' http
if [ -e /etc/debian_version ]; then
  sleep 4;su -c 'php $webroot$rpicamdir/schedule.php > /dev/null 2>&1 &' http
else
  sleep 4;su -s '/bin/bash' -c 'php $webroot$rpicamdir/schedule.php > /dev/null 2>&1 &' http
fi
#END RASPIMJPEG SECTION

#exit 0
EOF

    sudo chown root:root /usr/local/sbin/start_raspimjpeg_service.sh
    sudo chmod 755 /usr/local/sbin/start_raspimjpeg_service.sh

    sudo bash -c "cat > /etc/systemd/system/raspimjpeg.service" << EOF
[Unit]
Description=Raspimjpeg Server
Requires=systemd-networkd.service

[Service]
ExecStart=/usr/local/sbin/start_raspimjpeg_service.sh

[Install]
WantedBy=multi-user.target
EOF

    sudo chown root:root /etc/systemd/system/raspimjpeg.service
    sudo chmod 644 /etc/systemd/system/raspimjpeg.service
}

#Main install)
fn_stop

sudo mkdir -p $webroot$rpicamdir/media
#move old material if changing from a different install folder
if [ ! "$rpicamdir" == "$rpicamdirold" ]; then
   if [ -e $webroot$rpicamdirold/index.php ]; then
      sudo mv $webroot$rpicamdirold/* $webroot$rpicamdir
   fi
fi

sudo cp -r www/* $webroot$rpicamdir/
if [ -e $webroot$rpicamdir/index.html ]; then
   sudo rm $webroot$rpicamdir/index.html
fi

if [[ "$phpversion" == "7" ]]; then
   phpv=php7.0
else
   phpv=php5
fi


if [ "$webserver" == "apache" ]; then
   #sudo apt-get install -y apache2 $phpv $phpv-cli libapache2-mod-$phpv gpac motion zip libav-tools gstreamer1.0-tools
   sudo pacman -S --needed apache php php-apache gpac motion zip gstreamer make
   fn_apache
elif [ "$webserver" == "nginx" ]; then
   sudo apt-get install -y nginx $phpv-fpm $phpv-cli $phpv-common php-apcu apache2-utils gpac motion zip libav-tools gstreamer1.0-tools
   fn_nginx
elif [ "$webserver" == "lighttpd" ]; then
   sudo apt-get install -y  lighttpd $phpv-cli $phpv-common $phpv-cgi $phpv gpac motion zip libav-tools gstreamer1.0-tools
   fn_lighttpd
fi

#Make sure user http has bash shell
sudo sed -i "s/^http:x.*/http:x:33:33:http:$webroot:\/bin\/bash/g" /etc/passwd

if [ ! -e $webroot$rpicamdir/FIFO ]; then
   sudo mknod $webroot$rpicamdir/FIFO p
fi
sudo chmod 666 $webroot$rpicamdir/FIFO

if [ ! -e $webroot$rpicamdir/FIFO11 ]; then
   sudo mknod $webroot$rpicamdir/FIFO11 p
fi
sudo chmod 666 $webroot$rpicamdir/FIFO11

if [ ! -e $webroot$rpicamdir/FIFO1 ]; then
   sudo mknod $webroot$rpicamdir/FIFO1 p
fi

sudo chmod 666 $webroot$rpicamdir/FIFO1

if [ ! -d /dev/shm/mjpeg ]; then
   mkdir /dev/shm/mjpeg
fi

if [ "$jpglink" == "yes" ]; then
	if [ ! -e $webroot$rpicamdir/cam.jpg ]; then
	   sudo ln -sf /dev/shm/mjpeg/cam.jpg $webroot$rpicamdir/cam.jpg
	fi
fi

if [ -e $webroot$rpicamdir/status_mjpeg.txt ]; then
   sudo rm $webroot$rpicamdir/status_mjpeg.txt
fi
if [ ! -e /dev/shm/mjpeg/status_mjpeg.txt ]; then
   echo -n 'halted' > /dev/shm/mjpeg/status_mjpeg.txt
fi
sudo chown http:http /dev/shm/mjpeg/status_mjpeg.txt
sudo ln -sf /dev/shm/mjpeg/status_mjpeg.txt $webroot$rpicamdir/status_mjpeg.txt

sudo chown -R http:http $webroot$rpicamdir
sudo cp etc/sudoers.d/RPI_Cam_Web_Interface /etc/sudoers.d/
sudo chmod 440 /etc/sudoers.d/RPI_Cam_Web_Interface

if [ ! -d src ]; then
   mkdir src
fi

(cd src; git clone https://github.com/roberttidey/userland.git)
cp src/userland/host_applications/linux/apps/raspicam/RaspiMCam.c src/raspimjpeg
cp src/userland/host_applications/linux/apps/raspicam/RaspiMCmds.c src/raspimjpeg
cp src/userland/host_applications/linux/apps/raspicam/RaspiMJPEG.c src/raspimjpeg
cp src/userland/host_applications/linux/apps/raspicam/RaspiMJPEG.h src/raspimjpeg
cp src/userland/host_applications/linux/apps/raspicam/RaspiMMotion.c src/raspimjpeg
cp src/userland/host_applications/linux/apps/raspicam/RaspiMUtils.c src/raspimjpeg
rm -rf src/userland
(cd src/raspimjpeg; make)

sudo cp -r src/raspimjpeg/raspimjpeg /opt/vc/bin/
sudo chmod 755 /opt/vc/bin/raspimjpeg
if [ ! -e /usr/bin/raspimjpeg ]; then
   sudo ln -s /opt/vc/bin/raspimjpeg /usr/bin/raspimjpeg
fi

sed -e "s/\/var\/www/$webrootEsc$rpicamdirEsc/g" etc/raspimjpeg/raspimjpeg.1 > etc/raspimjpeg/raspimjpeg
if [[ `cat /proc/cmdline |awk -v RS=' ' -F= '/boardrev/ { print $2 }'` == "0x11" ]]; then
   sed -i "s/^camera_num 0/camera_num 1/g" etc/raspimjpeg/raspimjpeg
fi
if [ -e /etc/raspimjpeg ]; then
   $color_green; echo "Your custom raspimjpg backed up at /etc/raspimjpeg.bak"; $color_reset
   sudo cp -r /etc/raspimjpeg /etc/raspimjpeg.bak
fi
sudo cp etc/raspimjpeg/raspimjpeg /etc/raspimjpeg

sudo chmod 644 /etc/raspimjpeg
if [ ! -e $webroot$rpicamdir/raspimjpeg ]; then
   sudo ln -s /etc/raspimjpeg $webroot$rpicamdir/raspimjpeg
fi

sudo usermod -a -G video http
if [ -e $webroot$rpicamdir/uconfig ]; then
   sudo chown http:http $webroot$rpicamdir/uconfig
fi

fn_php
fn_motion
fn_autostart

if [ -e $webroot$rpicamdir/uconfig ]; then
   sudo chown http:http $webroot$rpicamdir/uconfig
fi

if [ -e $webroot$rpicamdir/schedule.php ]; then
   sudo rm $webroot$rpicamdir/schedule.php
fi

sudo sed -e "s/www/www$rpicamdirEsc/g" www/schedule.php > www/schedule.php.1
sudo mv www/schedule.php.1 $webroot$rpicamdir/schedule.php
sudo chown http:http $webroot$rpicamdir/schedule.php

exit  # icitte


if [ $# -eq 0 ] || [ "$1" != "q" ]; then
   fn_reboot
fi
