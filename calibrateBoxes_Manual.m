%% Extract and define necessary variables from setParams function
allParams=setParams;
load(allParams.camParamFile);
cameraParams=cameraParams_box1;
K = cameraParams_box1.IntrinsicMatrix;

points_per_board = prod(allParams.boardSize-1);

numBoards = size(allParams.ROIs,1) - 1;

P = eye(4,3);

% Create output directories
markedDir = [allParams.calImageDir 'markedImages/'];
boxCalDir = [allParams.calImageDir 'boxCalibration/'];

if ~exist(markedDir, 'dir')
    mkdir(markedDir);
else
    fprintf('Marked image directory already exists!\nLocation: %s\n', markedDir);
end

if ~exist(boxCalDir, 'dir')
    mkdir(boxCalDir);
else
    fprintf('Box calibration directory already exists!\nLocation: %s\n', boxCalDir);
end

% Get a list of all calibration images and all .csv files (saved from
% FIJI, containing all marked checkerboard points)
[imFiles_from_same_date, img_dateList] = groupByDate(allParams.imgList);
[csvFiles_from_same_date, csv_dateList] = groupByDate(allParams.csvList);

% Prompts to determine which videos to analyze
validResponse = 0;
while ~validResponse
    allDates = input('Do you want to analyze all dates? Y/N [Y]: ', 's');
    if strcmp(allDates,'Y') || isempty(allDates)
        validResponse = 1;
        numDates = length(csv_dateList);
    elseif strcmp(allDates,'N')
        validResponse = 1;
        wantDates = input('Enter the dates you want to analyze: ','s');
        if contains(wantDates,', ')
            splitDates = split(wantDates, ', ');
        else
            splitDates = split(wantDates, ',');
        end
        numDates=length(splitDates);
    else
        fprintf('\nPlease enter a valid response: Y for yes or N for no. Default is Yes.\n\n');    
    end
end

