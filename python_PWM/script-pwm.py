from RPIO import PWM

# Setup PWM and DMA channel 0
PWM.setup()
PWM.init_channel(0)

# Add some pulses to the subcycle
PWM.add_channel_pulse(0, 17, 0, 50)
PWM.add_channel_pulse(0, 17, 100, 50)

# Stop PWM for specific GPIO on channel 0
PWM.clear_channel_gpio(0, 17)

# Shutdown all PWM and DMA activity
PWM.cleanup()