function [direct_points,mirror_points] = findBoardPoints(imNum,iBoard,img,allPoints,mirrors,cameraParams)
%findBoardPoints 
%   Detailed explanation goes here
    
disp(['image ' imNum ': Outline ' mirrors{iBoard} ' mirror checkerboard'])
warning('off','all');
mirror=roipoly(img);
close all;

disp(['image ' imNum ': Outline direct view ' mirrors{iBoard} ' checkerboard'])
direct=roipoly(img);
warning('on','all');
close all;

mirror=undistortImage(mirror,cameraParams);
direct=undistortImage(direct,cameraParams);

[cM,rM]=find(mirror==1);
[cD,rD]=find(direct==1);

cur_mirror_points=NaN((length(allPoints)/(length(mirrors)*2)),2);
cur_direct_points=NaN((length(allPoints)/(length(mirrors)*2)),2);

indM=1;
indD=1;
for point=1:length(allPoints(:,1))

    if min(cM) <= allPoints(point,2) && allPoints(point,2) <= max(cM)
        if min(rM) <= allPoints(point,1) && allPoints(point,1) <= max(rM)
            cur_mirror_points(indM,:)=allPoints(point,:);
            indM=indM+1;
        end
    end
    if min(cD) <= allPoints(point,2) && allPoints(point,2) <= max(cD)
        if min(rD) <= allPoints(point,1) && allPoints(point,1) <= max(rD)
            cur_direct_points(indD,:)=allPoints(point,:);
            indD=indD+1;
        end
    end

end

mirror_points=cur_mirror_points;
direct_points=cur_direct_points;
        
end