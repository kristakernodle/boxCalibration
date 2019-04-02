function [ imgMask, denoisedMasks ] = findMirrorBorders(img, HSVlimits, ROIs, varargin)

% findMirrorBorders
%
% boxCalibration package for MatLab

% By Daniel K Leventhal, 2019
% dleventh@med.umich.edu
% https://github.com/orgs/LeventhalLab/boxCalibration

for iarg = 1 : 2 : nargin - 3
    switch lower(varargin{iarg})
        case 'diffthresh'
            diffThresh = varargin{iarg + 1};
        case 'threshstepsize'
            threshStepSize = varargin{iarg + 1};
        case 'maxthresh'
            maxThresh = varargin{iarg + 1};
        case 'maxdistfrommainblob'
            maxDistFromMainBlob = varargin{iarg + 1};
        case 'mincheckerboardarea'
            minCheckerboardArea = varargin{iarg + 1};
        case 'maxcheckerboardarea'
            maxCheckerboardArea = varargin{iarg + 1};
        case 'sesize'
            SEsize = varargin{iarg + 1};
        case 'minsolidity'
            minSolidity = varargin{iarg + 1};
    end
end

if iscell(img)
    num_img = length(img);
else
    num_img = 1;
    img = {img};
end

imgMask = cell(1, num_img);
numColors = size(ROIs,1) - 1;

h = size(img{1},1);
w = size(img{1},2);
    
denoisedMasks = false(h,w,numColors,num_img);
    
for iImg = 1 : num_img
    
    if isa(img{iImg},'uint8')
        img{iImg} = double(img{iImg}) / 255;
    end
    im_eq = adapthisteq(rgb2gray(img{iImg}));
    im_hsv = rgb2hsv(img{iImg});
    hsv_eq = im_hsv;
    hsv_eq(:,:,3) = im_eq;
    rgb_eq = hsv2rgb(hsv_eq);

    img_stretch = decorrstretch(rgb_eq);

    img_hsv = rgb2hsv(img_stretch);
    imgMask{iImg} = false(h,w,3);
    foundValidBorder = false(1,numColors);
    for iMirror = 1 : numColors
        
        mirrorMask = false(h,w);
        mirrorMask(ROIs(iMirror+1,2):ROIs(iMirror+1,2)+ROIs(iMirror+1,4)-1, ROIs(iMirror+1,1):ROIs(iMirror+1,1)+ROIs(iMirror+1,3)-1) = true;

        [mirrorBorder,denoisedMask,indValidBorder] = findValidBorders(img_hsv, HSVlimits(iMirror,:), mirrorMask, ...
            'diffthresh', diffThresh, 'threshstepsize', threshStepSize, 'maxthresh', maxThresh, ...
            'maxdistfrommainblob', maxDistFromMainBlob, 'mincheckerboardarea', minCheckerboardArea, ...
            'maxcheckerboardarea', maxCheckerboardArea, 'sesize', SEsize, 'minsolidity', minSolidity);
            
        denoisedMasks(:,:,iMirror,iImg) = denoisedMask;
        foundValidBorder(iMirror) = indValidBorder;

        if foundValidBorder(iMirror)
            imgMask{iImg}(:,:,iMirror) = mirrorBorder;
        end

    end

end

end