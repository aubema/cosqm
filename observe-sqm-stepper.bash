#!/bin/bash 
#
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
      let maxstep2=maxstep/3
      echo "recenter" $possqm
      let ang=possqm-maxstep2-pos
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
      let newsteps=maxstep2/movestep
      findSQM $newsteps
}
# ============================
# find the clear filter position
findSQM () {
#
# ----> parameter to set
#
     # set acquisition time to 15s
     let waittime=5
     filteroffset=0  # to ensure that the SQM fall in the center of the filter
     let movestep=maxstep/15
     let nstep=maxstep/movestep
     echo "Searching SQM position..." ; date
     while [ $movestep -gt 3 ]
     do echo "Searching number of trials: " $nstep "Skipping " $movestep "steps" 
        memoi=3000
        n=0
        while [ $n -lt $nstep ] 
        do /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /root/sqmdata.tmp    
           read sqm < /root/sqmdata.tmp
           echo $sqm | sed 's/,/ /g' | sed 's/m/ /g' | sed 's/\./ /g' > /root/toto.tmp
           read bidon sqmm sqmd bidon < /root/toto.tmp
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
        echo "Clearest filter position +- "$movestep " = " $possqm
        let ang=possqm-2*movestep-pos
        let pos=pos+ang
        /usr/local/bin/MoveStepFilterWheel.py $ang 0
        let movestep=movestep/2
        let nstep=6
        /bin/sleep $waittime      
     done
     let possqm=possqm-filteroffset
     echo "Final SQM position:" $possqm ; date
}
# ==================================
# global positioning system
globalpos () {
#
#            reading 10 gps transactions
#
             /bin/echo "Waiting 10 sec for GPS reading..."
             sleep 10
             /usr/bin/gpspipe -w -n 10 > /root/coords.tmp
             /usr/bin/tail -2 /root/coords.tmp | sed 's/,/\n/g' | sed 's/"//g' | sed 's/:/ /g'> /root/bidon.tmp
#             /bin/rm -f /root/coords.tmp
             grep lat /root/bidon.tmp > /root/bidon1.tmp
             read bidon lat bidon1 < /root/bidon1.tmp
             grep lon /root/bidon.tmp > /root/bidon1.tmp
             read bidon lon bidon1 < /root/bidon1.tmp
             grep alt /root/bidon.tmp > /root/bidon1.tmp
             read bidon alt bidon1 < /root/bidon1.tmp
             grep activated /root/bidon.tmp > /root/bidon1.tmp 
             read bidon gpsdate bidon1 < /root/bidon1.tmp
             /bin/echo "GPS is connected, reading lat lon data. Longitude:" $lon
             if [ -z "${lon}" ]
             then let lon=0
                  let lat=0
                  let alt=0
             fi 
             /bin/echo "GPS gives Latitude:" $lat ", Longitude:" $lon "and Altitude:" $alt
             # set computer time
             #pkill ntpd
             #sleep 2
             echo $gpsdate >> /root/datedugps
             #date -s "$gpsdate"
             #/usr/sbin/ntpd   
}
# ==================================
# ==================================
# main
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
calib=( 0.0 0.0 0.0 0.0 0.0 )
# calib is the magnitude offset for each filter
fname=(Clear Red Green Blue Yellow)
grep filter_gain /home/sand/localconfig > /root/toto
read bidon gain bidon < /root/toto
grep filter_offset /home/sand/localconfig > /root/toto
read bidon offset bidon < /root/toto
grep sqmIP /home/sand/localconfig > /root/toto # sqmIP est le mot cle cherche dans le localconfig 
read bidon sqmip bidon < /root/toto
# find the clear filter
# one complete rotation in half step mode (mode 1) is maxstep=4080 i.e. 1 step = 0.087890625 deg
# if you use the full step mode (mode 0) then maxstep=2040 is the number of steps i.e. 1 step = 0.17578125
let nstep=maxstep/movestep
pos=0
findSQM
#
#  searching for gps
#
if [ $gpsf -eq 1 ] 
then echo "GPS mode activated"
         if [ `ls /dev | grep ttyACM0`  ] 
         then echo "GPS look present." 
                  globalpos
         else /bin/echo "GPS not present: using coords. from localconfig"
                #
                #  reading longitude and latitude from localconfig
                #
                if [ `grep -c " " /home/sand/localconfig` -ne 0 ]
                then /bin/grep Longitude /home/sand/localconfig > /root/ligne.tmp
                         read bidon lon bidon < /root/ligne.tmp
                         /bin/grep Latitude /home/sand/localconfig > /root/ligne.tmp
                         read bidon lat bidon < /root/ligne.tmp
                         /bin/grep Altitude /home/sand/localconfig > /root/ligne.tmp
                        read bidon alt bidon < /root/ligne.tmp
                else 
                        echo "Please put something in /home/sand/localconfig and restart observe-sqm-stepper.bash."
                fi
                /bin/echo "Latitude:" $lat ", Longitude:" $lon
         fi
