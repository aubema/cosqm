#!/bin/bash 
#
#   
#    Copyright (C) 2019  Martin Aube
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
    /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /home/sand/sqmdata.tmp    
    read sqm < /home/sand/sqmdata.tmp
    echo $sqm | sed -e 's/,/ /g' | sed -e 's/m/ /g' | sed -e 's/\./ /g' > /home/sand/toto.tmp
    read bidon sqmm sqmd bidon < /home/sand/toto.tmp
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
     /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /home/sand/sqmdata.tmp
     read sqm < /home/sand/sqmdata.tmp
     echo $sqm | sed -e 's/,/ /g' | sed -e 's/s//g' | sed -e 's/C/ C/g' > /home/sand/toto.tmp
     read bidon bidon bidon bidon tim temp bidon < /home/sand/toto.tmp
     echo "Decimal readout time: " $tim
     echo "Int time: " $tim >> /var/www/html/data/$y/$mo/cosqm.log
     # default wait time set to the acquisition time with the red filter
     echo $tim | sed -e 's/\./ /g'  > /home/sand/toto.tmp
     read tim timd toto < /home/sand/toto.tmp
     echo $tim | sed -e 's/000//g' | sed -e 's/00//g' > /home/sand/toto.tmp
     read tim toto < /home/sand/toto.tmp
     waittime=$tim"."$timd
}


