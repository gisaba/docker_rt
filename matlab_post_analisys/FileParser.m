%% Parse File Log Time Step di Esecuzione

clear all;
clc;

    %test = 'lpo';
    test = 'fft';

    %linguaggio = 'python';
    linguaggio = 'csharp';
    
    so = 'linux';
    %so = 'macos';
    
    fid = fopen(['./time_' linguaggio '_' test '.' so],'r');
    %fid = fopen(['./time_' linguaggio '.log'],'r');
    
    disp_line = 0;
    
    timestep = [];
    
    tline = fgetl(fid); 
    
    while ischar(tline)
                    
                tline = tline(1:end);

                L = strlength(tline);
                
                if (L > 100)
                    
                    idxOK = regexp(tline,'OK: La funzione è stata eseguita entro il limite di');
                    idxKO = regexp(tline,'OverRun: La funzione ha superato il limite di');
                    
                    if (idxOK > 0)
                        l = 'eseguita entro il limite di 10 ms con';
                        start = regexp(tline,l) + strlength(l)+1;
                        stop = start + 3;
                        timestep = [timestep; tline(start:stop)];    
                    elseif (idxKO > 0)
                        l = 'superato il limite di 10 ms con';
                        start = regexp(tline,l) + strlength(l)+1;
                        stop = start + 3;
                        timestep = [timestep; tline(start:stop)]; 
                    end
                end
                
                tline = fgetl(fid);
    end

    L = height(timestep);       
    rownumber = (1:L)';
    T = table(rownumber,timestep);
    writetable(T,['./' 'data_parsed_' linguaggio '.txt']);
    
    fclose(fid);

clearvars -except test linguaggio so T timestep overrun error;