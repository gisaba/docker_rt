import gpiod

import time

LED_PIN = 17  # GPIO pin number where the LED is connected

# Open GPIO chip

chip = gpiod.Chip('gpiochip4')

# Get the GPIO line for the LED

led_line = chip.get_line(LED_PIN)

# Request exclusive access to the line and configure it as an output

led_line.request(consumer="LED", type=gpiod.LINE_REQ_DIR_OUT)

try:

   while True:

       led_line.set_value(1)  # Turn on the LED

       time.sleep(1)  # Wait for 1 second

       led_line.set_value(0)  # Turn off the LED

       time.sleep(1)  # Wait for 1 second

finally:

   # Release the GPIO line and clean up resources on program exit

   led_line.release()

   chip.close()