#!/usr/bin/python3
# move the filter wheel using half step mode on a bipolar stepper
# 
# usage: move_filter.py steps slow_level
# steps = number of steps (400 for a complete rotation)
# slow_level 1=fastest n=max_speed/n
import RPi.GPIO as GPIO
import time

GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

# Enable pins for IN1-4 to control step sequence

coil_A_1_pin = 16
coil_A_2_pin = 12
coil_B_1_pin = 20
coil_B_2_pin = 21

# Set pin states

GPIO.setup(coil_A_1_pin, GPIO.OUT)
GPIO.setup(coil_A_2_pin, GPIO.OUT)
GPIO.setup(coil_B_1_pin, GPIO.OUT)
GPIO.setup(coil_B_2_pin, GPIO.OUT)

# Function for step sequence
def setStep(w1, w2, w3, w4):
  time.sleep(delay)
  GPIO.output(coil_A_1_pin, w1)
  GPIO.output(coil_A_2_pin, w2)
  GPIO.output(coil_B_1_pin, w3)
  GPIO.output(coil_B_2_pin, w4)

# loop through step sequence based on number of steps
setStep(1,0,1,0)
