%% Parse File Iperf

clear all;
clc;


    fid = fopen(['./time.log'],'r');
    
    disp_line = 0;
    
    timestep = [];
    overrun = [];
    error = [];
    
    tline = fgetl(fid);
    
    while ischar(tline)
                    
                tline = tline(1:end);

                L = strlength(tline);
                
                if (L > 100)
                    
                    idxOK = regexp(tline,'[92mOK');
                    idxKO = regexp(tline,'OverRun:');
                    
                    if (idxOK > 0)
                        l = 'eseguita entro il limite di 10 ms con';
                        start = regexp(tline,l) + strlength(l)+1;
                        stop = start + 3;
                        timestep = [timestep; tline(start:stop)];    
                    else
                        l = 'superato il limite di 10 ms con';
                        start = regexp(tline,l) + strlength(l)+1;
                        stop = start + 3;
                        timestep = [timestep; tline(start:stop)]; 
                        overrun = [overrun; tline(start:stop)];
                    end
                end
                
                tline = fgetl(fid);
    end
    
    L = height(timestep);       
    rownumber = (1:L)';
    T = table(rownumber,timestep);
    %writetable(T,['./' 'data_parsed_' convertStringsToChars(test) '.txt']);
    writetable(T,['./' 'data_parsed.txt']);
    %type tabledata.txt
    
    fclose(fid);

clearvars -except T timestep overrun error;