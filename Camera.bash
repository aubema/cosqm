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
y=`date +%Y`
mo=`date +%m`
d=`date +%d`
if [ ! -d /var/www/html/data/$y ]
then mkdir /var/www/html/data/$y
fi
if [ ! -d /var/www/html/data/$y/$mo ]
then /bin/mkdir /var/www/html/data/$y/$mo
fi
if [ ! -d /var/www/html/data/$y/$mo/webcam ]
then /bin/mkdir /var/www/html/data/$y/$mo/webcam
fi
noname=`date +%Y-%m-%d_%H:%M:%S`
cd /home/sand
/usr/bin/raspistill -n -o obstmp.jpg  # -ss can be used to define the exposure time in microseconds 
/usr/bin/convert -resize 640x640^ -gaussian-blur 0.05 -quality 85%  obstmp.jpg sky.jpg
rm -f obstmp.jpg

# mesurer le niveau de gris moyen (mean) sur cammodel
/usr/bin/identify -verbose /home/sand/sky.jpg | /bin/grep mean | /bin/sed 's/mean://g' |  /usr/bin/tr -d '\n' > /home/sand/mean.tmp
read r rr g gg b bb < /home/sand/mean.tmp 
/bin/echo $r $g $b
/bin/echo $r $g $b >> /home/sand/color.txt
if [ ! $b ]
#support des image grayscale
then let mean=r
else mean=`/bin/echo "scale=0;("$r"+"$g"+"$b")/3." | /usr/bin/bc -l` 
fi
if [ ! $mean ] ; then mean=0 ; fi
/bin/echo $mean > /home/sand/webcam-mean

echo $mean | sed 's/\./ /g' > /home/sand/toto.tmp
read luminosite bidon < /home/sand/toto.tmp

# if it is dark increase the gain to the maximum and take a new image
if [ $luminosite -le 50 ] 
then /usr/bin/raspistill  -ss 60000000 -awb off -awbg 8,8 -ISO 1600 -o obstmp.jpg
     /usr/bin/convert -resize 640x640^ -gaussian-blur 0.05 -quality 85%  obstmp.jpg sky.jpg
     rm -f obstmp.jpg
fi
# mesurer le niveau de gris moyen (mean) sur cammodel
/usr/bin/identify -verbose /home/sand/sky.jpg | /bin/grep mean | /bin/sed 's/mean://g' |  /usr/bin/tr -d '\n' > /home/sand/mean.tmp
read r rr g gg b bb < /home/sand/mean.tmp 
/bin/echo $r $g $b
/bin/echo $r $g $b >> /home/sand/color.txt
if [ ! $b ]
#support des image grayscale
then let mean=r
else mean=`/bin/echo "scale=0;("$r"+"$g"+"$b")/3." | /usr/bin/bc -l` 
fi
echo $mean | sed 's/\./ /g' > /home/sand/toto.tmp
read luminosite bidon < /home/sand/toto.tmp
if [ ! $mean ] ; then mean=0 ; fi
/bin/echo $mean > /home/sand/webcam-mean
#
#
#
if [ $luminosite -gt 50 ]
then /bin/chmod a+rx /home/sand/sky.jpg
     /bin/cp -f /home/sand/sky.jpg /home/sand/lastwebcam.jpg
     /bin/chmod a+rx /home/sand/lastwebcam.jpg
     /usr/bin/convert -resize 280x200 /home/sand/lastwebcam.jpg /home/sand/webcamsmall.jpg
     /bin/chmod a+rx /home/sand/webcamsmall.jpg
     mv /home/sand/sky.jpg /var/www/html/data/$y/$mo/webcam/$noname".jpg"
fi
/bin/rm -f /home/sand/mean.tmp
