function [sameDateFiles,dateList] = groupByDate(fileList)
%
% [sameDateFiles,dateList] = groupByDate(fileList)
%   Groups files by date listed in file name.
%
%   Input:
%   fileList    structure with 'name' field containing all file names
%               Note: file names must be of the format '*_yyyymmdd_*',
%               where yyyymmdd is the date.
%
%   Output:
%       sameDateFiles   something
%       dateList    something
%
% IDENTIFIER FOR OUR CUSTOM LAB CODE
    
    dateList = cell(1);
    sameDateFiles={};
    numDates=0;
    numFiles_perDate = 0;
    
    for iFile = 1:length(fileList)
        
        % skip any files with 'marked' in the name
        if ~isempty(strfind(fileList(iFile).name,'marked'))
            continue;
        end
        
        % identify date in file name
        C = textscan(lower(fileList(iFile).name),'gridcalibration_%8s_*');
        dateIdx = strcmp(dateList, C{1}{1});
        
        if ~any(dateIdx)
            % if iFile is the first with this date
            numDates = numDates +1;
            dateList{numDates} = C{1}{1};
            
            numFiles_perDate(numDates) = 1;
            sameDateFiles{numDates}{1} = fileList(iFile).name;
        else
            % if iFile is not the first with this date
            numFiles_perDate(numDates) = numFiles_perDate(dateIdx) + 1;
            sameDateFiles{dateIdx}{numFiles_perDate(dateIdx)} = fileList(iFile).name;
        end
        
    end
    
end