function [meanHSV, stdHSV] = calcHSVstats(img_hsv, digitMask)
%
% INPUTS:
%   img_hsv - m x n x 3 array containing an hsv image
%   digitMask - binary mask of the digit (or other object)
%
% OUTPUTS:
%   meanHSV - average hsv values for img_hsv
%   stdHSV - standard deviation for hsv values of img_hsv
%
% boxCalibration package for MatLab

% By Daniel K Leventhal, 2019
% dleventh@med.umich.edu
% https://github.com/orgs/LeventhalLab/boxCalibration

    meanHSV = zeros(1,3);
    stdHSV  = zeros(1,3);
    idx = squeeze(digitMask);
    idx = idx(:);
    for jj = 1 : 3
        colPlane = squeeze(img_hsv(:,:,jj));
        colPlane = colPlane(:);
        if jj == 1
            meanAngle = wrapTo2Pi(circ_mean(colPlane(idx)*2*pi));
            stdAngle = wrapTo2Pi(circ_std(colPlane(idx)*2*pi));
            meanHSV(jj) = meanAngle / (2*pi);
            stdHSV(jj) = stdAngle / (2*pi);
        else
            meanHSV(jj) = mean(colPlane(idx));
            stdHSV(jj) = std(colPlane(idx));
        end
    end
    
end