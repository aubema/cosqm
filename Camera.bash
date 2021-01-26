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
noname=`date +%Y-%m-%d_%H-%M-%S`
cd /home/sand
itime=200
ng=1
luminosite=0
while [ $luminosite -lt 50 ] && [ $ng -le 7 ]
do /usr/bin/raspistill -t 1 -md 3 -bm -ex off -ag 16 --shutter $itime -dg 1 -st -o /home/sand/skytmp.jpg 
   /usr/bin/convert -resize 640x640^ -gaussian-blur 0.05 -quality 85%  /home/sand/skytmp.jpg /home/sand/sky.jpg


# mesurer le niveau de gris moyen (mean)
   /usr/bin/identify -verbose /home/sand/sky.jpg | /bin/grep mean | /bin/sed 's/mean://g' |  /usr/bin/tr -d '\n' > /home/sand/mean.tmp
   read r rr g gg b bb < /home/sand/mean.tmp 
   /bin/echo $r $g $b
   /bin/echo $r $g $b >> /home/sand/color.txt
   if [ ! $b ]
#support des image grayscale
   then let mean=r
   else mean=`/bin/echo "scale=0;("$r"+"$g"+"$b")/3." | /usr/bin/bc -l` 
   fi
   echo $mean | sed 's/\./ /g' > /home/sand/mean.tmp
   read luminosite bidon < /home/sand/mean.tmp
   if [ ! $luminosite ] 
   then luminosite=0
   fi
   echo $luminosite $itime
   let itime=itime*2
   let ng=ng+1
done
mv /home/sand/sky.jpg /var/www/html/data/$y/$mo/webcam/$noname".jpg"
/bin/rm -f /home/sand/mean.tmp
/bin/rm -f /home/sand/skytmp.jpg
