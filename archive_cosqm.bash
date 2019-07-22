#!/bin/bash 
#
#program to archive cosqm network data
cosqm_addr=(192.168.0.100 161.72.128.52 vpn.izana.org:5080 193.146.80.130:5180 )
cosqm_name=(Saint-Camille Observatorio_Teide Santa-Cruz_Tenerife Pico_Teide)
cd /var/www/html/DATA/CoSQM-Network
n=0
while [ $n -le ${#cosqm_addr[*]} ]
do addr=${cosqm_addr[$n]}
   name=${cosqm_name[$n]}
   let n=n+1
   echo "Downloading " $name " ..." $n"/"${#cosqm_addr[*]}
   rm -fr $addr
   wget -q -r -N -R "index.html*" http://$addr/data/
   echo $name " done."
   rm -fr $name
   mv -f $addr $name
done
