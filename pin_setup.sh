#!/bin/bash 

# Configure the PRU pins based on which Beagle is running
echo "*******************************************************"
machine=$(awk '{print $NF}' /proc/device-tree/model)
channel="TM1_Channel TM2_channel"
echo -n $machine
if [ $machine = "Black" ]; then
    echo " Beagle Found"
    pins="P8_27 P8_28 "
elif [ $machine = "Blue" ]; then
    echo " Beagle  Found"
    pins=""
elif [ $machine = "PocketBeagle" ]; then
    echo " Beagle Found"
   pins="P2_35 P1_35 "
else
    echo " Not Found"
    pins=""
fi
x=1;
echo "*******************************************************"
echo "Configuring pinmux"

for pin in $pins
do
    config-pin $pin pruin
    echo "TM"$x "Channel"
    config-pin -q $pin
    x=2;
done

echo "*******************************************************"
