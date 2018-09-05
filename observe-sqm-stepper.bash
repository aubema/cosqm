#!/bin/bash 
#   
#    Copyright (C) 2018  Martin Aube Mia Caron
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
# =============================
# reset the center of the clear filter
recenter () {
      echo "recenter" $possqm
      let ang=possqm-maxstep/8-pos
      if [ $ang -ge $maxstep ] 
      then let ang=ang-maxstep
      fi
      if [ $ang -le -$maxstep ]
      then let ang=ang+maxstep
      fi
      # moving filter wheel
      echo "Moving the filter wheel to filter before SQM to recenter" 
      let pos=pos+ang
      if [ $pos -ge $maxstep ] 
      then let pos=pos-maxstep
      fi
      if [ $pos -le -$maxstep ]
      then let pos=pos+maxstep
      fi
      /usr/local/bin/MoveStepFilterWheel.py $ang 0  
      let newsteps=maxstep/4/movestep
      findSQM $newsteps
}
# ============================
# find the clear filter position
findSQM () {
     let nstep=$1
     echo "Searching number of steps: " $nstep
     memoi=3000
     n=0
     while [ $n -lt $nstep ] 
     do /usr/local/bin/sqmleread.pl $sqmip 10001 1 > sqmdata.tmp    
          read sqm < sqmdata.tmp
          echo $sqm | sed 's/,/ /g' | sed 's/m/ /g' | sed 's/\./ /g' > toto.tmp
          read bidon sqmm sqmd bidon < toto.tmp
         # remove leading zero to the sky brightness
          if [ ${sqmm:0:1} == 0 ]
          then sqmm=`echo $sqmm | sed 's/0//g'`
          fi
          if [ ${sqmd:0:1} == 0 ]
          then sqmd=`echo $sqmd | sed 's/0//g'`
          fi
          let meas=sqmm*100+sqmd
          if [ $meas -lt $memoi ]
          then let memoi=meas
                   let possqm=pos
                   echo "Found clearer position = " $possqm
          fi
          /usr/local/bin/MoveStepFilterWheel.py $movestep 0
          let pos=pos+movestep
          if [ $pos -ge $maxstep ] 
          then let pos=pos-maxstep
          fi
          if [ $pos -le -$maxstep ] 
          then let pos=pos+maxstep
          fi
          let n=n+1
         done
         let possqm=possqm-filteroffset
         echo "Clearest filter position +- "$movestep " = " $possqm
}
# ==================================
# global positioning system
globalpos () {
#
#            reading 10 gps transactions
#
             /bin/echo "Waiting 5 sec for GPS reading..."
             /usr/bin/gpspipe -w -n 10 > $homed/public_html/cgi-bin/coords.tmp
             /usr/bin/tail -1 $homed/public_html/cgi-bin/coords.tmp | sed 's/,/\n/g' | sed 's/"//g' | sed 's/:/ /g'> $homed/public_html/cgi-bin/bidon.tmp
             /bin/rm -f $homed/public_html/cgi-bin/coords.tmp
             grep lat $homed/public_html/cgi-bin/bidon.tmp > $homed/public_html/cgi-bin/bidon1.tmp
             read bidon lat bidon1 < $homed/public_html/cgi-bin/bidon1.tmp
             grep lon $homed/public_html/cgi-bin/bidon.tmp > $homed/public_html/cgi-bin/bidon1.tmp
             read bidon lon bidon1 < $homed/public_html/cgi-bin/bidon1.tmp
             grep alt $homed/public_html/cgi-bin/bidon.tmp > $homed/public_html/cgi-bin/bidon1.tmp
             read bidon alt bidon1 < $homed/public_html/cgi-bin/bidon1.tmp
             grep activated $homed/public_html/cgi-bin/bidon.tmp > $homed/public_html/cgi-bin/bidon1.tmp 
             read bidon gpsdate bidon1 < $homed/public_html/cgi-bin/bidon1.tmp
             /bin/echo "GPS is connected, reading lat lon data."
             if [ -z "${lon}" ]
             then let lon=0
                  let lat=0
                  let alt=0
             fi 
             /bin/echo "GPS gives Latitude:" $lat ", Longitude:" $lon "and Altitude:" $alt
             # set computer time
             #pkill ntpd
             #sleep 2
             echo $gpsdate >> /home/sand/datedugps
             #date -s "$gpsdate"
             #/usr/sbin/ntpd   
}
# ==================================
# ==================================
# main
# home directory
homed=/home/sand
# activate gps option 0=off 1=on
gpsf=1
nobs=9999  		# number of times measured if 9999 then infinity
waittime=10             # at a mag of about 24 the integration time is around 60s
movestep=16
maxstep=2040
daydelay=20    # add a delay between samplings during daytime to restrict the total amount of data
filteroffset=0  # to ensure that the SQM fall in the center of the filter
#
# set band list
# wavelengths 0:= Clear ,1:= Red 2:= Green ,3:= Blue ,4:= Yellow
#
filters=( 0 1 2 3 4 )
calib=( 1.0 1.0 1.0 1.0 1.0 )
fname=(Clear Red Green Blue Yellow)
grep filter_gain $homed/localconfig > toto
read bidon gain bidon < toto
grep filter_offset $homed/localconfig > toto
read bidon offset bidon < toto
grep sqmIP $homed/localconfig > toto # sqmIP est le mot cle cherche dans le localconfig 
read bidon sqmip bidon < toto
# find the clear filter
# one complete rotation in half step mode (mode 1) is maxstep=4080 i.e. 1 step = 0.087890625 deg
# if you use the full step mode (mode 0) then maxstep=2040 is the number of steps i.e. 1 step = 0.17578125
let nstep=maxstep/movestep
pos=0
findSQM $nstep
#
#  searching for gps port
#
if [ $gpsf -eq 1 ] 
then echo "GPS mode activated"
         if [ `ls /dev | grep ttyUSB0`  ] 
         then echo "GPS look present." 
                  globalpos
         else /bin/echo "GPS not present: using coords. from localconfig"
                #
                #  reading longitude and latitude from localconfig
                #
                if [ `grep -c " " $homed/public_html/cgi-bin/$myFile` -ne 0 ]
                then /bin/grep Longitude $homed/localconfig > $homed/public_html/cgi-bin/ligne.tmp
                         read bidon lon bidon < $homed/public_html/cgi-bin/ligne.tmp
                         /bin/grep Latitude $homed/localconfig > $homed/public_html/cgi-bin/ligne.tmp
                         read bidon lat bidon < $homed/public_html/cgi-bin/ligne.tmp
                         /bin/grep Altitude $homed/localconfig > $homed/public_html/cgi-bin/ligne.tmp
                        read bidon alt bidon < $homed/public_html/cgi-bin/ligne.tmp
                else 
                        echo "Please put something in "$homed"/localconfig and restart observe-sqm-stepper.bash."
                fi
                /bin/echo "Latitude:" $lat ", Longitude:" $lon
         fi
