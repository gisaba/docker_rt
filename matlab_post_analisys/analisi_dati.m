%% Analisi dei Dati

clear all;
clc;

t_deadline = 1;

%test = 'lpo';
test = 'fft';

profile = 'real-time';
%profile = 'balanced';

%linguaggio = 'python';
%linguaggio = 'csharp'
linguaggio = 'c';

%so = 'linux';
so = 'RaspberryPi-OS';

path_table_misure = ['./misure/' so '/'];

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
    opts.VariableNames = ["rownumber","timestep","periodo"];
    opts.VariableTypes = ["uint16", "double","double"];
    opts.ExtraColumnsRule = "ignore";
    opts.EmptyLineRule = "skip";
    opts.ConsecutiveDelimitersRule = "join";
     
    % avoid rows with text settings
    opts.ImportErrorRule = "omitrow";
    opts.MissingRule = "omitrow";
     
    % Import the data
    filename = strcat(path_table_misure, [profile '_' linguaggio '_' test]);
    TableFile = readtable(filename, opts);

    disp(['Analizzo i dati del test'])

    % Timestep

    Timestep = TableFile.timestep;
    Periodo = TableFile.periodo;

    Timestep(Timestep==0) = mean(Timestep);
    pd = fitdist(Timestep,'Lognormal');
    %pd = fitdist(Timestep,'Weibull');
    %pd = fitdist(Timestep,'Normal')
    
    step = 0.001;
    x_pdf = 0:step:max(Timestep);
    y = pdf(pd,x_pdf);

    mediaTimestep = [mediaTimestep;  mean(pd);];
    varTimestep = [varTimestep; var(pd)];
    devStdTimestep = [stdTimestep; std(pd)];

    [y_max, idx] = max(y);
    x = x_pdf(idx);
    modaTimestep = [modaTimestep;  x];

Table = table(modaTimestep, mediaTimestep,varTimestep,devStdTimestep);    
overrun = Timestep(Timestep>=t_deadline);
WCET = max(Timestep(Timestep<t_deadline));
BCET = min(Timestep(Timestep<t_deadline));
PeriodoMAX = max(Periodo);
PeriodoMIN = min(Periodo);
clearvars -except profile t_deadline filename path_table_misure PeriodoMAX PeriodoMIN WCET BCET test so linguaggio overrun T Table mediaTimestep varTimestep devStdTimestep varTimestep;

%% TimeStep

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
'Name', ['Tempi di esecuzione Task : ' test '-' linguaggio '-' so '-' profile ' Deadline: 1 ms']);

[y_max, idx] = max(y);
moda = x_pdf(idx);

histogram(dati,'Normalization','pdf');
line(x_pdf,y,'Color','blu','LineStyle','-','LineWidth',1.5);
txt = ['\leftarrow ' num2str(moda) ' ms'];
text(moda,y_max,txt,'Color','red','FontWeight','Bold','FontSize',20);
grid on
xlabel("TimeStep (ms)");
clearvars -except PeriodoMAX PeriodoMIN WCET BCET test linguaggio so overrun mediaTimestepPD devStdTimestepPD varTimestepPD moda mediaTimestep varTimestep devStdTimestep;


