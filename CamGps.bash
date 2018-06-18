#!/bin/bash 
# script pour prendre une image de la ip webcam
# supporte la ip webcam linksys et la d-link mais il faut definir le model
# sur la ligne ci-dessous
# valeurs cammodel="dlink" ou cammodel="linksys" ou "raspberry-pi"
#   
#    Copyright (C) 2010  Martin Aube
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#    Contact: martin.aube@cegepsherbrooke.qc.ca
#
# 
cammodel="raspberry-pi"
y=`date +%Y`
mo=`date +%m`
d=`date +%d`
if [ ! -d /home/sand/public_html/data/$y ]
then mkdir /home/sand/public_html/data/$y
fi
if [ ! -d /home/sand/public_html/data/$y/$mo ]
then /bin/mkdir /home/sand/public_html/data/$y/$mo
fi
if [ ! -d /home/sand/public_html/data/$y/$mo/webcam ]
then /bin/mkdir /home/sand/public_html/data/$y/$mo/webcam
fi
noname=`date +%Y-%m-%d_%H:%M:%S`
cd /home/sand/public_html/cgi-bin
# find skycam model from localconfig file
/bin/grep "cammodel" /home/sand/localconfig > wline.tmp
read tag cammodel bidon < wline.tmp
if [ $cammodel = "linksys" ]
then
/usr/bin/mplayer http://sand:memo123@192.168.1.101/img/video.asf -frames 32 -vo pnm > /dev/null
/bin/chmod a+rx /home/sand/public_html/cgi-bin/0000000*.ppm 
/usr/bin/convert -average /home/sand/public_html/cgi-bin/000*ppm /home/sand/public_html/cgi-bin/sky.jpg
rm -f /home/sand/public_html/cgi-bin/000*.ppm
fi
if [ $cammodel = "dlink" ]
then
list=" 00001 00002 00003 00004 00005 00006 00007 00008 00009 00010 00011 00012 00013 00014 00015 00016 00017 00018 00019 00020 00021 00022 00023 00024 00025 00026 00027 00028 00029 00030 00031 00032 "
for nf in $list
do /usr/bin/wget http://sand:memo123@192.168.1.101/IMAGE.JPG
   /bin/mv -f IMAGE.JPG $nf.jpg
done
/usr/bin/convert -average /home/sand/public_html/cgi-bin/000*jpg /home/sand/public_html/cgi-bin/sky.jpg
rm -f /home/sand/public_html/cgi-bin/image*
fi
if [ $cammodel = "IPVideo9100A" ]
then /usr/bin/curl -m 1 http://sand:memo123@192.168.1.101/GetData.cgi -o fifo.mjpeg & /usr/bin/mplayer -demuxer lavf fifo.mjpeg
     /bin/sleep 1
     /usr/bin/ffmpeg -i fifo.mjpeg img%d.png
     /usr/bin/convert -average img*.png -quality 100 toto.png 
     /usr/bin/convert toto.png sky.jpg
     rm -f img*png
fi
if [ $cammodel = "raspberry-pi" ]
then /usr/bin/raspistill -n -o obstmp.jpg  # -ss can be used to define the exposure time in microseconds 
     /usr/bin/convert -resize 640x640^ -gaussian-blur 0.05 -quality 85%  obstmp.jpg sky.jpg
     rm -f obstmp.jpg
fi

if [ $cammodel = "none" ]
then mean=0
     /bin/echo $mean > /home/sand/public_html/cgi-bin/webcam-mean  
fi

