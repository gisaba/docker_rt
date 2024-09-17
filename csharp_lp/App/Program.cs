using Google.OrTools.Init;
using realtime;
using System.Diagnostics;

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
        const double time_period = 2; // ms
        //const double deadline = 1;  // ms
        double tempo_esecuzione = 0; 

        /***********************************************************/
        var stopwatch = new Stopwatch();
        stopwatch.Start();
        var primaEsecuzione = Lp.Solve();
        // var primaEsecuzione = fft.FFT(true,50,1000,100,false); 
        // f = 50 Hz , fc = 1 KHz , 100 periodi del segnale => CampioniSegnale = fc/f * Nperiodi
        // Campioni FFT = prima potenza di 2 > Nperiodi (Zero padding)
        stopwatch.Stop();
        double fi = stopwatch.Elapsed.TotalMilliseconds;
        /***********************************************************/
        Console.WriteLine("LPO");
        Console.WriteLine("rownumber,timestep,periodo");
        stopwatch.Reset();

        for (int idx_task = 0;idx_task<100000;idx_task++) 
        {    
            stopwatch.Start();
            /*********************FFT**************************************/
            // f = 50 Hz , fc = 1 KHz , 100 periodi del segnale => CampioniSegnale = fc/f * Nperiodi
            // Campioni FFT = prima potenza di 2 > Nperiodi (Zero padding)
            //tempo_esecuzione = fft.FFT(true,50,1000,100,false); 
            /**************************************************************/

            /*********************LPO**************************************/
            tempo_esecuzione = Lp.Solve();
            /**************************************************************/
            
            while (stopwatch.Elapsed.TotalMilliseconds < time_period);
            Console.WriteLine($"{idx_task},{tempo_esecuzione.ToString().Replace(",",".")},{stopwatch.Elapsed.TotalMilliseconds}");
            stopwatch.Reset();
            
            /*** DEBUG ****
            if (tempo_esecuzione <= deadline) 
            {               
                while (stopwatch.Elapsed.TotalMilliseconds < time_period);
                period = stopwatch.Elapsed.TotalMilliseconds;
                //Console.WriteLine($"{GREEN}OK: La funzione è stata eseguita entro il limite di {deadline} ms con {tempo_esecuzione} ms{NORMAL} - periodo: ms {period}      ");
                //Console.WriteLine($"OK: La funzione è stata eseguita entro il limite di {deadline} ms con {tempo_esecuzione} ms - periodo: ms {period}      ");
                stopwatch.Reset();
            } 
            else if ((tempo_esecuzione > deadline) && (tempo_esecuzione < time_period))
            {
                while (stopwatch.Elapsed.TotalMilliseconds < time_period);
                period = stopwatch.Elapsed.TotalMilliseconds;
                //Console.WriteLine($"{RED}OverRun: La funzione ha superato il limite di {deadline} ms con {tempo_esecuzione} ms{NORMAL} - periodo: ms {period}      ");
                Console.WriteLine($"OverRun: La funzione ha superato il limite di {deadline} ms con {tempo_esecuzione} ms - periodo: ms {period}      ");
                stopwatch.Reset();
            } else if (tempo_esecuzione > time_period)
            {
                while (stopwatch.Elapsed.TotalMilliseconds < time_period);
                period = stopwatch.Elapsed.TotalMilliseconds;
                Console.WriteLine($"OverRun: La funzione ha superato il limite di {deadline} ms con {tempo_esecuzione} ms - periodo: ms {period}      ");
                stopwatch.Reset();
            }
            */
        }
    }
}