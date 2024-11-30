import pigpio

# Definizione dei pin GPIO
MISO = 19  # Pin GPIO usato per il Master In Slave Out
MOSI = 20  # Pin GPIO usato per il Master Out Slave In
SCLK = 21  # Pin GPIO usato per il Clock SPI
CS = 18    # Pin GPIO usato per Chip Select (Slave Select)

class SPISlave:
    def __init__(self, pi, miso, mosi, sclk, cs):
        self.pi = pi
        self.miso = miso
        self.mosi = mosi
        self.sclk = sclk
        self.cs = cs
        self.received_data = []
        self.transmit_data = []

        # Configurazione dei pin
        pi.set_mode(miso, pigpio.OUTPUT)
        pi.set_mode(mosi, pigpio.INPUT)
        pi.set_mode(sclk, pigpio.INPUT)
        pi.set_mode(cs, pigpio.INPUT)

        # Impostazione callback
        self.cb_cs = pi.callback(cs, pigpio.EITHER_EDGE, self.cs_callback)
        self.cb_sclk = pi.callback(sclk, pigpio.RISING_EDGE, self.sclk_callback)

    def cs_callback(self, gpio, level, tick):
        if level == 0:  # Chip Select attivo (LOW)
            self.received_data = []
        else:  # Chip Select inattivo (HIGH)
            print("Dati ricevuti:", self.received_data)
            self.transmit_data = []  # Reset dei dati da trasmettere

    def sclk_callback(self, gpio, level, tick):
        if self.pi.read(self.cs) == 0:  # Solo se CS è attivo
            bit = self.pi.read(self.mosi)
            self.received_data.append(bit)
            
            # Invio del bit successivo (se disponibile)
            if self.transmit_data:
                next_bit = self.transmit_data.pop(0)
                self.pi.write(self.miso, next_bit)

    def send_data(self, data):
        """
        Imposta i dati da trasmettere (lista di bit: 0 o 1).
        """
        self.transmit_data = data[:]

    def close(self):
        self.cb_cs.cancel()
        self.cb_sclk.cancel()
        self.pi.stop()

# Inizializzazione
pi = pigpio.pi()
if not pi.connected:
    raise RuntimeError("Impossibile connettersi al demone pigpio")

try:
    spi_slave = SPISlave(pi, MISO, MOSI, SCLK, CS)
    
    # Simulazione: dati da trasmettere al master
    spi_slave.send_data([1, 0, 1, 1, 0, 0, 1, 0])  # Esempio: byte 0b10110010
    
    print("SPI slave in esecuzione. In attesa di dati...")
    input("Premi INVIO per terminare...")
finally:
    spi_slave.close()
    print("SPI slave terminato.")
