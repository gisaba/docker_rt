using Google.OrTools.Init;
using realtime;

internal class Program
{
    private static void Main(string[] args)
    {
        Console.WriteLine("Google.OrTools version: " + OrToolsVersion.VersionString());
        
        for (int i = 0;i<10;i++){
            
            Lp.Solve();
            //LPO_example.Solve();
            
        }
    }
}
