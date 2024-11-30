import spidev
import time

# Configurazione del bus SPI
SPI_BUS = 0   # Numero del bus SPI
SPI_DEVICE = 0  # Numero del dispositivo SPI (CS0 o CS1)

class SPIMaster:
    def __init__(self, bus, device):
        self.spi = spidev.SpiDev()
        self.bus = bus
        self.device = device
        self.spi.open(bus, device)  # Apre il bus e il dispositivo
        self.spi.max_speed_hz = 500000  # Imposta la velocità SPI (500 kHz)
        self.spi.mode = 0b00  # Modalità SPI: CPOL=0, CPHA=0
        print(f"SPI master inizializzato su bus {bus}, dispositivo {device}")

    def transfer(self, data):
        """
        Invia e riceve dati sul bus SPI.
        :param data: Lista di byte da inviare
        :return: Lista di byte ricevuti
        """
        print(f"Inviando: {data}")
        response = self.spi.xfer2(data)  # Invia dati e riceve la risposta
        print(f"Ricevuto: {response}")
        return response

    def close(self):
        """
        Chiude la connessione SPI.
        """
        self.spi.close()
        print("Connessione SPI chiusa.")

# Esempio principale
if __name__ == "__main__":
    try:
        spi_master = SPIMaster(SPI_BUS, SPI_DEVICE)
        
        # Loop continuo per trasmissione SPI
        print("Inizio trasmissione SPI (premi Ctrl+C per interrompere)...")
        while True:
            # Dati da inviare
            data_to_send = [0x01, 0x02, 0x03, 0x04]
            
            # Trasferimento dati
            response = spi_master.transfer(data_to_send)
            
            # Attesa di 1 secondo prima del prossimo ciclo
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nTerminazione manuale.")
    finally:
        spi_master.close()
