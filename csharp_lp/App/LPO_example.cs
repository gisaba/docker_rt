using System.Diagnostics;
using Google.OrTools.LinearSolver;

namespace realtime;

public static class LPO_example
{
    /********
    https://developers.google.com/optimization/introduction/dotnet
    
    Maximize 3x + y subject to the following constraints:

    0 ≤ x ≤ 1
    0 ≤ y ≤ 2
    x + y ≤ 2

    ********/
    public static void Solve()
    {
        var stopwatch = new Stopwatch();
        stopwatch.Start();

        // Create the linear solver with the GLOP backend.
        Solver solver = Solver.CreateSolver("GLOP");
        if (solver is null)
        {
            return;
        }

        // Create the variables x and y.
        Variable x = solver.MakeNumVar(0.0, 1.0, "x");
        Variable y = solver.MakeNumVar(0.0, 2.0, "y");

        //Console.WriteLine("Number of variables = " + solver.NumVa riables());

        // Create a linear constraint, 0 <= x + y <= 2.
        Constraint ct = solver.MakeConstraint(0.0, 2.0, "ct");
        ct.SetCoefficient(x, 1);
        ct.SetCoefficient(y, 1);

        //Console.WriteLine("Number of constraints = " + solver.NumConstraints());

        // Create the objective function, 3 * x + y.
        Objective objective = solver.Objective();
        objective.SetCoefficient(x, 3);
        objective.SetCoefficient(y, 1);
        objective.SetMaximization();

        solver.Solve();

        stopwatch.Stop();
        double elapsed = stopwatch.Elapsed.TotalMilliseconds;
        Console.WriteLine($"Task executed in ({elapsed} ms)");

        //Console.WriteLine("Solution:");
        //Console.WriteLine("Objective value = " + solver.Objective().Value());
        //Console.WriteLine("x = " + x.SolutionValue());
        //Console.WriteLine("y = " + y.SolutionValue());
    }

}
