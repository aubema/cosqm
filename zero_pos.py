#!/usr/bin/python
import RPi.GPIO as GPIO
import time
import sys

# Variables
steps = 400
delay = 0.005

GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

# Enable pins for IN1-4 to control step sequence
print("enable pins")
coil_A_1_pin = 16
coil_A_2_pin = 12
coil_B_1_pin = 20
coil_B_2_pin = 21

# Set pin states

GPIO.setup(coil_A_1_pin, GPIO.OUT)
GPIO.setup(coil_A_2_pin, GPIO.OUT)
GPIO.setup(coil_B_1_pin, GPIO.OUT)
GPIO.setup(coil_B_2_pin, GPIO.OUT)

# set the sensor pin
sensor_gpio=3
GPIO.setup(sensor_gpio, GPIO.IN)



# Function for step sequence
def setStep(w1, w2, w3, w4):
  time.sleep(delay)
  GPIO.output(coil_A_1_pin, w1)
  GPIO.output(coil_A_2_pin, w2)
  GPIO.output(coil_B_1_pin, w3)
  GPIO.output(coil_B_2_pin, w4)

# loop through step sequence based on number of steps
j=0

for i in range(0, steps):
	if GPIO.input(sensor_gpio)==0:
		break
	j=j+1
	if j==1:
       		setStep(0,0,1,0)
    	if j==2:
       		setStep(0,1,1,0)
    	if j==3:
      		setStep(0,1,0,0)
    	if j==4:
       		setStep(0,1,0,1)
    	if j==5:
       		setStep(0,0,0,1)
    	if j==6:
       		setStep(1,0,0,1)
    	if j==7:
       		setStep(1,0,0,0)
    	if j==8:
       		setStep(1,0,1,0)
       		j=0
setStep(0,0,1,0)
setStep(0,1,1,0)
setStep(0,1,0,0)
setStep(0,1,0,1)