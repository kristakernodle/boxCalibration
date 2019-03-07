function allParams = setParams
%setParams Used to set parameters for project.
%
% boxCalibration package for MatLab

% By Daniel K Leventhal, 2019
% dleventh@med.umich.edu
% https://github.com/orgs/LeventhalLab/boxCalibration
    
    % Calibration images directory (images should be .png): 
    allParams.calImageDir = '/Users/Krista/Desktop/CalCubeImages/';
    % Camera parameters file directory (should be .mat file):
    allParams.camParamFile = '/Users/Krista/Desktop/CalCubeImages/cameraParameters.mat';

    % Plotting Parameters:
    allParams.saveMarkedImages = true;
    allParams.markRadius = 5;
    allParams.colorList = {'red','green','blue'};
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
    allParams.SEsize = 3;

    % Regions of interest containing the checkerboards
    allParams.ROIs = [700,270,650,705;
            750,1,600,325;
            1,400,350,500;
            1700,400,340,500];

    % Orientation of mirrors
    allParams.mirrorOrientation = {'top','left','right'};
    
    % Color thresholds for checkerboards (HSV)
    allParams.direct_hsvThresh = [0,0.1,0.9,1,0.9,1; % red
                        0.33,0.1,0.9,1,0.9,1; % green
                        0.66,0.1,0.9,1,0.9,1]; % blue

    allParams.mirror_hsvThresh = [0,0.1,0.85,1,0.85,1; % red
                        0.30,0.05,0.85,1,0.85,1; % green
                        0.60,0.1,0.85,1,0.85,1]; % blue
    
    % Size of the checkerboard
    allParams.boardSize = [4 5];
    allParams.cb_spacing = 4; % Real world grid spacing, in mm

    % List of images and csvs in directory
    allParams.imgList = dir([allParams.calImageDir 'GridCalibration_*.png']);
    allParams.csvList = dir([allParams.calImageDir 'GridCalibration_*.csv']);
    
end