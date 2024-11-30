import RPi.GPIO as GPIO
import time

# Definizione dei pin GPIO
MISO = 19  # Pin GPIO usato per il Master In Slave Out
MOSI = 20  # Pin GPIO usato per il Master Out Slave In
SCLK = 21  # Pin GPIO usato per il Clock SPI
CS = 18    # Pin GPIO usato per Chip Select (Slave Select)

class SPISlave:
    def __init__(self, miso, mosi, sclk, cs):
        self.miso = miso
        self.mosi = mosi
        self.sclk = sclk
        self.cs = cs
        self.received_data = []
        self.transmit_data = []

        # Configurazione dei pin
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.miso, GPIO.OUT)
        GPIO.setup(self.mosi, GPIO.IN)
        GPIO.setup(self.sclk, GPIO.IN)
        GPIO.setup(self.cs, GPIO.IN, pull_up_down=GPIO.PUD_UP)

    def listen(self):
        """
        Ascolta il bus SPI per la comunicazione con il master.
        """
        self.received_data = []
        while GPIO.input(self.cs) == GPIO.LOW:  # CS attivo (LOW)
            if GPIO.input(self.sclk) == GPIO.HIGH:  # Flusso dati
                bit = GPIO.input(self.mosi)
                self.received_data.append(bit)
                print(f"Bit ricevuto: {bit}")

                # Invio del prossimo bit al master (se disponibile)
                if self.transmit_data:
                    next_bit = self.transmit_data.pop(0)
                    GPIO.output(self.miso, next_bit)
                time.sleep(0.001)  # Breve ritardo per la sincronizzazione

        print("Dati ricevuti:", self.received_data)

    def send_data(self, data):
        """
        Imposta i dati da trasmettere (lista di bit: 0 o 1).
        """
        self.transmit_data = data[:]

    def cleanup(self):
        GPIO.cleanup()

# Esecuzione principale
if __name__ == "__main__":
    spi_slave = SPISlave(MISO, MOSI, SCLK, CS)
    try:
        # Simulazione: dati da trasmettere al master
        spi_slave.send_data([1, 0, 1, 1, 0, 0, 1, 0])  # Esempio: byte 0b10110010
        print("SPI slave in esecuzione. In attesa di dati...")
        
        while True:
            if GPIO.input(CS) == GPIO.LOW:  # CS attivo
                spi_slave.listen()
            time.sleep(0.1)  # Evita utilizzo CPU al 100%
    except KeyboardInterrupt:
        print("Terminazione manuale.")
    finally:
        spi_slave.cleanup()
        print("SPI slave terminato.")
