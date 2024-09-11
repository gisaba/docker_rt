using System.Diagnostics;
using Google.OrTools.Init;
using Google.OrTools.LinearSolver;

namespace realtime;

public static class Lp
{
    /********
     Esempio: Minimizza una funzione con 3 variabili soggetta a:
     x + y + z <= 30
     2x + 3y + z <= 60
     x, y, z >= 0
    ********/

    public static void Solve()
    {
        var stopwatch = new Stopwatch();
        stopwatch.Start();

        Solver solver = Solver.CreateSolver("GLOP");
        if (solver is null)
        {
            return;
        }
        // x and y are continuous non-negative variables.
        Variable x = solver.MakeNumVar(0.0, double.PositiveInfinity, "x");
        Variable y = solver.MakeNumVar(0.0, double.PositiveInfinity, "y");

        Console.WriteLine("Number of variables = " + solver.NumVariables());

        // x + 2y <= 14.
        solver.Add(x + 2 * y <= 14.0);

        // 3x - y >= 0.
        solver.Add(3 * x - y >= 0.0);

        // x - y <= 2.
        solver.Add(x - y <= 2.0);

        Console.WriteLine("Number of constraints = " + solver.NumConstraints());

        // Objective function: 3x + 4y.
        solver.Maximize(3 * x + 4 * y);

        Solver.ResultStatus resultStatus = solver.Solve();

        // Check that the problem has an optimal solution.
        if (resultStatus != Solver.ResultStatus.OPTIMAL)
        {
            Console.WriteLine("The problem does not have an optimal solution!");
            return;
        }
        Console.WriteLine("Solution:");
        Console.WriteLine("Objective value = " + solver.Objective().Value());
        Console.WriteLine("x = " + x.SolutionValue());
        Console.WriteLine("y = " + y.SolutionValue());

        Console.WriteLine("\nAdvanced usage:");
        Console.WriteLine("Problem solved in " + solver.WallTime() + " milliseconds");
        Console.WriteLine("Problem solved in " + solver.Iterations() + " iterations");
    

        stopwatch.Stop();
        double elapsed = stopwatch.Elapsed.TotalMilliseconds;
        Console.WriteLine($"Task executed in ({elapsed} ms)");
    }
}
