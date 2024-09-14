using System.Diagnostics;
using System.Drawing;
using ScottPlot.Plottables;
using System.Security.Principal;
using Google.OrTools.Init;
using Google.OrTools.LinearSolver;

namespace realtime;

public static class fft
{

public static double FFT(bool shape_window,int frequency,int sampleRate,int periodi,bool DEBUG)
    {        
        double p = 1;
        int lengh_signal = (sampleRate/frequency) * periodi;
        while(Math.Pow(2,p)<lengh_signal) {p++;}
        var l_fft = (int)Math.Pow(2,p);

        // sampleRate/frequency = risoluzione in frequenza
        double[] signal = Signal(lengh_signal,l_fft,frequency,sampleRate,DEBUG);

        /**************************TASK*********************************/
        var stopwatch = new Stopwatch();
        stopwatch.Start();

        // Shape the signal using a Hanning window
        if (shape_window){
            var window = new FftSharp.Windows.Hanning();
            window.ApplyInPlace(signal);
        }

        // calculate the power spectral density using FFT
        System.Numerics.Complex[] spectrum = FftSharp.FFT.Forward(signal);
        double[] power = FftSharp.FFT.Power(spectrum);                             // power spectral density (dB)

        /*
        for (int i = 0; i < spectrum.Length/2; i++)
            Log.Information($"Indice: {i} Frequency: {freq[i]}, Power: {Math.Round(power[i],3)}");
        
        //Log.Information($"CC Frequency: {freq[0]} Hz, Power: {Math.Round(psd[0],3)} dB");
        //Log.Information($"Fodamentale Frequency: {freq[1]} Hz, Power: {Math.Round(psd[1],3)} dB");
        Log.Information("********************************************************");
        */

        /***********************************************************/

        stopwatch.Stop();
        double elapsed = stopwatch.Elapsed.TotalMilliseconds;

        if (DEBUG)
        {
            double[] freq = FftSharp.FFT.FrequencyScale(power.Length, sampleRate);
            double[] ploFFT = new double[power.Length/2-1];
            double[] ploFreq = new double[power.Length/2-1];
            
            Array.Copy(power, 0, ploFFT, 0, power.Length/2-1);
            Array.Copy(freq, 0, ploFreq, 0, power.Length/2-1);
            // plot the sample audio
            ScottPlot.Plot plt = new ScottPlot.Plot();
            plt.Add.ScatterLine(ploFreq,ploFFT);
            plt.YLabel("Power (dB)");
            plt.XLabel("Frequency (Hz)");
            plt.SavePng("periodogram.png",640,300);
        }

        return elapsed;
    }

    public static double[] Signal(int lengh_signal,int l_fft,int frequency, int sampleRate, bool DEBUG)
    {       
        short[] buffer = new short[l_fft];
        short[] buffer2 = new short[l_fft];
        short[] buffer3 = new short[l_fft];
        double[] signal = new double[l_fft];

        double amplitude = Lp.GetRandomNumber(220,221)*Math.Sqrt(2);
        double samplePeriod = sampleRate / frequency;

        for (int n = 0; n < lengh_signal; n++)
        {
            buffer[n] = (short)(amplitude * Math.Sin((2 * Math.PI * n * frequency) / sampleRate));
            buffer2[n] = (short)(amplitude/10 * Math.Sin((2 * Math.PI * n * (2*frequency)) / sampleRate));
            buffer3[n] = (short)(amplitude/100 * Math.Sin((2 * Math.PI * n * (3*frequency)) / sampleRate));
            signal[n] = (buffer[n]+buffer2[n]+buffer3[n]);
        }

        for (int z = lengh_signal; z < l_fft; z++) { signal[z] = 0; }

        if (DEBUG)
        {
            // plot the sample signal
            ScottPlot.Plot plt = new();
            plt.Add.Signal(signal, samplePeriod,ScottPlot.Color.FromColor(Color.Red));
            plt.YLabel("Amplitude");
            plt.SavePng("time-series.png",2048,300);
        }
        return signal;
    }
}