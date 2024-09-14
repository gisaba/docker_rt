using Google.OrTools.Init;
using realtime;

internal class Program
{
    private static void Main(string[] args)
    {
        string NL          = Environment.NewLine; // shortcut
        string NORMAL      = Console.IsOutputRedirected ? "" : "\x1b[39m";
        string RED         = Console.IsOutputRedirected ? "" : "\x1b[91m";
        string GREEN       = Console.IsOutputRedirected ? "" : "\x1b[92m";
        string YELLOW      = Console.IsOutputRedirected ? "" : "\x1b[93m";
        string BLUE        = Console.IsOutputRedirected ? "" : "\x1b[94m";
        string MAGENTA     = Console.IsOutputRedirected ? "" : "\x1b[95m";
        string CYAN        = Console.IsOutputRedirected ? "" : "\x1b[96m";
        string GREY        = Console.IsOutputRedirected ? "" : "\x1b[97m";
        string BOLD        = Console.IsOutputRedirected ? "" : "\x1b[1m";
        string NOBOLD      = Console.IsOutputRedirected ? "" : "\x1b[22m";
        string UNDERLINE   = Console.IsOutputRedirected ? "" : "\x1b[4m";
        string NOUNDERLINE = Console.IsOutputRedirected ? "" : "\x1b[24m";
        string REVERSE     = Console.IsOutputRedirected ? "" : "\x1b[7m";
        string NOREVERSE   = Console.IsOutputRedirected ? "" : "\x1b[27m";

        //Console.WriteLine("Google.OrTools version: " + OrToolsVersion.VersionString());
        double tempo_massimo = 10;
        var primaEsecuzione = fft.FFT(true,50,1000,100,true); 
        // f = 50 Hz , fc = 1 KHz , 100 periodi del segnale => CampioniSegnale = fc/f * Nperiodi
        // Campioni FFT = prima potenza di 2 > Nperiodi (Zero padding)

        for (int i = 0;i<100000;i++) 
        {    
            //Console.WriteLine($"*********** {BLUE}Esecuzione numero {i}{NORMAL} ***********");
            //var tempo_esecuzione = Lp.Solve();

            var tempo_esecuzione = fft.FFT(true,50,1000,100,false); 
            // f = 50 Hz , fc = 1 KHz , 100 periodi del segnale => CampioniSegnale = fc/f * Nperiodi
            // Campioni FFT = prima potenza di 2 > Nperiodi (Zero padding)

            if (tempo_esecuzione < tempo_massimo) 
            {
                Console.WriteLine($"{GREEN}OK: La funzione è stata eseguita entro il limite di {tempo_massimo} ms con {tempo_esecuzione}   ms{NORMAL}");
            } 
            else 
            {
                Console.WriteLine($"{RED}OverRun: La funzione ha superato il limite di {tempo_massimo} ms con {tempo_esecuzione}           ms{NORMAL}");
            }
        }
    }
}