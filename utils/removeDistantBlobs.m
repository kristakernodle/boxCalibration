function newMask = removeDistantBlobs(refBlob, oldMask, maxSeparation)

% removeDistantBlobs
%
% boxCalibration package for MatLab

% By Daniel K Leventhal, 2019
% dleventh@med.umich.edu
% https://github.com/orgs/LeventhalLab/boxCalibration

otherBlobs = oldMask & ~refBlob;

L = bwlabel(otherBlobs);

newMask = oldMask;
for ii = 1 : max(L(:))
    
    d = distBetweenBlobs(refBlob, L==ii);
    
    if d > maxSeparation
        newMask = newMask & ~(L==ii);
    end
end

