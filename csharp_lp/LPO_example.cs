using System;
using Google.OrTools.LinearSolver;
using Serilog;

namespace ApiSupport;

public static class LPO_example
{
    /*******
    https://developers.google.com/optimization/introduction/dotnet
    
    Maximize 3x + y subject to the following constraints:

    0 ≤ x ≤ 1
    0 ≤ y ≤ 2
    x + y ≤ 2

    ********/
    public static void Solve()
    {
        // Create the linear solver with the GLOP backend.
        Solver solver = Solver.CreateSolver("GLOP");
        if (solver is null)
        {
            return;
        }

        // Create the variables x and y.
        Variable x = solver.MakeNumVar(0.0, 1.0, "x");
        Variable y = solver.MakeNumVar(0.0, 2.0, "y");

        Log.Information("Number of variables = " + solver.NumVariables());

        // Create a linear constraint, 0 <= x + y <= 2.
        Constraint ct = solver.MakeConstraint(0.0, 2.0, "ct");
        ct.SetCoefficient(x, 1);
        ct.SetCoefficient(y, 1);

        Log.Information("Number of constraints = " + solver.NumConstraints());

        // Create the objective function, 3 * x + y.
        Objective objective = solver.Objective();
        objective.SetCoefficient(x, 3);
        objective.SetCoefficient(y, 1);
        objective.SetMaximization();

        solver.Solve();

        Log.Information("Solution:");
        Log.Information("Objective value = " + solver.Objective().Value());
        Log.Information("x = " + x.SolutionValue());
        Log.Information("y = " + y.SolutionValue());
    }

}
