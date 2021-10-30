#!/bin/bash 
#
#   
#    Copyright (C) 2020  Martin Aube
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
# find integer brightness
#
findIntBrightness () {
    sleep $waittime
    /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /root/sqmdata.tmp    
    read sqm < /root/sqmdata.tmp
    echo $sqm | sed -e 's/,/ /g' | sed -e 's/m/ /g' | sed -e 's/\./ /g' > /root/toto.tmp
    read bidon sqmm sqmd bidon < /root/toto.tmp
    # remove leading zero to the sky brightness
    if [ ${sqmm:0:1} == 0 ]
    then sqmm=`echo $sqmm | sed -e 's/0//g'`
    fi
    if [ ${sqmd:0:1} == 0 ]
    then sqmd=`echo $sqmd | sed -e 's/0//g'`
    fi
    let meas=sqmm*100+sqmd
}

#
# =============================
# find appropriate integration time
#
findIntegration () {
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
     #  The integration time can be calculated with t=2.37E-25*SB**18.98
     /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /root/sqmdata.tmp
     read sqm < /root/sqmdata.tmp
     echo $sqm | sed -e 's/,/ /g' | sed -e 's/s//g' | sed -e 's/C/ C/g' > /root/toto.tmp
     read bidon bidon bidon bidon tim temp bidon < /root/toto.tmp
     echo "Decimal readout time: " $tim
     echo "Int time: " $tim >> /var/www/html/data/$y/$mo/cosqm.log
     # default wait time set to the acquisition time with the red filter
     echo $tim | sed -e 's/\./ /g'  > /root/toto.tmp
     read tim timd toto < /root/toto.tmp
     echo $tim | sed -e 's/000//g' | sed -e 's/00//g' > /root/toto.tmp
     read tim toto < /root/toto.tmp
     waittime=$tim"."$timd
}