# mesurer le niveau de gris moyen (mean) sur cammodel
/usr/bin/identify -verbose /home/sand/public_html/cgi-bin/sky.jpg | /bin/grep mean | /bin/sed 's/mean://g' |  /usr/bin/tr -d '\n' > /home/sand/public_html/cgi-bin/mean.tmp
read r rr g gg b bb < /home/sand/public_html/cgi-bin/mean.tmp 
/bin/echo $r $g $b
/bin/echo $r $g $b >> /home/sand/public_html/data/$y/$mo/color.txt
if [ ! $b ]
#support des image grayscale
then let mean=r
else mean=`/bin/echo "scale=0;("$r"+"$g"+"$b")/3." | /usr/bin/bc -l` 
fi
if [ ! $mean ] ; then mean=0 ; fi
/bin/echo $mean > /home/sand/public_html/cgi-bin/webcam-mean
#
#
#
/bin/chmod a+rx /home/sand/public_html/cgi-bin/sky.jpg
/bin/cp -f /home/sand/public_html/cgi-bin/sky.jpg /home/sand/public_html/lastwebcam.jpg
/bin/chmod a+rx /home/sand/public_html/lastwebcam.jpg
/usr/bin/convert -resize 280x200 /home/sand/public_html/lastwebcam.jpg /home/sand/public_html/webcamsmall.jpg
/bin/chmod a+rx /home/sand/public_html/webcamsmall.jpg
cd /home/sand/public_html/data/$y/$mo/webcam
/bin/ls -1 /home/sand/public_html/data/$y/$mo/webcam/sky* > /home/sand/public_html/cgi-bin/liste.tmp
list=`/bin/ls -1 /home/sand/public_html/data/$y/$mo/webcam/sky*`
nlign=` /bin/grep -c "" /home/sand/public_html/cgi-bin/liste.tmp`
/bin/echo $nlign 
n=0 
/bin/rm -f /home/sand/public_html/cgi-bin/animation 
for i in $list
   do let n=n+1 
      let debut="$nlign"-48
      if [ "$n" -gt "$debut"  ]
      then /bin/echo $i >> /home/sand/public_html/cgi-bin/animation 
      fi 
   done
   /bin/echo "/usr/bin/convert -delay 25" `/bin/cat /home/sand/public_html/cgi-bin/animation |  /usr/bin/tr -d '\n' | /bin/sed 's/jpg/jpg /g'` " /home/sand/public_html/cgi-bin/tata.gif" > /home/sand/public_html/cgi-bin/animation.tmp
   /bin/bash /home/sand/public_html/cgi-bin/animation.tmp
   /bin/mv /home/sand/public_html/cgi-bin/tata.gif /home/sand/public_html/animation.gif
   /bin/chmod a+xr  /home/sand/public_html/animation.gif
   /bin/rm -f /home/sand/public_html/cgi-bin/liste.tmp
   /bin/rm -f /home/sand/public_html/cgi-bin/animation.tmp
   /bin/rm -f /home/sand/public_html/cgi-bin/animation
   /bin/rm -f /home/sand/public_html/cgi-bin/mean.tmp
#   
#  GPS section
#
#
#  searching for gps port
#
   if [ $gpsf -eq 1 ] 
   then echo "GPS mode activated"
        if [ `ls /dev | grep ttyUSB0`  ] 
        then echo "GPS look present." 
#
#            reading 10 gps transactions
#
             /bin/echo "Waiting 5 sec for GPS reading..."
             /usr/bin/gpspipe -w -n 10 > $homed/public_html/cgi-bin/coords.tmp
             /usr/bin/tail -1 $homed/public_html/cgi-bin/coords.tmp > $homed/public_html/cgi-bin/bidon.tmp
             /bin/rm -f $homed/public_html/cgi-bin/coords.tmp
             read bidon bidon bidon lat lon altitude bidon1 < $homed/public_html/cgi-bin/bidon.tmp
             if [ "${bidon1:0:1}" != "" ]
             then /bin/echo "GPS is connected, reading lat lon data."
                  lon=`/bin/echo $lon"/-1" |/bin/bc -l`
                  DD=`/bin/echo "scale=0;"$lon"/1" |/usr/bin/bc -l`
                  dd=`/bin/echo "scale=0;"$lat"/1" |/usr/bin/bc -l`
                  MMM=`/bin/echo "("$lon"-"$DD")*60" |/usr/bin/bc -l`
                  MM=${MMM:0:2}
                  mmm=`/bin/echo "("$lat"-"$dd")*60" |/usr/bin/bc -l`
                  mm=${mmm:0:2}
                  SSS=`/bin/echo "(("$lon"-"$DD")-"$MM"/60)*3600" |/usr/bin/bc -l`
                  SS=${SSS:0:2}
                  sss=`/bin/echo "(("$lat"-"$dd")-"$mm"/60)*3600" |/usr/bin/bc -l`
                  ss=${sss:0:2}
                  /bin/echo "GPS give Latitude:" $dd $mm $ss ", Longitude:" $DD $MM $SS "and Altitude:" $altitude
             else /bin/echo "GPS not working: using coords. from localconfig"
                  /bin/echo "Latitude:" $dd $mm $ss ", Longitude:" $DD $MM $SS
             fi    
        else /bin/echo "GPS not present: using coords. from localconfig"
             /bin/echo "Latitude:" $dd $mm $ss ", Longitude:" $DD $MM $SS
        fi
   else  echo "GPS mode off"
   fi
   /bin/grep "Site_name" $homed/localconfig > $homed/public_html/cgi-bin/ligne.tmp
   read bidon NAME bidon < $homed/public_html/cgi-bin/ligne.tmp
#
#  reading longitude and latitude from observation schedule
#
   if [ `grep -c " " $homed/public_html/cgi-bin/$myFile` -ne 0 ]
   then /bin/grep Longitude $homed/localconfig > $homed/public_html/cgi-bin/ligne.tmp
        read bidon DD MM SS bidon < $homed/public_html/cgi-bin/ligne.tmp
        /bin/grep Latitude $homed/localconfig > $homed/public_html/cgi-bin/ligne.tmp
        read bidon dd mm ss bidon < $homed/public_html/cgi-bin/ligne.tmp
   else 
        echo "Please put something in $homed/public_html/cgi-bin/observation_list and restart observe."
        if [ $ival = "sp" ] || [ $ival = "ra" ] ; then
           /usr/local/bin/night_temperature set -off
        fi
        exit 1
   fi