function calibrateBoxes
%calibrateBoxes Generate parameters for 3D reconstruction. 

    % Extract and define necessary variables from setParams function
    allParams=setParams;
    load(allParams.camParamFile);
    K = cameraParams.IntrinsicMatrix;

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
    numDates = length(csv_dateList);

%
    for iDate = 1 : numDates

        curDate = csv_dateList{iDate};

        fprintf('working on %s\n',curDate);
        
        % Begin processing for curDate
        
        num_csvPerDate = length(csvFiles_from_same_date{iDate});

        % Find this date in the img_dateList
        img_date_idx = find(strcmp(img_dateList, curDate));

        numImgPerDate = length(imFiles_from_same_date{img_date_idx});
        img = cell(1, numImgPerDate);

        csvData = cell(1,num_csvPerDate);
        csvNumList = zeros(1,num_csvPerDate);
        
        % Read in csv data and undistort the points
        for i_csv = 1 : num_csvPerDate
            cur_csvName = csvFiles_from_same_date{iDate}{i_csv};
            C = textscan(cur_csvName,['GridCalibration_' curDate '_%d.csv']);
            csvNumList(i_csv) = C{1};
            csvData{i_csv} = readFIJI_csv([allParams.calImageDir cur_csvName]);
            % Undistort points in csv file
            csvData{i_csv}=undistortPoints(csvData{i_csv},cameraParams); 
        end

        % Load marked images (i.e., has .csv file)
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

%
        [directBorderMask, ~] = findDirectBorders(img, allParams.direct_hsvThresh, allParams.ROIs, ...
                'diffthresh', allParams.diffThresh, 'threshstepsize', allParams.threshStepSize, 'maxthresh', allParams.maxThresh, ...
                'maxdistfrommainblob', allParams.maxDistFromMainBlob, 'mincheckerboardarea', allParams.minDirectCheckerboardArea, ...
                'maxcheckerboardarea', allParams.maxDirectCheckerboardArea, 'sesize', allParams.SEsize, 'minsolidity', allParams.minSolidity);
        [mirrorBorderMask, ~] = findMirrorBorders(img, allParams.mirror_hsvThresh, allParams.ROIs, ...
                'diffthresh', allParams.diffThresh, 'threshstepsize', allParams.threshStepSize, 'maxthresh', allParams.maxThresh, ...
                'maxdistfrommainblob', allParams.maxDistFromMainBlob, 'mincheckerboardarea', allParams.minMirrorCheckerboardArea, ...
                'maxcheckerboardarea', allParams.maxMirrorCheckerboardArea, 'sesize', allParams.SEsize, 'minsolidity', allParams.minSolidity);

        % Undistort masks
        for ii = 1 : length(directBorderMask)
            for jj = 1 : size(directBorderMask{ii},3)
                directBorderMask{ii}(:,:,jj) = undistortImage(squeeze(directBorderMask{ii}(:,:,jj)), cameraParams);
            end
        end
        for ii = 1 : length(mirrorBorderMask)
            for jj = 1 : size(mirrorBorderMask{ii},3)
                mirrorBorderMask{ii}(:,:,jj) = undistortImage(squeeze(mirrorBorderMask{ii}(:,:,jj)), cameraParams);
            end
        end

        % Create arrays to hold the marked checkerboard points
        directChecks = NaN(prod(allParams.boardSize-1),2,size(directBorderMask{1},3),numImgPerDate);
        mirrorChecks = NaN(prod(allParams.boardSize-1),2,size(mirrorBorderMask{1},3),numImgPerDate);

        % now loop through .csv files
        for i_csv = 1 : num_csvPerDate

            % figure out what image index to use
            img_idx = find(imgNumList == csvNumList(i_csv));

            % fill out the directChecks and mirrorChecks arrays. Assume that
            % the image number is the correct index to use.

            [new_directChecks, new_mirrorChecks] = assign_csv_points_to_checkerboards(directBorderMask{img_idx}, ...
                                                    mirrorBorderMask{img_idx}, ...
                                                    allParams.ROIs, csvData{i_csv}, ...
                                                    allParams.boardSize, ...
                                                    allParams.mirrorOrientation);

            % update directChecks and mirrorChecks arrays
            for iBoard = 1 : size(new_directChecks,3)
                testPoints = squeeze(new_directChecks(:,:,iBoard));
                if ~all(isnan(testPoints(:)))
                    % marked points were found for this board
                    directChecks(:,:,iBoard,imgNumList(img_idx)) = testPoints;
                end

                testPoints = squeeze(new_mirrorChecks(:,:,iBoard));
                if ~all(isnan(testPoints(:)))
                    % marked points were found for this board
                    mirrorChecks(:,:,iBoard,imgNumList(img_idx)) = testPoints;
                end

            end

        end

        allMatchedPoints = NaN(points_per_board * numImgPerDate, 2, 2, numBoards);
        for iImg = 1 : numImgPerDate
            for iBoard = 1 : numBoards
                curDirectChecks = squeeze(directChecks(:,:,iBoard,iImg));
                curMirrorChecks = squeeze(mirrorChecks(:,:,iBoard,iImg));

                if all(isnan(curDirectChecks(:))) || all(isnan(curMirrorChecks(:)))
                    % don't have matching points for the direct and mirror view
                    continue;
                end 
                matchIdx = matchCheckerboardPoints(curDirectChecks, curMirrorChecks);

                matchStartIdx = (iImg-1) * points_per_board + 1;
                matchEndIdx = (iImg) * points_per_board;

                allMatchedPoints(matchStartIdx:matchEndIdx,:,1,iBoard) = curDirectChecks(matchIdx(:,1),:);
                allMatchedPoints(matchStartIdx:matchEndIdx,:,2,iBoard) = curMirrorChecks(matchIdx(:,2),:);

                directChecks(:,:,iBoard,iImg) = curDirectChecks(matchIdx(:,1),:);
                mirrorChecks(:,:,iBoard,iImg) = curMirrorChecks(matchIdx(:,2),:);
            end
        end

