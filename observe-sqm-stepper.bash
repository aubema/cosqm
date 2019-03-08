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
# find integer brightness
#
findIntBrightness () {
    sleep $waittime
    /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /root/sqmdata.tmp    
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
     echo $sqm | sed 's/,/ /g' | sed 's/s//g' | sed 's/C/ C/g' > /root/toto.tmp
     read bidon bidon bidon bidon tim temp bidon < /root/toto.tmp
     echo "Decimal readout time: " $tim  
     # default wait time set to the acquisition time with the red filter
     echo $tim | sed 's/\./ /g'  > /root/toto.tmp
     read tim timd toto < /root/toto.tmp
     echo $tim | sed 's/000//g'  > /root/toto.tmp
     read tim toto < /root/toto.tmp
     waittime=$tim"."$timd
}


findSQM () {
# =============================
# find the clear filter position
#
    echo "================================="
    echo "Searching for the clear filter..."
    maxbright=99999
    maxgrightpos=0
    findIntegration
    n=0
    while [ $n -lt ${#filters[*]} ]
    do filter=${filters[$n]}
       destina=${filterpos[$n]}
       let ang=destina-pos
       # moving filter wheel
       echo "Moving the filter wheel to filter " $n "("${fname[$n]}")"
       let pos=pos+ang
       # echo "Moving to position " $pos $ang $destina $n
       /usr/local/bin/MoveStepFilterWheel.py $ang 0  
       echo "Reading sqm, Filter: " $n
       # echo "Waiting time:" $waittime
       /bin/sleep $waittime  # let enough time to be sure that the reading comes from
       # that filter
       /bin/sleep 0.5
       findIntBrightness 
       if [ $meas -lt $maxbright ]
       then let maxbright=meas
            let maxbrightpos=pos
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
      echo "Move to clear filter"
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
    echo "======================================"
    echo "Searching for nearest filter center..."
     npeak=0
     findIntegration
#     let destina=possqm-maxstep/10-2*movestep

#echo $destina $possqm $maxstep $movestep $pos

#     if [ $destina -lt 0 ]
#     then let destina=destina+maxstep
#     fi
#     let ang=destina-pos
#     /usr/local/bin/MoveStepFilterWheel.py $ang 0
      let newstep=maxstep/5/movestep+1   # move before the preceeding peak
    # let newstep=4*3-1
#     let pos=pos+ang

     let n=0
     let memoi=0
     echo "Iter Pos SB"
     while [ $n -le $newstep ]
     do /usr/local/bin/MoveStepFilterWheel.py $movestep 0
	findIntBrightness
	echo $n $pos $meas
	if [ $meas -gt $memoi ]
        then let memoi=meas
             let pospeak=pos
	     let npeak=n
        fi
	let pos=pos+movestep
        let n=n+1
     done
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
     echo "Filter positions:" ${filterpos[*]}
     # go to clear filter
     n=0
     destina=${filterpos[$n]}
     echo  "Moving to clear filter"
     let ang=destina-pos
     let pos=pos+ang
     /usr/local/bin/MoveStepFilterWheel.py $ang 0
}
# ==================================
# global positioning system
globalpos () {
#
#    reading 10 gps transactions
#
     /bin/echo "Waiting 10 sec for GPS reading..."
     sleep 10
     /usr/bin/gpspipe -w -n 10 > /root/coords.tmp &
     sleep 1
     killall gpspipe
     /usr/bin/tail -2 /root/coords.tmp | sed 's/,/\n/g' | sed 's/"//g' | sed 's/:/ /g'> /root/bidon.tmp
     grep lat /root/bidon.tmp > /root/bidon1.tmp
     read bidon lat bidon1 < /root/bidon1.tmp
     grep lon /root/bidon.tmp > /root/bidon1.tmp
     read bidon lon bidon1 < /root/bidon1.tmp
     grep alt /root/bidon.tmp > /root/bidon1.tmp
     read bidon alt bidon1 < /root/bidon1.tmp
     grep activated /root/bidon.tmp > /root/bidon1.tmp 
     read bidon gpsdate bidon1 < /root/bidon1.tmp
     # /bin/echo "GPS is connected, reading lat lon data. Longitude:" $lon
     if [ -z "${lon}" ]
     then let lon=0
          let lat=0
          let alt=0
     fi 
     /bin/echo "GPS gives Latitude:" $lat ", Longitude:" $lon "and Altitude:" $alt
     # set computer time
     # pkill ntpd
     #sleep 2
     echo $gpsdate >> /root/datedugps
     #date -s "$gpsdate"
     #/usr/sbin/ntpd   
}
#
# ==================================
# ==================================
# main
# activate gps option 0=off 1=on
gpsf=1
gpsport="ttyACM0"
nobs=9999  		# number of times measured if 9999 then infinity
waittime=10             # at a mag of about 24 the integration time is around 60s
maxstep=2040
nmeas=5000                 # lowest number of measurements before a possible new scan of the filter wheel
maxInt=20               # maximal allowed integration time
# After startup of the CoSQM, We search for the SQM position of the filter wheel 
# during twilight (around SB=12)
# At that moment the sky is relatively uniform and the integration time is short
# minim should be written as 100xSkyBrightness (e.g for Sky brightness of 11.0 you 
# should write 1100
minim=800 # minimal value of the interval of sky brightness optimal to find SQM position sugg. 1000
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
grep sqmIP /home/sand/localconfig > /root/toto # sqmIP est le mot cle cherche dans le localconfig 
      # echo "Required acquistion time:" $waittime
read bidon sqmip bidon < /root/toto
# one complete rotation in half step mode (mode 1) is maxstep=4080 i.e. 1 step = 0.087890625 deg
# if you use the full step mode (mode 0) then maxstep=2040 is the number of steps i.e. 1 step = 0.17578125
pos=0
scandone=0
count=1
newstep=0
tim=0
let movestep=maxstep/128
sleep 10  # let 10 second to the gps to cleanly startup
/bin/grep "Site_name" /home/sand/localconfig > /root/ligne.tmp
read bidon NAME bidon < /root/ligne.tmp
#
# main loop
#
time1=`date +%s`
i=0
while [ $i -lt $nobs ]
do    findIntegration
      while [ $tim -ge $maxInt ]
      do echo "Too dark, waiting 1 min"
	 sleep 60
         findIntegration
      done
      findIntBrightness
      while [ $meas -le $minim ]    # too bright it is daytime
      do findIntBrightness
	      echo "Brightness = " $meas "Wait 1 min until twilight ("$minim"<(SBx100))"
	 sleep 60
      done
      if [ $scandone -eq 0 ]
      then center
           findSQM
	   scandone=1
      fi
      #
      #  searching for gps
      #
      if [ $gpsf -eq 1 ] 
      then echo "GPS mode activated"
           if [ `ls /dev | grep $gpsport`  ] 
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
                # /bin/echo "Latitude:" $lat ", Longitude:" $lon
           fi
      else  echo "GPS mode off"
      fi
      echo "=========================="
      echo "Start measurement #" $count"/"$nmeas "before rescan of the SQM position."
      if [ $scandone -eq 1 ]
      then  findIntBrightness
            recentime=0
            if [ $count -eq $nmeas ]
            then count=1
	         if [ $meas -lt $minim ]  # reset the filter wheel scan flag for the next day
                 then scandone=0
	         else center
                      findSQM
                 fi
	    else let count=count+1
            fi
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
               # echo "Moving to position " $pos $ang $destina $n
               /usr/local/bin/MoveStepFilterWheel.py $ang 0  
               echo "Reading sqm, Filter: " $n
               # echo "Waiting time:" $waittime
               /bin/sleep $waittime  # let enough time to be sure that the reading comes from
 	       # that filter
               /bin/sleep 0.5
	       /usr/local/bin/sqmleread.pl $sqmip 10001 1 > /root/sqmdata.tmp
               # echo "End of reading"      
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
      time2=`date +%s`
      let idle=150-time2+time1  # one measurement every 2.5 min
      echo $idle $time1 $time2
      if [ $idle -lt 0 ] ; then let idle=0; fi
      echo "Wait " $idle "s before next reading."
      /bin/sleep $idle
      time1=`date +%s`

done
echo "End of observe-sqm-stepper.bash"
exit 0



