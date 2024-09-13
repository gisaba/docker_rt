using System.Diagnostics;
using System.Security.Principal;
using Google.OrTools.Init;
using Google.OrTools.LinearSolver;

namespace realtime;

public static class fft
{

public static double FFT(bool shape_window,int lengh_fft)
    {
        double[] signal = new double[lengh_fft];
        
        int sampleRate = 1_600; // 1600/32 = 50Hz di risoluzione in frequenza
        //  villas signal -f json -F 50 -r 1600 -a 1.414 sine | villas pipe -f json mqtt.conf mqtt_node
        
        for ( int idx=0; idx<lengh_fft;idx++)
        {
            signal[idx] = Lp.GetRandomNumber(0,1);
        }

        var stopwatch = new Stopwatch();
        stopwatch.Start();

        // Shape the signal using a Hanning window
        if (shape_window){
            var window = new FftSharp.Windows.Hanning();
            window.ApplyInPlace(signal);
        }

        // calculate the power spectral density using FFT
        System.Numerics.Complex[] spectrum = FftSharp.FFT.Forward(signal);

        // or get the magnitude (units²) or power (dB) as real numbers
        // double[] magnitude = FftSharp.FFT.Magnitude(spectrum);                  // magnitude (units²)
        double[] power = FftSharp.FFT.Power(spectrum);                             // power spectral density (dB)
        //double[] freq = FftSharp.FFT.FrequencyScale(power.Length, sampleRate);

        /*
        for (int i = 0; i < spectrum.Length/2; i++)
            Log.Information($"Indice: {i} Frequency: {freq[i]}, Power: {Math.Round(power[i],3)}");
        
        //Log.Information($"CC Frequency: {freq[0]} Hz, Power: {Math.Round(psd[0],3)} dB");
        //Log.Information($"Fodamentale Frequency: {freq[1]} Hz, Power: {Math.Round(psd[1],3)} dB");
        Log.Information("********************************************************");
        */
        stopwatch.Stop();
        double elapsed = stopwatch.Elapsed.TotalMilliseconds;

        return elapsed;
    }
}