else  echo "GPS mode off"
fi
/bin/grep "Site_name" /home/sand/localconfig > /root/ligne.tmp
read bidon NAME bidon < /root/ligne.tmp
#
# loop
#
i=0
count=0
while [ $i -lt $nobs ]
do    #  according to unihedron here are the typical waiting time vs sky brightness
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
      /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /root/sqmdata.tmp
      read sqm < /root/sqmdata.tmp
      echo $sqm | sed 's/,/ /g' | sed 's/s//g' | sed 's/C/ C/g' > /root/toto.tmp
      read bidon bidon bidon bidon tim temp bidon < /root/toto.tmp
      echo "Decimal readout time: " $tim  
      # default wait time set to the acquisition time with the red filter
      echo $tim | sed 's/\./ /g'  > /root/toto.tmp
      read tim timd toto < /root/toto.tmp
      echo $tim | sed 's/000//g'  > /root/toto.tmp
      read tim toto < /root/toto.tmp
      if [ $timd -ge 500 ]
      then let tim=tim+1
      fi
      #   add 1 seconds to the waiting time to be sure that no overlap will occur
      let waittime=tim+1
      echo "Required acquistion time:" $waittime
      let count=count+1
      if [ $count -eq 2 ]   # set frequency of the recenter operation
      then findSQM
           let count=0
           #
           #  searching for gps
           #
           if [ $gpsf -eq 1 ] 
           then echo "GPS mode activated"
                if [ `ls /dev | grep ttyACM0`  ] 
                then echo "GPS look present." 
                     globalpos
                else /bin/echo "GPS not present: using coords. from localconfig"
                     #
                     #  reading longitude and latitude from localconfig
                     #
                     if [ `grep -c " " /home/sand/localconfig` -ne 0 ]
                     then /bin/grep Longitude /home/sand/localconfig > /root/ligne.tmp
                          read bidon lon bidon < /root/ligne.tmp
                          /bin/grep Latitude /home/sand/localconfig > /root/ligne.tmp
                          read bidon lat bidon < /root/ligne.tmp
                          /bin/grep Altitude /home/sand/localconfig > /root/ligne.tmp
                          read bidon alt bidon < /root/ligne.tmp
                     else 
                          echo "Please put something in /home/sand/localconfig and restart observe-sqm-stepper.bash."
                     fi
                     /bin/echo "Latitude:" $lat ", Longitude:" $lon
                fi
           else  echo "GPS mode off"
           fi
      else
           let dodo=1
           /bin/sleep $dodo
      fi

      if [  $nobs != 9999 ] 
      then let i=i+1 #   never ending loop
      fi
      n=0
      echo "Start"
      echo "Observation number: " $count
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
      /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /root/sqmdata.tmp
      echo "End of reading"      
      read sqm < /root/sqmdata.tmp
      echo $sqm | sed 's/,/ /g' | sed 's/m//g' > /root/toto.tmp
      read bidon sb bidon < /root/toto.tmp
      # keep the sqm value in mag per square arc second
      sqmread[$n]=`/bin/echo $sb"+"${calib[$n]} |/usr/bin/bc -l`
      sqmreads[$n]=`printf "%0.2f\n" ${sqmread[$n]}`
      echo "Sky brightness in band " $n " = " ${sqmreads[$n]}
      # convert mag par sq arc second to flux
# convert mpsas to W cm-2 sr-1
# Sanchez de Miguel, A., M. Aube, Jaime Zamorano, M. Kocifaj, J. Roby, and C. Tapia. 
# "Sky Quality Meter measurements in a colour-changing world." 
# Monthly Notices of the Royal Astronomical Society 467, no. 3 (2017): 2966-2979.
#      sbcal[$n]=`/bin/echo "270.0038*10^(-0.4*"${sqmread[$n]}")" |/usr/bin/bc -l`
      sbcal[$n]=`/bin/echo "270.0038*e((-0.4*"${sqmread[$n]}")*l(10))" |/usr/bin/bc -l`
      sbcals[$n]=`printf "%0.6e\n" ${sbcal[$n]}`
      echo "Flux in band " $n " = "${sbcals[$n]}
      let n=n+1
   done
   echo ${sqmread[0]} | sed 's/\./ /g'  > /root/toto.tmp  # on decoupe les entiers et decimales de la mesure sqm
   read seuil toto toto < /root/toto.tmp
   nomfich=`date -u +"%Y-%m-%d"`
   nomfich=$nomfich".txt"
   time=`date +%Y-%m-%d" "%H:%M:%S`
   y=`date +%Y`
   mo=`date +%m`
   d=`date +%d`
   if [ ! -d /var/www/html/data/$y ]
   then mkdir /var/www/html/data/$y
   fi
   if [ ! -d /var/www/html/data/$y/$mo ]
   then /bin/mkdir /var/www/html/data/$y/$mo
   fi
   echo $time $lat $lon $alt $temp ${sqmreads[0]} ${sqmreads[1]} ${sqmreads[2]} ${sqmreads[3]} ${sqmreads[4]} ${sbcals[0]} ${sbcals[1]} ${sbcals[2]} ${sbcals[3]} ${sbcals[4]}>> /var/www/html/data/$y/$mo/$nomfich
   if [ $seuil -lt 12 ]
       then /bin/sleep $daydelay    # waiting when it is daytime
   fi 
done
echo "Parking filter wheel..."
let ang=-pos
/usr/local/bin/MoveStepFilterWheel.py $ang 0  
echo "Finish observe-sqm-stepper.bash"
exit 0



