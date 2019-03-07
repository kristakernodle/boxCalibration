function [normalized_points] = normalize_points(points2d, K)
% INPUTS
%   points2d - m x 2 array containing (x,y) pairs in each row
%   K - intrinsic matrix (lower triangular format)
%
% boxCalibration package for MatLab

% By Daniel K Leventhal, 2019
% dleventh@med.umich.edu
% https://github.com/orgs/LeventhalLab/boxCalibration

homogeneous_points = [points2d,ones(size(points2d,1),1)];
normalized_points  = (K' \ homogeneous_points')';
normalized_points = bsxfun(@rdivide,normalized_points(:,1:2),normalized_points(:,3));

end