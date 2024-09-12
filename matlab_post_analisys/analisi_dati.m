%% Analisi dei Dati

% Algoritmo 
% Per ogni test effettuato
        % Carico Table con il test da analizzare
        
        % Analizzo i dati creando le distibuzioni statistiche
        
        % Memorizzo i dati caratteristici del test in un vettore 
        
        % Memorizzo in un vetttore i parametri caratteristici della
        % distribuzione e dati caratteristici (Moda,media ,varianza ecc)

        % Plot Condizione test --> postprocessing 

        % cercare la curva che mminimizza errore quadratico medio 
% FINE CICLO

clear all;
clc;

path_table_misure = './';

modaTimestep = [];
mediaTimestep = [];
varTimestep = [];
stdTimestep = [];

modaOverRun = [];
mediaOverRun = [];
varOverRun = [];
stdOverRun = [];
    
    opts = delimitedTextImportOptions("NumVariables", 2);
    opts.DataLines = [2, Inf];
    opts.Delimiter = ["\t", ","];
    opts.VariableNames = ["rownumber","timestep"];
    opts.VariableTypes = ["uint16", "double"];
    opts.ExtraColumnsRule = "ignore";
    opts.EmptyLineRule = "skip";
    opts.ConsecutiveDelimitersRule = "join";
     
    % avoid rows with text settings
    opts.ImportErrorRule = "omitrow";
    opts.MissingRule = "omitrow";
     
    % Import the data
    filename = strcat(path_table_misure, 'data_parsed.txt');
    TableFile = readtable(filename, opts);

    disp(['Analizzo i dati del test'])

    % Jitter

    Timestep = TableFile.timestep;

    Timestep(Timestep==0) = mean(Timestep);
    pd = fitdist(Timestep,'Lognormal');
    %pd = fitdist(Jitter,'Weibull');
    %pd = fitdist(Jitter,'Normal')
    
    x_pdf = 0:0.01:max(Timestep);
    y = pdf(pd,x_pdf);

    mediaTimestep = [mediaTimestep;  mean(pd);];
    varTimestep = [varTimestep; var(pd)];
    devStdTimestep = [stdTimestep; std(pd)];

    [y_max, idx] = max(y);
    x = x_pdf(idx);
    modaTimestep = [modaTimestep;  x];

%datagramUDPSize = Test';
Table = table(modaTimestep, mediaTimestep,varTimestep,devStdTimestep);    
clearvars -except T Table mediaTimestep varTimestep devStdTimestep varTimestep;

%% TimeStep

datagramSize = ['Time Step'];

path_table_misure = './data_parsed.txt';
opts = delimitedTextImportOptions("NumVariables", 2);
opts.DataLines = [2, Inf];
opts.Delimiter = ["\t", ","];
opts.VariableNames = ["rownumber","timestep"];
opts.VariableTypes = ["uint16", "double"];
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "skip";
opts.ConsecutiveDelimitersRule = "join";
 
% avoid rows with text settings
opts.ImportErrorRule = "omitrow";
opts.MissingRule = "omitrow";
 
% Import the data
filename = strcat(path_table_misure);
TableFile = readtable(filename, opts);

step = 0.001;
dati = TableFile.timestep;
TypeDist = 'Lognormal';
%pd = fitdist(dati,'Weibull');
%pd = fitdist(dati,'Normal')

valMedio = mean(dati);
dati(dati==0) = valMedio;

pd = fitdist(dati,TypeDist);
x_pdf = 0:step:max(dati);
y = pdf(pd,x_pdf);

mediaTimestepPD = mean(pd);
devStdTimestepPD = std(pd);
varTimestepPD = var(pd);
FigH = figure;

set(FigH, 'NumberTitle', 'off', ...
'Name', ['Datagram Size: ' datagramSize]);

[y_max, idx] = max(y);
moda = x_pdf(idx);

histogram(dati,'Normalization','pdf');
line(x_pdf,y,'Color','blu','LineStyle','-','LineWidth',1.5);
txt = ['\leftarrow ' num2str(moda) ' ms'];
text(moda,y_max,txt,'Color','red','FontWeight','Bold','FontSize',20);
grid on
xlabel("TimeStep (ms)");
clearvars -except mediaTimestepPD devStdTimestepPD varTimestepPD moda mediaTimestep varTimestep devStdTimestep;