%% Begin processing for selected dates
for iDate = 1 : numDates

    % Adjust variables for selected dates
    if strcmp(allDates,'Y') || isempty(allDates)
        curDate = csv_dateList{iDate};
    else
        curDate = splitDates{iDate};
    end

    fprintf('working on %s\n',curDate);
    
    for csvFiles_all=1:length(csvFiles_from_same_date)
        logical=contains(csvFiles_from_same_date{csvFiles_all},curDate);
        if logical(1)==1
            csv_date_idx=csvFiles_all;
            num_csvPerDate = length(csvFiles_from_same_date{csvFiles_all});
        end
    end

    % Find this date in the img_dateList
    img_date_idx = find(strcmp(img_dateList, curDate));

    numImgPerDate = length(imFiles_from_same_date{img_date_idx});
    img = cell(1, numImgPerDate);

    csvData = cell(1,num_csvPerDate);
    csvNumList = zeros(1,num_csvPerDate);

    %% Read in csv data and undistort the points
    for i_csv = 1 : num_csvPerDate
        cur_csvName = csvFiles_from_same_date{csv_date_idx}{i_csv};
        C = textscan(cur_csvName,['GridCalibration_' curDate '_%d.csv']);
        csvNumList(i_csv) = C{1};
        csvData{i_csv} = readFIJI_csv([allParams.calImageDir cur_csvName]);
        
        % Undistort points in csv file
        csvData{i_csv}=undistortPoints(csvData{i_csv},cameraParams); 
    end

    %% Load marked images (i.e., has .csv file)
    imgNumList = zeros(1,numImgPerDate);
    numImgLoaded = 0;
    if exist('img','var')
        clear img
    end
    
    for iImg = 1 : numImgPerDate
        curImgName = imFiles_from_same_date{img_date_idx}{iImg};
        C = textscan(curImgName,['GridCalibration_' curDate '_%d.png']);
        imageNumber = C{1};
        if any(csvNumList == imageNumber)
            % load this image
            numImgLoaded = numImgLoaded + 1;
            img{numImgLoaded} = imread([allParams.calImageDir curImgName]);
            imgNumList(numImgLoaded) = imageNumber;
        end
    end
    
    %% Identify boards and associated points
    
    % Create arrays to hold the marked checkerboard points
    directChecks = NaN(prod(allParams.boardSize-1),2,numBoards,numImgPerDate);
    mirrorChecks = NaN(prod(allParams.boardSize-1),2,numBoards,numImgPerDate);
    
    allMatchedPoints = NaN(points_per_board * numImgPerDate, 2, 2, numBoards);
    
    for imNum=1:length(img)
        for iBoard=1:numBoards
        
            [direct_points,mirror_points]=findBoardPoints(imNum,iBoard,...
                                                            img{imNum},...
                                                            csvData{imNum},...
                                                            allParams.mirrorOrientation,...
                                                            cameraParams);
                                                        
            matchIdx=matchCheckerboardPoints(direct_points,mirror_points);
            
            matchStartIdx = (iImg-1) * points_per_board + 1;
            matchEndIdx = (iImg) * points_per_board;

            allMatchedPoints(matchStartIdx:matchEndIdx,:,1,iBoard) = direct_points(matchIdx(:,1),:);
            allMatchedPoints(matchStartIdx:matchEndIdx,:,2,iBoard) = mirror_points(matchIdx(:,2),:);

            directChecks(:,:,iBoard,iImg) = direct_points(matchIdx(:,1),:);
            mirrorChecks(:,:,iBoard,iImg) = mirror_points(matchIdx(:,2),:);
            directChecks(:,:,iBoard,imNum)=direct_points(matchIdx(:,1),:);
            mirrorChecks(:,:,iBoard,imNum)=mirror_points(matchIdx(:,2),:);
                                                        
        end
    end
    
    imFileList = imFiles_from_same_date{img_date_idx};
    
    % Save marked images
    if allParams.saveMarkedImages
        for iImg = 1 : numImgPerDate

            % was there a previously marked image?
            curImgName = imFiles_from_same_date{img_date_idx}{iImg};
            oldImg = imread([allParams.calImageDir curImgName],'png');
            newImg = undistortImage(oldImg,cameraParams);

            for iBoard = 1 : numBoards

                curChecks = squeeze(directChecks(:,:,iBoard,iImg));
                for i_pt = 1 : size(curChecks,1)
                    if isnan(curChecks(i_pt,1)); continue; end
                    newImg = insertShape(newImg,'FilledCircle',...
                        [curChecks(i_pt,1),curChecks(i_pt,2),allParams.markRadius],...
                        'color',allParams.colorList{iBoard},'opacity',allParams.markOpacity);
                end

                curChecks = squeeze(mirrorChecks(:,:,iBoard,iImg));
                for i_pt = 1 : size(curChecks,1)
                    if isnan(curChecks(i_pt,1)); continue; end
                    newImg = insertShape(newImg,'FilledCircle',...
                        [curChecks(i_pt,1),curChecks(i_pt,2),allParams.markRadius],...
                        'color',allParams.colorList{iBoard},'opacity',allParams.markOpacity);
                end

            end

            newImgName = strrep(curImgName,'.png','_marked.png');
            imwrite(newImg,[markedDir newImgName],'png');

        end       
    end
    
    num_img = size(directChecks, 4);
    F = NaN(3,3,numBoards);
    E = NaN(3,3,numBoards);
    Pn = NaN(4,3,numBoards);
    scaleFactor = NaN(numBoards, num_img);

    % Create reconstruction variables for date
    for iBoard = 1 : size(allMatchedPoints, 4)
        mp_direct = squeeze(allMatchedPoints(:,:,1,iBoard));
        mp_mirror = squeeze(allMatchedPoints(:,:,2,iBoard));
        valid_mp_direct = mp_direct(~isnan(mp_direct));
        valid_mp_direct = reshape(valid_mp_direct,size(valid_mp_direct,1)/2,2);
        valid_mp_mirror = mp_mirror(~isnan(mp_mirror));
        valid_mp_mirror = reshape(valid_mp_mirror,size(valid_mp_mirror,1)/2,2);
        if isempty(valid_mp_direct) || isempty(valid_mp_mirror)
            % either didn't have marks for these images or the marks
            % weren't assigned to the correct boards/images
            fprintf('no matched points on board %d\n',iBoard);
            continue;
        end
        if size(valid_mp_direct,1) ~= size(valid_mp_mirror,1)
            fprintf('direct and mirror point arrays do not match for board %d\n',iBoard);
        end
        F(:,:,iBoard) = fundMatrix_mirror(valid_mp_direct, valid_mp_mirror);

        E(:,:,iBoard) = K * squeeze(F(:,:,iBoard)) * K';

        cur_E = squeeze(E(:,:,iBoard));
        [rot,t] = EssentialMatrixToCameraMatrix(cur_E);
        [cRot,cT,~] = SelectCorrectEssentialCameraMatrix_mirror(...
            rot,t,valid_mp_mirror',valid_mp_direct',K');
        Ptemp = [cRot,cT];
        Pn(:,:,iBoard) = Ptemp';

        % normalize matched points by K in preparation for calculating
        % world points
        for iImg = 1 : num_img
            mp_direct = squeeze(directChecks(:,:,iBoard,iImg));
            mp_mirror = squeeze(mirrorChecks(:,:,iBoard,iImg));

            if all(isnan(mp_direct(:))) || all(isnan(mp_mirror(:)))
                % either didn't have marks for these images or the marks
                % weren't assigned to the correct boards/images
                try
                fprintf('no matched points on board %d, image %s\n',iBoard,imFileList{iImg});
                catch
                    keyboard
                end
                continue;
            end

            direct_hom = [mp_direct, ones(size(mp_direct,1),1)];
            direct_norm = (K' \ direct_hom')';
            direct_norm = bsxfun(@rdivide,direct_norm(:,1:2),direct_norm(:,3));

            mirror_hom = [mp_mirror, ones(size(mp_mirror,1),1)];
            mirror_norm = (K' \ mirror_hom')';
            mirror_norm = bsxfun(@rdivide,mirror_norm(:,1:2),mirror_norm(:,3));

            cur_P = squeeze(Pn(:,:,iBoard));
            [wpts, ~]  = triangulate_DL(direct_norm, mirror_norm, P, cur_P);
            gs = calcGridSpacing(wpts,allParams.boardSize-1);
            scaleFactor(iBoard,iImg) = allParams.cb_spacing / mean(gs);

            all_wpts{iImg,iBoard}=wpts;
        end

    end
    
    % Plot world points figures (scatter plots)
    if allParams.makeWorldPts_fig

        plotDir = [allParams.calImageDir 'plots/'];
        if ~exist(plotDir, 'dir')
            mkdir(plotDir);
        end

        plotDateDir = [allParams.calImageDir 'plots/' curDate '/'];
        if ~exist(plotDateDir, 'dir')
            mkdir(plotDateDir);
        end

        for iImg=1:numImgPerDate
            if iImg ~= 1
                close(f);
            end
            figNum=num2str(iImg);
            f = figure('visible','off');
            hold on
            scatter3(all_wpts{iImg,1}(:,1),all_wpts{iImg,1}(:,2),all_wpts{iImg,1}(:,3));
            scatter3(all_wpts{iImg,2}(:,1),all_wpts{iImg,2}(:,2),all_wpts{iImg,2}(:,3));
            saveas(f,[plotDateDir 'WorldPts_' curDate '_' figNum],'fig');
            saveas(f,[plotDateDir 'WorldPts_' curDate '_' figNum],'png');
        end
    end
    
    % write box calibration information to disk
    calibrationFileName = [boxCalDir 'boxCalibration_box1_' curDate '.mat'];
    save(calibrationFileName,'P','Pn','F','E','scaleFactor','directChecks','mirrorChecks','allMatchedPoints','cameraParams','curDate','imFileList');
end