function allParams = setParams
%setParams Used to set parameters for project.
%
% boxCalibration package for MatLab

% By Daniel K Leventhal, 2019
% dleventh@med.umich.edu
% https://github.com/orgs/LeventhalLab/boxCalibration
    
    % Calibration images directory (images should be .png): 
    allParams.calImageDir = '/home/kkrista/Documents/SkilledReaching/CalCube_imgs/';
    % Camera parameters file directory (should be .mat file):
    allParams.camParamFile = '/home/kkrista/Documents/SkilledReaching/cameraParameters_box1.mat';

    % Plotting Parameters:
    allParams.saveMarkedImages = true;
    allParams.markRadius = 5;
    allParams.colorList = {'green','blue'};
    allParams.markOpacity = 1;

    % Plot Creation:
    allParams.makeWorldPts_fig = true;
    
    % Parameters for detecting borders around checkerboards:
    allParams.threshStepSize = 0.01;
    allParams.diffThresh = 0.1;
    allParams.maxThresh = 0.2;

    allParams.minDirectCheckerboardArea = 5000;
    allParams.maxDirectCheckerboardArea = 25000;

    allParams.minMirrorCheckerboardArea = 5000;
    allParams.maxMirrorCheckerboardArea = 20000;

    allParams.maxDistFromMainBlob = 200;  
    allParams.minSolidity = 0.8;
    allParams.SEsize = 2;

    % Size of the checkerboard
    allParams.boardSize = [4 5];
    allParams.cb_spacing = 4; % Real world grid spacing, in mm

    % Regions of interest containing the checkerboards
    allParams.ROIs = [800, 200, 530, 790;
            310, 200, 457, 739;
            1319, 200, 393, 740];

    % Orientation of mirrors
    allParams.mirrorOrientation = {'left','right'};
    
    % Color thresholds for checkerboards (HSV)
    allParams.direct_hsvThresh = [0.33,0.1,0.9,1,0.9,1; 0.518,0.240,0.425,1,1,0.99]; % green; blue

    allParams.mirror_hsvThresh = [0.3,0.05,0.79,1,0.85,1; 0.62,0.218,0.296,1,1,0.99]; % green; blue

    % List of images and csvs in directory; this should not need to be changed
    allParams.imgList = dir([allParams.calImageDir 'GridCalibration_*.png']);
    allParams.csvList = dir([allParams.calImageDir 'GridCalibration_*.csv']);
    
end