# ==================================
# global positioning system
globalpos () {
#
#    reading 10 gps transactions
#
#     /bin/echo "Waiting 10 sec for GPS reading..."
#     sleep 10
     rm -f /root/*.tmp
     

     bash -c '/usr/bin/gpspipe -w -n 5 | sed -e "s/,/\n/g" | grep lat | tail -1 | sed "s/n\"/ /g" |sed -e "s/\"/ /g" | sed -e "s/:/ /g" | sed -e"s/lat//g" | sed -e "s/ //g" > /home/sand/coords.tmp'
     read lat < /home/sand/coords.tmp
     bash -c '/usr/bin/gpspipe -w -n 5 | sed -e "s/,/\n/g" | grep lon | tail -1 | sed "s/n\"/ /g" |sed -e "s/\"/ /g" | sed -e "s/:/ /g" | sed -e "s/lo//g" | sed -e "s/ //g" > /home/sand/coords.tmp'
     read lon < /home/sand/coords.tmp
     bash -c '/usr/bin/gpspipe -w -n 5 | sed -e "s/,/\n/g" | grep alt | tail -1 | sed "s/n\"/ /g" |sed -e "s/\"/ /g" | sed -e "s/:/ /g" | sed -e "s/alt//g" | sed -e "s/ //g" > /home/sand/coords.tmp'
     read alt < /home/sand/coords.tmp
     echo $lat $lon $alt


     /bin/echo "GPS is connected, reading lat lon data. Longitude:" $lon
     if [ -z "${lon}" ]
     then let lon=0
          let lat=0
          let alt=0
     fi 
     /bin/echo "GPS gives Latitude:" $lat ", Longitude:" $lon "and Altitude:" $alt
     /bin/echo "Lat.:" $lat ", Lon.:" $lon " Alt.:" $alt  >> /var/www/html/data/$y/$mo/cosqm.log
     echo $gpsdate >> /root/datedugps
}


#
# ==================================
#
# main
#
# activate gps option 0=off 1=on
gpsf=0
gpsport="ttyACM0"
nobs=9999  		# number of times measured if 9999 then infinity
waittime=10             # at a mag of about 24 the integration time is around 60s
minim=900 # minimal value of the interval of sky brightness optimal to find SQM position suggested value 900 with the red filter
#
# set band list
# wavelengths 0:= Clear ,1:= Red 2:= Green ,3:= Blue ,4:= Yellow
#
filters=( 0 1 2 3 4 )
nbands=4  # we now exclude filter 4 (yellow)
calib=( 0.0 0.0 0.0 0.0 0.0 ) # magnitude offset for each filter
ang=80  # steps between each filter (400 for the complete rotation)
fname=(Clear Red Green Blue Yellow)
grep sqmIP /home/sand/localconfig > /root/toto # sqmIP est le mot cle cherche dans le localconfig 
read bidon sqmip bidon < /root/toto
# one complete rotation in half step mode 400
pos=0
count=1
newstep=0
tim=0
lon="0"
lat="0"
alt="0"
sleep 10  # let 10 second to the gps to cleanly startup
/bin/grep "Site_name" /home/sand/localconfig > /root/ligne.tmp
read bidon NAME bidon < /root/ligne.tmp
# Setting led parameters
# Exports pin to userspace
if [ ! -e /sys/class/gpio/gpio13 ]; then
	bash -c 'echo "13" > /sys/class/gpio/export'
fi               
# Sets gpio 13 as an output for the LED
if [ ! -e /sys/class/gpio/export/13/direction ]; then
	bash -c 'echo "out" > /sys/class/gpio/gpio13/direction'
fi
bash -c 'echo "1" > /sys/class/gpio/gpio13/value'
sleep 2
bash -c 'echo "0" > /sys/class/gpio/gpio13/value'
#=====          
#
# main loop
#
time1=`date +%s`
i=0
while [ $i -lt $nobs ]
do    y=`date +%Y`
      mo=`date +%m`
      # check for sufficient darkness while on park position
      findIntegration
      findIntBrightness
      while [ $meas -le $minim ]    # too bright it is daytime
      do findIntBrightness
         timetmp=`date`
	 echo "Brightness = " $meas "Wait 1 min until twilight ("$minim"<(SBx100))"
         echo "BrightLev= " $meas $timetmp >> /var/www/html/data/$y/$mo/cosqm.log
         # blink the led to indicate that the cosqm is waiting for the twilight
         del=0
         while [ $del -le 3 ]
         do bash -c 'echo "1" > /sys/class/gpio/gpio13/value'
            sleep 19
            bash -c 'echo "0" > /sys/class/gpio/gpio13/value'
            sleep 1
            let del=del+1        
         done
      done
      #
      #  searching for gps
      #
      if [ $gpsf -eq 1 ] 
      then echo "GPS mode activated"
           if [ `ls /dev | grep $gpsport`  ] 
           then echo "GPS look present."
                globalpos
           else /bin/echo "GPS not present: using coords. from localconfig"
                /bin/echo "GPS not present" >> /var/www/html/data/$y/$mo/cosqm.log
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
                     echo "Please edit /home/sand/localconfig and restart observe-sqm-stepper.bash."
                fi
           fi
      else echo "GPS mode off"
           echo "GPS mode off" >> /var/www/html/data/$y/$mo/cosqm.log
           if [ `grep -c " " /home/sand/localconfig` -ne 0 ]
           then /bin/grep Longitude /home/sand/localconfig > /root/ligne.tmp
                read bidon lon bidon < /root/ligne.tmp
                /bin/grep Latitude /home/sand/localconfig > /root/ligne.tmp
                read bidon lat bidon < /root/ligne.tmp
                /bin/grep Altitude /home/sand/localconfig > /root/ligne.tmp
                read bidon alt bidon < /root/ligne.tmp
           else 
                echo "Please edit /home/sand/localconfig and restart observe-sqm-stepper.bash."
           fi
      fi
      # flash 10 times the LED to indicate that the measurement sequence is beginning
      led=0
      while [ $led -le 10 ]
      do bash -c 'echo "1" > /sys/class/gpio/gpio13/value'
         sleep 0.25
         bash -c 'echo "0" > /sys/class/gpio/gpio13/value'
         sleep 0.25
         let led=led+1
      done
      findIntBrightness
      if [ $meas -gt $minim ]    # the night has begun
      then recentime=0
           let count=count+1
           # go to the red filter to find the relevant integration time for that sequence of measurements
           /usr/local/bin/zero_pos.py
           /usr/local/bin/move_filter.py $ang 1
           findIntegration
           y=`date +%Y`
           mo=`date +%m`
           d=`date +%d`
           if [ ! -d /var/www/html/data/$y ]
           then mkdir /var/www/html/data/$y
           fi
           if [ ! -d /var/www/html/data/$y/$mo ]
           then /bin/mkdir /var/www/html/data/$y/$mo
           fi
           echo "=========================="
           echo "Start measurement #" $count
           echo "Meas #" $count >> /var/www/html/data/$y/$mo/cosqm.log
           if [  $nobs != 9999 ] 
           then let i=i+1 #   never ending loop
           fi
           n=0
           /usr/local/bin/zero_pos.py
           while [ $n -lt $nbands ]
           do filter=${filters[$n]}
              echo "Reading sqm, Filter: " $n
              /bin/sleep $waittime  # let enough time to be sure that the reading comes from that filter
              /bin/sleep 5.0
	      /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /root/sqmdata.tmp
              read sqm < /root/sqmdata.tmp
              echo $sqm | sed -e 's/,/ /g' | sed -e 's/m//g' > /root/toto.tmp
              read bidon sb bidon < /root/toto.tmp
              # keep the sqm value in mag per square arc second
              sqmread[$n]=`/bin/echo $sb"+"${calib[$n]} |/usr/bin/bc -l`
              sqmreads[$n]=`printf "%0.2f\n" ${sqmread[$n]}`
              echo "Sky brightness in band " $n " = " ${sqmreads[$n]}
              echo "Bright " $n " = " ${sqmreads[$n]} >> /var/www/html/data/$y/$mo/cosqm.log
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
              /usr/local/bin/move_filter.py $ang 1
           done
           # here we should be at the park position (filter yellow)
           # short 3 blinks of the led after measurement sequence after parking to yellow
           led=0
           while [ $led -le 3 ]
           do bash -c 'echo "1" > /sys/class/gpio/gpio13/value'
              sleep 0.25
              bash -c 'echo "0" > /sys/class/gpio/gpio13/value'
              sleep 0.25
              let led=led+1
           done
           nomfich=`date -u +"%Y-%m-%d"`
           nomfich=$nomfich".txt"
           time=`date +%Y-%m-%d" "%H-%M-%S`
           echo "Time of writing:" $time >> /var/www/html/data/$y/$mo/cosqm.log
           echo $time $lat $lon $alt $temp $waittime ${sqmreads[0]} ${sqmreads[1]} ${sqmreads[2]} ${sqmreads[3]} ${sqmreads[4]} ${sbcals[0]} ${sbcals[1]} ${sbcals[2]} ${sbcals[3]} ${sbcals[4]}>> /var/www/html/data/$y/$mo/$nomfich
      fi
      time2=`date +%s`
      let idle=150-time2+time1  # one measurement every 2.5 min
      if [ $idle -lt 0 ] ; then let idle=0; fi
      echo "Wait " $idle "s before next reading."
      echo "Wait " $idle "s" >> /var/www/html/data/$y/$mo/cosqm.log
      bash -c 'echo "1" > /sys/class/gpio/gpio13/value'
      /bin/sleep $idle
      bash -c 'echo "0" > /sys/class/gpio/gpio13/value'
      time1=`date +%s`
done
echo "End of observe-sqm-stepper.bash"
echo "End of observe-sqm-stepper.bash" >> /var/www/html/data/$y/$mo/cosqm.log
exit 0
