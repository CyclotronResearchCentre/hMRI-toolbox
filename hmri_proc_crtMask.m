function [fn_maskTC,fn_meanTC] = hmri_proc_crtMask(fn_smwTC, opts)
% Generating tissue specific mask for the SPM analysis.
% The aim is to preselect, based on smoothed modulated posterior tissue 
% probability maps, which voxels should be considered for further 
% statistical analysis.
% 
% FORMAT
%   [fn_maskTC,fn_meanTC] = hmri_proc_crtMask(fn_smwTC, opts)
% 
% INPUT
% - fn_smwTC : filenames (cell array, 1 cell per TC, containing a char or 
%             cell array) of the modulated warped tissue classes, 
%             ex. the mwc1/2*.nii filenames in the 1st and 2nd cell.
% - opts    : option structure
%   .minTCp : minimal posterior probability value to be considered [.2, def]
%   .noOvl  : avoid overlap by assigning to tissue class with maximum
%             posterior probability [1, def]
%   .outPth : path to output folder, use that of the 1st image if it is 
%             left empty ['', def]
% 
% OUTPUT
% - fn_maskTC : filenames (char array) of the tissue specific masks
% - fn_meanTC : filenames (char array) of the mean tissue class images
% 
% The core idea comes from Callaghan et al. 2014
% https://doi.org/10.1016/j.neurobiolaging.2014.02.008
% > smoothed Jacobian-modulated tissue probability maps in MNI space were  
% > averaged across all subjects for each tissue class (GM, WM, and 
% > cerebrospinal fluid). Masks were generated by assigning voxels to the 
% > tissue class for which the probability was maximal. Voxels for which 
% > neither the GM nor the WM probability exceeded 20% were excluded from 
% > the analysis. This approach was used to ensure that each voxel was 
% > analyzed in only one subspace and that non-brain tissue was excluded.
% 
% The function is relatively flexible as
% - nTC different tissue class images can be introduced. If only one is
%   provided, then only the minimal probability thresholding can be
%   applied.
% - this minimal probability threshold, by default 20%, can be changed;
% - the "no overlap by assigning the the class with maximum probability" 
%   can be disabled and then only the thresholding is applied.
% - the mean tissue class images could still come in handy for quality &
%   sanity checks so they're not deleted and there filenames passed out.
% 
% REFERENCE
% Callaghan et al., https://doi.org/10.1016/j.neurobiolaging.2014.02.008
%_______________________________________________________________________
% Copyright (C) 2019 Cyclotron Research Centre

% Written by C. Phillips.
% Cyclotron Research Centre, University of Liege, Belgium


%% Deal with input:
% 1/ in case nothing is passed
if nargin<1
    help(mfilename)
    return
end

% 2/ set up default options & update passed options
if nargin<2, opts = struct; end
opts_def = struct(...
    'minTCp', .2, ... % default 20%
    'noOvl', true, ... 
    'outPth', '');
opts = hmri_check_opt(opts_def,opts);

% 3/ get nr of tissue classes (nTC) & nr of images (nImg), then check
nTC = numel(fn_smwTC);
nImg = zeros(1,nTC);
for ii=1:nTC
    tmp = fn_smwTC{ii};
    if iscell(tmp)
        fn_smwTC{ii} = char( tmp ); % turn into cell array
    end
    nImg(ii) = size(fn_smwTC{ii},1);
end
if length(unique(nImg))>1
    error('hmri:crtMsk','Provide same number of images per tissue class');
end
if nTC==1, 
    % No no-overlap possible if only relying on a single TC!
    opts.noOvl = false; 
end

% 4/ sort out output path
if isempty(opts.outPth)
    % set it to that of the 1st image...
    opts.outPth = spm_file(fn_smwTC{ii}(1,:),'path');
end

% 5/ chek & extract TC threshold
thrTC = opts.minTCp;
if thrTC>=1 
    % assume that thresholded is expressed explicitly in %, 
    % e.g. 20 instead of .2
    fprintf('\nWARNING: threshold value passed >1!\n');
    fprintf('\tAssuming you used percent value, need to convert it.\n');
    fprintf('\tE.g. 20%% -> .2\n' );
    thrTC = thrTC/100;
end

%% Deal with mask creation

% 1/ create the mean across subject of each the tissue map
% NOTE:
% it would look better to generate de mean image names in a more generic
% way, say with the just the tissue class index but no reference to any
% specific subject's Id.
fn_meanTC = cell(nTC,1);
imcalc_flags = struct(...
    'dmtx', 1, ... % load into matrix X -> mean(X)
    'mask', 1, ... % mask out 'bad' voxels across subjects
    'descrip', 'mean tissue class image');
for ii=1:nTC
    fn_meanTC{ii} = fullfile(opts.outPth, ...
        ['mean_',spm_file(fn_smwTC{ii}(1,:),'basename'),'.nii']);
    spm_imcalc(fn_smwTC{ii}, fn_meanTC{ii}, 'mean(X)' ,imcalc_flags);
end

% 2/ binarize using 1 or 2 criteria:
% - always, some thresholding
% - possibly, some max-ing
fn_maskTC = cell(nTC,1);
imcalc_flags = struct(...
    'dmtx', 0, ... % load into matrix X -> mean(X)
    'mask', -1, ... % mask out 'bad' voxels 
    'dtype', 2, ... % save in int8 format
    'descrip', 'tissue specific mask');
for ii=1:nTC
    fn_maskTC{ii} = fullfile(opts.outPth, ...
        ['mask_',spm_file(fn_smwTC{ii}(1,:),'basename'),'.nii']);
    % 1st thresholding
    fn_in = fn_meanTC{ii};
    f_oper = 'i1>thrTC';
    % then max-ing, if needed
    if opts.noOvl
        % add images to input + add conditions to operations
        l_ind2add = 1:nTC; l_ind2add(ii) = [];
        for jj = 1:nTC-1
            fn_in = char(fn_in,fn_meanTC{l_ind2add(jj)});
            f_oper = sprintf('%s & i1>i%d', f_oper, jj+1);
        end
    end
    % do it
    spm_imcalc(fn_in, fn_maskTC{ii}, f_oper, imcalc_flags, ...
        struct('name','thrTC','value',thrTC) );
    % pass the extra variable "threTC" via a structure as the function
    % 'inputname' was not working correctly on my Matlab...
end


end
