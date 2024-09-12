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

    public static double GetRandomNumber(double minimum, double maximum)
    { 
        Random random = new Random();
        return random.NextDouble() * (maximum - minimum) + minimum;
    }

    public static double Solve()
    {
        var stopwatch = new Stopwatch();
        stopwatch.Start();

        Solver solver = Solver.CreateSolver("GLOP");
        if (solver is null)
        {
            return -1;
        }
        // x and y are continuous non-negative variables.
        Variable x = solver.MakeNumVar(GetRandomNumber(1,10), double.PositiveInfinity, "x");
        Variable y = solver.MakeNumVar(GetRandomNumber(1,10), double.PositiveInfinity, "y");
        Variable z = solver.MakeNumVar(GetRandomNumber(1,10), double.PositiveInfinity, "z");

        /********
        Esempio: Minimizza una funzione con 3 variabili soggetta a:
        x + y + z <= 30
        2x + 3y + z <= 60
        x, y, z >= 0
        ********/

        solver.Add(x + y + z <= 30.0);
        solver.Add(2 * x + 3 * y + z <= 60.0);
        solver.Add(x + y + z >= 0);

        // Objective function: 
        solver.Minimize(x + y + z);
        solver.Minimize(2 * x + 3 * y + z);

        Solver.ResultStatus resultStatus = solver.Solve();

        // Check that the problem has an optimal solution.
        if (resultStatus != Solver.ResultStatus.OPTIMAL)
        {
            Console.WriteLine("The problem does not have an optimal solution!");
            return -1;
        }

        stopwatch.Stop();
        double elapsed = stopwatch.Elapsed.TotalMilliseconds;
/*
        Console.WriteLine("Number of variables = " + solver.NumVariables());

        Console.WriteLine("Number of constraints = " + solver.NumConstraints());

        Console.WriteLine("********* Solution:");
        Console.WriteLine("Objective value = " + solver.Objective().Value());
        Console.WriteLine("x = " + x.SolutionValue());
        Console.WriteLine("y = " + y.SolutionValue());
        Console.WriteLine("z = " + z.SolutionValue());
*/
        return elapsed;
    }
}