%         matSaveFileName = [allParams.calImageDir 'GridCalibration_' csv_dateList{iDate} '_all.mat'];
        imFileList = imFiles_from_same_date{img_date_idx};
%         save(matSaveFileName, 'directChecks','mirrorChecks','allMatchedPoints','cameraParams','imFileList','curDate');

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
                        newImg = insertShape(newImg,'circle',...
                            [curChecks(i_pt,1),curChecks(i_pt,2),allParams.markRadius],...
                            'color',allParams.colorList{iBoard},'opacity',allParams.markOpacity);
                    end

                    curChecks = squeeze(mirrorChecks(:,:,iBoard,iImg));
                    for i_pt = 1 : size(curChecks,1)
                        if isnan(curChecks(i_pt,1)); continue; end
                        newImg = insertShape(newImg,'circle',...
                            [curChecks(i_pt,1),curChecks(i_pt,2),allParams.markRadius],...
                            'color',allParams.colorList{iBoard},'opacity',allParams.markOpacity);
                    end

                end
                
                newImgName = strrep(curImgName,'.png','_all_marked.png');
                imwrite(newImg,[markedDir newImgName],'png');
                
            end       
        end
%     end
%     
%     all_pt_matList = dir([allParams.calImageDir 'Grid*_all.mat']);
%     
%     for iMat = 1 : length(all_pt_matList)
    
%         load([allParams.calImageDir all_pt_matList(iMat).name]);
        fprintf('working on %s\n',curDate);
       
        num_img = size(directChecks, 4);
        F = NaN(3,3,numBoards);
        E = NaN(3,3,numBoards);
        Pn = NaN(4,3,numBoards);
        scaleFactor = NaN(numBoards, num_img);
        
        for iBoard = 1 : size(allMatchedPoints, 4)
            mp_direct = squeeze(allMatchedPoints(:,:,1,iBoard));
            mp_mirror = squeeze(allMatchedPoints(:,:,2,iBoard));
            valid_mp_direct = mp_direct(~isnan(mp_direct));
            valid_mp_direct = reshape(valid_mp_direct,size(valid_mp_direct,1)/2,2);
            valid_mp_mirror = mp_mirror(~isnan(mp_mirror));
            valid_mp_mirror = reshape(valid_mp_mirror,size(valid_mp_mirror,1)/2,2);
    %         if any(isnan(mp_direct(:))) || any(isnan(mp_mirror(:)))
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

                % comment in below to make scatter plots of world points
    %             figure(iImg + 3)
    %             if iBoard == 1
    %                 hold off
    %             else
    %                 hold on
    %             end
    %             scatter3(wpts(:,1),wpts(:,2),wpts(:,3))
            end

        end

        % write box calibration information to disk
        calibrationFileName = [boxCalDir 'boxCalibration_' curDate '.mat'];
        save(calibrationFileName,'P','Pn','F','E','scaleFactor','directChecks','mirrorChecks','allMatchedPoints','cameraParams','curDate','imFileList');

        % comment in below to draw lines between matching points

    %     img = cell(1, length(imFileList));
    %     for ii = 1 : length(imFileList)
    %         img{ii} = imread(imFileList{ii},'png');
    %         img{ii} = undistortImage(img{ii},cameraParams);
    %         
    %         figure(ii)
    %         imshow(img{ii})
    %         h = size(img{ii},1);
    %         w = size(img{ii},2);
    %         hold on
    %         num_pts = size(directChecks,1);
    %         for jj = 1 : size(directChecks,3)   % view index
    %             cur_F = squeeze(F(:,:,jj));
    %             if ~any(isnan(cur_F(:)))
    %                 [isIn,epipole] = isEpipoleInImage(cur_F, [h,w]);
    %             else
    %                 epipole = NaN(1,2);
    %             end
    %             for kk = 1 : num_pts
    %                 line([epipole(1),directChecks(kk,1,jj,ii)],...
    %                     [epipole(2),directChecks(kk,2,jj,ii)],'color','r');
    %                 line([directChecks(kk,1,jj,ii),mirrorChecks(kk,1,jj,ii)],...
    %                     [directChecks(kk,2,jj,ii),mirrorChecks(kk,2,jj,ii)],'color','b')
    %             end
    %         end
    %     end

    end
    
end