findSQM () {
# =============================
# find the clear filter position
#
    echo "================================="
    echo "Searching for the clear filter..."
    echo "Search clear" >> /var/www/html/data/$y/$mo/cosqm.log
    maxbright=99999
    maxgrightpos=0
    nmoy=5    # number of scan to average for a better retreival of the clear filter
    findIntegration
    nn=0
    let moy[0]=0
    let moy[1]=0
    let moy[2]=0
    let moy[3]=0
    let moy[4]=0
    while [ $nn -le $nmoy ]
    do echo "Finding clear filter...  SCAn # " $nn
       echo "Find clear, SCAn # " $nn >> /var/www/html/data/$y/$mo/cosqm.log
       n=0
       while [ $n -le ${#filters[*]} ]
       do filter=${filters[$n]}
          destina=${filterpos[$n]}
          let ang=destina-pos
          # moving filter wheel
          echo "Moving the filter wheel to filter position " $n
          let pos=pos+ang
          sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
          /usr/local/bin/MoveStepFilterWheel.py $ang 0
          sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
          echo "Reading sqm at position: " $n
          echo "Reading sqm at position: " $n >> /var/www/html/data/$y/$mo/cosqm.log
          /bin/sleep $waittime  # let enough time to be sure that the reading comes from that filter
          /bin/sleep 0.1
          findIntBrightness 
          let IntBright[$n]=meas
          echo "n="$n " SB=" $meas
          echo "n="$n " SB=" $meas  >> /var/www/html/data/$y/$mo/cosqm.log
          let moy[$n]=moy[$n]+IntBright[$n]
          let n=n+1
       done
       let nn=nn+1
    done
    n=0
    while [ $n -le ${#filters[*]} ]
    do let IntBright[$n]=moy[$n]/nmoy
       let n=n+1
    done
    # correct for possible drift in the brightness during the scan
    let drift=IntBright[5]-IntBright[0]
    n=0
    while [ $n -lt ${#filters[*]} ]
    do let IntBright[$n]=IntBright[$n]-drift*n/5
       if [ ${IntBright[$n]} -lt $maxbright ]
       then let maxbright=IntBright[$n]
            let maxbrightpos=${filterpos[$n]}
       fi
       let n=n+1
    done
    let possqm=maxbrightpos
    let filterpos[0]=possqm
    let filterpos[1]=possqm+maxstep/5
    if [ ${filterpos[1]} -gt $maxstep ]
    then let filterpos[1]=filterpos[1]-maxstep
    fi
    let filterpos[2]=possqm+2*maxstep/5
    if [ ${filterpos[2]} -gt $maxstep ]
    then let filterpos[2]=filterpos[2]-maxstep
    fi
    let filterpos[3]=possqm+3*maxstep/5
    if [ ${filterpos[3]} -gt $maxstep ]
    then let filterpos[3]=filterpos[3]-maxstep
    fi
    let filterpos[4]=possqm+4*maxstep/5
    if [ ${filterpos[4]} -gt $maxstep ]
    then let filterpos[4]=filterpos[4]-maxstep
    fi
    destina=${filterpos[0]}
    let ang=destina-pos
    # moving filter wheel
    echo "Moving the filter wheel to filter " $n "("${fname[0]}")"
    let pos=pos+ang
    /usr/local/bin/MoveStepFilterWheel.py $ang 0   
}


#######
# filter center
center () {
    
    mes0=99999
    # approximate position of the clear
    let ang=maxstep/10
    findIntegration
    findIntBrightness
    let pos0=pos
    let mes0=meas
    /usr/local/bin/MoveStepFilterWheel.py $ang 0
    let pos=pos+ang
    findIntBrightness
    if [ $meas -lt $mes0 ]
    then let pos0=pos
         let mes0=meas
    fi
    /usr/local/bin/MoveStepFilterWheel.py $ang 0
    let pos=pos+ang
    findIntBrightness
    if [ $meas -lt $mes0 ]
    then let pos0=pos
         let mes0=meas
    fi
    /usr/local/bin/MoveStepFilterWheel.py $ang 0
    let pos=pos+ang
    findIntBrightness
    if [ $meas -lt $mes0 ]
    then let pos0=pos
         let mes0=meas
    fi
    /usr/local/bin/MoveStepFilterWheel.py $ang 0
    let pos=pos+ang
    findIntBrightness
    if [ $meas -lt $mes0 ]
    then let pos0=pos
         let mes0=meas
    fi
    /usr/local/bin/MoveStepFilterWheel.py $ang 0
    let pos=pos+ang
    findIntBrightness
    if [ $meas -lt $mes0 ]
    then let pos0=pos
         let mes0=meas
    fi
    /usr/local/bin/MoveStepFilterWheel.py $ang 0
    let pos=pos+ang
    findIntBrightness
    if [ $meas -lt $mes0 ]
    then let pos0=pos
         let mes0=meas
    fi
    /usr/local/bin/MoveStepFilterWheel.py $ang 0
    let pos=pos+ang
    findIntBrightness
    if [ $meas -lt $mes0 ]
    then let pos0=pos
         let mes0=meas
    fi
    /usr/local/bin/MoveStepFilterWheel.py $ang 0
    let pos=pos+ang
    findIntBrightness
    if [ $meas -lt $mes0 ]
    then let pos0=pos
         let mes0=meas
    fi


# goto approx clear
let ang=pos0-pos
/usr/local/bin/MoveStepFilterWheel.py $ang 0
let pos=pos+ang

    let newstep=maxstep/5/movestep+1
    let ang=maxstep/2-maxstep/10
    /usr/local/bin/MoveStepFilterWheel.py $ang 0
    let pos=pos+ang

    echo "Searching for nearest filter center..."
    echo "Search filter center..."  >> /var/www/html/data/$y/$mo/cosqm.log
       findIntegration
       let n=0
       let memoi=0
       echo -e "Iter \t\t Pos \t\t SB"
       echo -e "Iter \t\t Pos \t\t SB"  >> /var/www/html/data/$y/$mo/cosqm.log
       while [ $n -le $newstep ]
       do findIntBrightness
	  echo -e $n "\t\t" $pos "\t\t" $meas
          echo -e $n "\t\t" $pos "\t\t" $meas >> /var/www/html/data/$y/$mo/cosqm.log
	  if [ $meas -gt $memoi ]
          then let memoi=meas
               let pospeak=pos
          fi
          sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
          /usr/local/bin/MoveStepFilterWheel.py $movestep 0
	  let pos=pos+movestep
          sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
          let n=n+1
       done
echo "peak 1=" $pospeak
echo "newstep" $newstep $pospeak $pos

    # add 1/10 of the total tics to find the center of the filter
    let possqm=pospeak+maxstep/10
    if [ $possqm -gt $maxstep ] 
    then let possqm=possqm-maxstep-1
    fi
    if [ $possqm -lt -$maxstep ] 
    then let possqm=possqm+maxstep+1
    fi
    # set filters position array
    let filterpos[0]=possqm
    let filterpos[1]=possqm+maxstep/5
    if [ ${filterpos[1]} -gt $maxstep ]
    then let filterpos[1]=filterpos[1]-maxstep
    fi
    let filterpos[2]=possqm+2*maxstep/5
    if [ ${filterpos[2]} -gt $maxstep ]
    then let filterpos[2]=filterpos[2]-maxstep
    fi
    let filterpos[3]=possqm+3*maxstep/5
    if [ ${filterpos[3]} -gt $maxstep ]
    then let filterpos[3]=filterpos[3]-maxstep
    fi
    let filterpos[4]=possqm+4*maxstep/5
    if [ ${filterpos[4]} -gt $maxstep ]
    then let filterpos[4]=filterpos[4]-maxstep
    fi
    let filterpos[5]=possqm+5*maxstep/5
    if [ ${filterpos[5]} -gt $maxstep ]
    then let filterpos[5]=filterpos[5]-maxstep
    fi
}


# ==================================
# global positioning system
globalpos () {
#
#    reading 10 gps transactions
#
#     /bin/echo "Waiting 10 sec for GPS reading..."
#     sleep 10
     rm -f /home/sand/*.tmp
     sh -c '/usr/bin/gpspipe -w -n 10 > /home/sand/coords.tmp &'
     killall -s SIGINT gpspipe 
     var=$(/usr/bin/tail -2 /home/sand/coords.tmp | sed -e 's/,/\n/g' | sed -e 's/"//g' | sed -e 's/:/ /g' | grep lat)
     lat=$(echo $var|/usr/bin/awk '{print $2}')
     echo $var > /home/sand/toto.tmp
     read bidon lat bidon < /home/sand/toto.tmp
     var=$(/usr/bin/tail -2 /home/sand/coords.tmp | sed -e 's/,/\n/g' | sed -e 's/"//g' | sed -e 's/:/ /g' | grep lon)
     lon=$(echo $var|/usr/bin/awk '{print $2}')
          echo $lon $lat "var" $var
     var=$(/usr/bin/tail -2 /home/sand/coords.tmp | sed -e 's/,/\n/g' | sed -e 's/"//g' | sed -e 's/:/ /g' | grep alt)
     alt=$(echo $var|/usr/bin/awk '{print $2}')
     var=$(/usr/bin/tail -2 /home/sand/coords.tmp | sed -e 's/,/\n/g' | sed -e 's/"//g' | sed -e 's/:/ /g' | grep activated)
     gpsdate=$(echo $var|/usr/bin/awk '{print $2}')    

     # /bin/echo "GPS is connected, reading lat lon data. Longitude:" $lon
     if [ -z "${lon}" ]
     then let lon=0
          let lat=0
          let alt=0
     fi 
     /bin/echo "GPS gives Latitude:" $lat ", Longitude:" $lon "and Altitude:" $alt
     /bin/echo "Lat.:" $lat ", Lon.:" $lon " Alt.:" $alt  >> /var/www/html/data/$y/$mo/cosqm.log
     # set computer time
     # pkill ntpd
     #sleep 2
     echo $gpsdate >> /home/sand/datedugps
     #date -s "$gpsdate"
     #/usr/sbin/ntpd
}


#
# ==================================
# main
# activate gps option 0=off 1=on
gpsf=1
gpsport="ttyACM0"
nobs=9999  		# number of times measured if 9999 then infinity
waittime=10             # at a mag of about 24 the integration time is around 60s
maxstep=2040            # this is inherent to the motor and mode used
# After startup of the CoSQM, We search for the SQM position of the filter wheel 
# during twilight (around SB=11)
# At that moment the sky is relatively uniform and the integration time is short
# minim should be written as 100xSkyBrightness (e.g for Sky brightness of 9.0 you 
# should write 900
minim=900 # minimal value of the interval of sky brightness optimal to find SQM position suggested value 900
scanlevel=1500  # must be brightest than that level to perfore the filter scans, i.e. brightness values lower that scanlevel/100 suggested value 1100
#
# set band list
# wavelengths 0:= Clear ,1:= Red 2:= Green ,3:= Blue ,4:= Yellow
#
filters=( 0 1 2 3 4 )
calib=( 0.0 0.0 0.0 0.0 0.0 )
filterpos=( 0 0 0 0 0 )
possqm=0
# calib is the magnitude offset for each filter
fname=(Clear Red Green Blue Yellow)
grep sqmIP /home/sand/localconfig > /home/sand/toto # sqmIP est le mot cle cherche dans le localconfig 
read bidon sqmip bidon < /home/sand/toto
# one complete rotation in half step mode (mode 1) is maxstep=4080 i.e. 1 step = 0.087890625 deg
# if you use the full step mode (mode 0) then maxstep=2040 is the number of steps i.e. 1 step = 0.17578125
pos=0
scandone=0
count=1
newstep=0
tim=0
let movestep=maxstep/128
sleep 10  # let 10 second to the gps to cleanly startup
/bin/grep "Site_name" /home/sand/localconfig > /home/sand/ligne.tmp
read bidon NAME bidon < /home/sand/ligne.tmp
#setting led parameters
#   Exports pin to userspace
if [ ! -e /sys/class/gpio/gpio18 ]; then
	sh -c 'echo "18" > /sys/class/gpio/export'
fi               
# Sets pin 18 as an output
if [ ! -e /sys/class/gpio/export/18/direction ]; then
	sh -c 'echo "out" > /sys/class/gpio/gpio18/direction'
fi
sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
sleep 2
sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
#
# main loop
#
time1=`date +%s`
i=0
while [ $i -lt $nobs ]
do    y=`date +%Y`
      mo=`date +%m`
      findIntegration
      findIntBrightness
      while [ $meas -le $minim ] && [ $scandone -eq 0 ]   # too bright it is daytime
      do findIntBrightness
	 echo "Brightness = " $meas "Wait 1 min until twilight ("$minim"<(SBx100))"
         echo "BrightLev= " $meas >> /var/www/html/data/$y/$mo/cosqm.log
         scandone=0
# blink the led to indicate that the cosqm is waiting for the twilight
         sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
         sleep 19
         sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
         sleep 1         
         sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
         sleep 19
         sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
         sleep 1
         sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
         sleep 19
         sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
         sleep 1         
#	 sleep 60
      done
      if [ $scandone -eq 0 ]                                    # filter scan not yet done today
      then echo "Brightness = " $meas
           echo "Brightness = " $meas >> /var/www/html/data/$y/$mo/cosqm.log
           if [ $meas -le $scanlevel ] && [ $meas -ge $minim ]  # it is twilight
           then center
                findSQM
	        scandone=1
                count=0
           fi
      fi
      #
      #  searching for gps
      #
      if [ $gpsf -eq 1 ] 
      then echo "GPS mode activated"
#           echo "GPS mode activated" >> /var/www/html/data/$y/$mo/cosqm.log
           if [ `ls /dev | grep $gpsport`  ] 
           then echo "GPS look present."
#                echo "GPS look present." >> /var/www/html/data/$y/$mo/cosqm.log
                globalpos
           else /bin/echo "GPS not present: using coords. from localconfig"
                /bin/echo "GPS not present" >> /var/www/html/data/$y/$mo/cosqm.log
                #
                #  reading longitude and latitude from localconfig
                #
                if [ `grep -c " " /home/sand/localconfig` -ne 0 ]
                then /bin/grep Longitude /home/sand/localconfig > /home/sand/ligne.tmp
                     read bidon lon bidon < /home/sand/ligne.tmp
                     /bin/grep Latitude /home/sand/localconfig > /home/sand/ligne.tmp
                     read bidon lat bidon < /home/sand/ligne.tmp
                     /bin/grep Altitude /home/sand/localconfig > /home/sand/ligne.tmp
                     read bidon alt bidon < /home/sand/ligne.tmp
                else 
                     echo "Please put something in /home/sand/localconfig and restart observe-sqm-stepper.bash."
#                     echo "Please put something in /home/sand/localconfig and restart observe-sqm-stepper.bash." >> /var/www/html/data/$y/$mo/cosqm.log
                fi
           fi
      else echo "GPS mode off"
           echo "GPS mode off" >> /var/www/html/data/$y/$mo/cosqm.log
      fi
      if [ $scandone -eq 1 ]
      then  # flash 10 times the LED to indicate that the measurement sequence is beginning
            sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
            sleep 0.25
            sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
            sleep 10
            findIntBrightness
            if [ $meas -gt $minim ]    # too bright it is daytime
            then recentime=0
                 let count=count+1
                 echo "=========================="
                 echo "Start measurement #" $count
                 echo "Meas #" $count >> /var/www/html/data/$y/$mo/cosqm.log
                 if [  $nobs != 9999 ] 
                 then let i=i+1 #   never ending loop
                 fi
                 n=0
                 while [ $n -lt ${#filters[*]} ]
                 do filter=${filters[$n]}
	                destina=${filterpos[$n]}
                    let ang=destina-pos
                    # moving filter wheel
                    echo "Moving the filter wheel to filter " $n "("${fname[$n]}")"
                    let pos=pos+ang
                    /usr/local/bin/MoveStepFilterWheel.py $ang 0  
                    echo "Reading sqm, Filter: " $n
                    /bin/sleep $waittime  # let enough time to be sure that the reading comes from
 	            # that filter
                    /bin/sleep 5.0
	            /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /home/sand/sqmdata.tmp
                    read sqm < /home/sand/sqmdata.tmp
                    echo $sqm | sed -e 's/,/ /g' | sed -e 's/m//g' > /home/sand/toto.tmp
                    read bidon sb bidon < /home/sand/toto.tmp
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
                 done
                 # short blink of the led after measurement sequence
                 sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
                 sleep 0.25
                 sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
                 sleep 0.25
                 sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
                 sleep 0.25
                 sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
                 sleep 0.25
                 sh -c 'echo "1" > /sys/class/gpio/gpio18/value'
                 sleep 0.25
                 sh -c 'echo "0" > /sys/class/gpio/gpio18/value'
                 sleep 0.25
                 # goto the red filter to protect the sqm lens
                 destina=${filterpos[1]}
                 let ang=destina-pos
                 # moving filter wheel
                 echo "Moving the filter wheel to filter 1 ("${fname[1]}")"
                 echo "Moving to "${fname[1]} >> /var/www/html/data/$y/$mo/cosqm.log
                 let pos=pos+ang
                 /usr/local/bin/MoveStepFilterWheel.py $ang 0      
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
                 echo $time $lat $lon $alt $temp $waittime ${sqmreads[0]} ${sqmreads[1]} ${sqmreads[2]} ${sqmreads[3]} ${sqmreads[4]} ${sbcals[0]} ${sbcals[1]} ${sbcals[2]} ${sbcals[3]} ${sbcals[4]}>> /var/www/html/data/$y/$mo/$nomfich
            fi
      fi
      time2=`date +%s`
      let idle=150-time2+time1  # one measurement every 2.5 min
      if [ $idle -lt 0 ] ; then let idle=0; fi
      echo "Wait " $idle "s before next reading."
      echo "Wait " $idle "s" >> /var/www/html/data/$y/$mo/cosqm.log
      /bin/sleep $idle
      time1=`date +%s`
done
echo "End of observe-sqm-stepper.bash"
echo "End of observe-sqm-stepper.bash" >> /var/www/html/data/$y/$mo/cosqm.log
exit 0
