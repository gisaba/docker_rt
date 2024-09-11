using Google.OrTools.Init;
using realtime;

internal class Program
{
    private static void Main(string[] args)
    {
        Console.WriteLine("Google.OrTools version: " + OrToolsVersion.VersionString());
        double tempo_massimo = 10;

        for (int i = 0;i<10;i++) {
            var tempo_esecuzione = Lp.Solve();
            
            if (Lp.Solve() < tempo_massimo) 
            {
                Console.WriteLine($"La funzione è stata eseguita entro il limite di {tempo_massimo} con {tempo_esecuzione} ms");
            } 
            else 
            {
                Console.WriteLine($"La funzione ha superato il limite di {tempo_massimo} ms");
            }
        }
    }
}