else  echo "GPS mode off"
fi
/bin/grep "Site_name" $homed/localconfig > $homed/public_html/cgi-bin/ligne.tmp
read bidon NAME bidon < $homed/public_html/cgi-bin/ligne.tmp
#
# loop
#
i=0
count=0
while [ $i -lt $nobs ]
do  let count=count+1
      if [ $count -eq 10 ]   # set frequency of the recenter operation
      then recenter
               let count=0
      fi
      #  according to unihedron here are the typical waiting time vs sky brightness
      #  19.83 = 1s
      #  21.97 = 6.9s
      #  22.69 = 12.8s
      #  23.13 = 18.7s
      #  23.48 = 24.6s
      #  23.76 = 30.5s
      #  24.00 = 36.4s
      #  24.21 = 42.3s
      #  24.41 = 48.2s 
      #  24.60 = 54.1s
      #  24.76 = 60s
      #
      #  it is suggested to use filter 1 (Red) to estimate the waittime
      #  waittime must be at least twice that time
      #  moving the filter wheel to the Red filter
      #  72 degrees between filter i.e. maxstep/5 
      let ang=possqm+1*maxstep/5-pos
      echo "Moving wheel of" $ang " steps"
      #
      /usr/local/bin/MoveStepFilterWheel.py $ang 0
      let pos=pos+ang
      if [ $pos -ge $maxstep ] 
      then let pos=pos-maxstep
      fi
      if [ $pos -le -$maxstep ]
      then let pos=pos+maxstep
      fi
      let waittime=10
      echo "Waiting " $waittime " s to determine optimal acquisition time"
      /bin/sleep $waittime
      /usr/local/bin/sqmleread.pl $sqmip 10001 1 > sqmdata.tmp
      read sqm < sqmdata.tmp
      echo $sqm | sed 's/,/ /g' | sed 's/s//g' > toto.tmp
      read bidon bidon bidon bidon tim bidon < toto.tmp
      echo "Decimal readout time: " $tim  
      # default wait time set to the acquisition time with the red filter
      echo $tim | sed 's/\./ /g'  > toto.tmp
      read tim timd toto < toto.tmp
      echo $tim | sed 's/000//g'  > toto.tmp
      read tim toto < toto.tmp
      if [ $timd -ge 500 ]
      then let tim=tim+1
      fi
      #   add 1 seconds to the waiting time to be sure that no overlap will occur
      let waittime=tim+1
      echo "Required acquistion time:" $waittime
      if [  $nobs != 9999 ] 
      then let i=i+1 #   never ending loop
      fi
      n=0
      echo "Start"
      echo "Observation number: " $i
      while [ $n -lt ${#filters[*]} ]
      do filter=${filters[$n]}
           let ang=possqm+n*maxstep/5-pos
           if [ $ang -ge $maxstep ] 
           then let ang=ang-maxstep
           fi
      if [ $ang -le -$maxstep ]
      then let ang=ang+maxstep
      fi
      # moving filter wheel
      echo "Moving the filter wheel to filter " $n "("${fname[$n]}")"
      let pos=pos+ang
      if [ $pos -ge $maxstep ] 
      then let pos=pos-maxstep
      fi
      if [ $pos -le -$maxstep ]
      then let pos=pos+maxstep
      fi
      echo "Moving to position " $pos
      /usr/local/bin/MoveStepFilterWheel.py $ang 0  
      echo "Reading sqm, Filter: " $n
      echo "Waiting time:" $waittime
      /bin/sleep $waittime         # let enough time to be sure that the reading comes from this filter
      /usr/local/bin/sqmleread.pl $sqmip 10001 1 > sqmdata.tmp
      echo "End of reading"      
      read sqm < sqmdata.tmp
      echo $sqm | sed 's/,/ /g' | sed 's/m//g' > toto.tmp
      read bidon sb bidon < toto.tmp
      if [ $n -eq 0 ]
      # keep the sqm clear value in mag per square arc second
      then sqmreading=$sb
      fi
      echo "Sky brightness = " $sb
      # convert mag par sq arc second to flux
      sbcal[$n]=`/bin/echo "e((-1*"$sb"/2.5000000)*l(10))*"${calib[$n]} |/usr/bin/bc -l`
      sbcals[$n]=`printf "%0.6e\n" ${sbcal[$n]}`
      echo "Flux in band " $n " = "${sbcals[$n]}
      let n=n+1
   done
   echo $sb | sed 's/\./ /g'  > toto.tmp  # on decoupe les entiers et decimales de la mesure sqm
   read seuil toto toto < toto.tmp
   nomfich=`date -u +"%Y-%m-%d"`
   nomfich=$nomfich".txt"
   time=`date +%Y-%m-%d" "%H:%M:%S`
   y=`date +%Y`
   mo=`date +%m`
   d=`date +%d`
   if [ ! -d /home/sand/public_html/data/$y ]
   then mkdir /home/sand/public_html/data/$y
   fi
   if [ ! -d /home/sand/public_html/data/$y/$mo ]
   then /bin/mkdir /home/sand/public_html/data/$y/$mo
   fi
   echo $time $lat $lon $alt $sqmreading ${sbcals[0]} ${sbcals[1]} ${sbcals[2]} ${sbcals[3]} ${sbcals[4]}>> $homed/public_html/data/$y/$mo/$nomfich
   if [ $seuil -lt 12 ]
       then /bin/sleep $daydelay    # waiting when it is daytime
   fi 
done
echo "Parking filter wheel..."
let ang=-pos
/usr/local/bin/MoveStepFilterWheel.py $ang 0  
echo "Finish observe-sqm-stepper.bash"
exit 0



