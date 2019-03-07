function rowIdx = findMatchingRows(testRow, testMatrix)

% findMatchingRows
%
% boxCalibration package for MatLab

% By Daniel K Leventhal, 2019
% dleventh@med.umich.edu
% https://github.com/orgs/LeventhalLab/boxCalibration

numRows = size(testMatrix,1);
rowIdx = false(numRows,1);
for ii = 1 : size(testMatrix,1)
    
    if norm(testRow - testMatrix(ii,:)) == 0
        rowIdx(ii) = true;
    end
    
end