function calibrateBoxes
%calibrateBoxes Generate parameters for 3D reconstruction. 

    allParams=setParams;
    load(allParams.camParamFile);
    K = cameraParams.IntrinsicMatrix;

    points_per_board = prod(allParams.boardSize-1);

    numBoards = size(allParams.ROIs,1) - 1;

    [imFiles_from_same_date, img_dateList] = groupCalibrationImagesbyDate(allParams.imgList);
    [csvFiles_from_same_date, csv_dateList] = group_csv_files_by_date(allParams.csvList);
    numDates = length(csv_dateList);

    for iDate = 1 : numDates

        curDate = csv_dateList{iDate};

        fprintf('working on %s\n',curDate);
        num_csvPerDate = length(csvFiles_from_same_date{iDate});

        % find this date in the img_dateList
        img_date_idx = find(strcmp(img_dateList, curDate));

        numImgPerDate = length(imFiles_from_same_date{img_date_idx});
        img = cell(1, numImgPerDate);

        csvData = cell(1,num_csvPerDate);
        csvNumList = zeros(1,num_csvPerDate);
        for i_csv = 1 : num_csvPerDate
            cur_csvName = csvFiles_from_same_date{iDate}{i_csv};
            C = textscan(cur_csvName,['GridCalibration_' curDate '_%d.csv']);
            csvNumList(i_csv) = C{1};
            csvData{i_csv} = readFIJI_csv([allParams.calImageDir cur_csvName]);
            % Undistort points in csv file
            csvData{i_csv}=undistortPoints(csvData{i_csv},cameraParams); %#ok<USENS>
        end

        % load images, but only ones for which there is a .csv file
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

        [directBorderMask, ~] = findDirectBorders(img, allParams.direct_hsvThresh, allParams.ROIs, ...
                'diffthresh', allParams.diffThresh, 'threshstepsize', allParams.threshStepSize, 'maxthresh', allParams.maxThresh, ...
                'maxdistfrommainblob', allParams.maxDistFromMainBlob, 'mincheckerboardarea', allParams.minDirectCheckerboardArea, ...
                'maxcheckerboardarea', allParams.maxDirectCheckerboardArea, 'sesize', allParams.SEsize, 'minsolidity', allParams.minSolidity);
        [mirrorBorderMask, ~] = findMirrorBorders(img, allParams.mirror_hsvThresh, allParams.ROIs, ...
                'diffthresh', allParams.diffThresh, 'threshstepsize', allParams.threshStepSize, 'maxthresh', allParams.maxThresh, ...
                'maxdistfrommainblob', allParams.maxDistFromMainBlob, 'mincheckerboardarea', allParams.minMirrorCheckerboardArea, ...
                'maxcheckerboardarea', allParams.maxMirrorCheckerboardArea, 'sesize', allParams.SEsize, 'minsolidity', allParams.minSolidity);

        % undistort masks
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

        % create arrays to hold the marked checkerboard points
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

        matSaveFileName = [allParams.calImageDir 'GridCalibration_' csv_dateList{iDate} '_all.mat'];
        imFileList = imFiles_from_same_date{img_date_idx};
        save(matSaveFileName, 'directChecks','mirrorChecks','allMatchedPoints','cameraParams','imFileList','curDate');

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
                imwrite(newImg,[allParams.calImageDir newImgName],'png');
                
            end       
        end
    end

    
end