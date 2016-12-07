function P_trans = hmri_run_b1map(jobsubj)

%% Processing of the B1 maps for B1 bias correction
% FORMAT P_trans = hmri_run_b1map(jobsubj)
%    jobsubj - are parameters for one subject out of the job list. 
%    NB: ONE SINGLE DATA SET FROM ONE SINGLE SUBJECT IS PROCESSED HERE, 
%    LOOP OVER SUBJECTS DONE AT HIGHER LEVEL. 
%    P_trans - a vector of file names with P_trans(1,:) = anatomical volume
%        for coregistration and P_trans(2,:) = B1 map in percent units.
%_______________________________________________________________________
% Written by E. Balteau, 2014.
% Cyclotron Research Centre, University of Liege, Belgium
%_______________________________________________________________________
% Modified by T. Leutritz in 2016 in order to use the SIEMENS product 
% sequences 'rf_map' and 'tfl_b1map'. The latter produces essentially 
% a FLASH like image and a flip angle map (multiplied by 10) based on 
% Chung S. et al.: "Rapid B1+ Mapping Using a Preconditioning RF Pulse with 
% TurboFLASH Readout", MRM 64:439-446 (2010). 
%_______________________________________________________________________

% retrieve b1_type from job and pass it as default value for the current
% processing:
[hdr,IsExtended]=hMRI_get_extended_hdr(jobsubj.raw_fld.b1{1});
b1_prot = jobsubj.b1_type;
hmri_get_defaults('b1_type.val',b1_prot);
if (~IsExtended)
    b1map_defs = hmri_get_defaults('b1map.i3D_EPI');
else
    if ~isempty(strfind(hdr{1}.acqpar.ProtocolName,'al_B1mapping'))
        b1map_defs.data='EPI';b1map_defs.avail=true;b1map_defs.procreq=true;
        b1map_defs.b1acq.beta=hMRI_get_extended_hdr_val(hdr{1},'B1mapNominalFAValues');
        b1map_defs.b1acq.TM=hMRI_get_extended_hdr_val(hdr{1},'B1mapMixingTime');
        b1map_defs.b1acq.nPEacq=hMRI_get_extended_hdr_val(hdr{1},'MeasuredPELines');%hdr{1}.acqpar.Columns/hmri_get_defaults('b1map.i3D_EPI.b1acq.phaseGRAPPA');
        if hdr{1}.acqpar.PixelBandwidth==2300% not ideal...
            b1map_defs.b1acq.EchoSpacing=540e-3;
        elseif hdr{1}.acqpar.PixelBandwidth==3600
            b1map_defs.b1acq.EchoSpacing=330e-3;
        end
        b1map_defs.b1acq.blipDIR=hMRI_get_extended_hdr_val(hdr{1},'PhaseEncodingDirectionSign');        
        b1map_defs.b1proc=hmri_get_defaults('b1map.i3D_EPI.b1proc');
%         b1map_defs.T1=hmri_get_defaults(['b1map.',b1_prot,'.b1proc' '.T1']);
%         b1map_defs.Nonominalvalues=hmri_get_defaults(['b1map.',b1_prot,'.b1proc' '.Nonominalvalues']);
%         b1map_defs.eps=hmri_get_defaults(['b1map.',b1_prot,'.b1proc' '.eps']);
    end
end
P_trans = [];

if ~b1map_defs.avail
    disp('----- No B1 correction performed (semi-quantitative maps only) -----');
    return;
end

% calculate the B1 map if required
if b1map_defs.procreq
    if strcmpi(b1map_defs.data,'AFI')
        % processing B1 map from AFI data
        P_trans  = calc_AFI_b1map(jobsubj, b1map_defs);
        
    elseif strcmpi(b1map_defs.data,'EPI')
        % processing B1 map from SE/STE EPI data
        P_trans  = calc_SESTE_b1map(jobsubj, b1map_defs);
        
    elseif strcmpi(b1map_defs.data,'TFL')
        % processing B1 map from tfl_b1map data
        P_trans  = calc_tfl_b1map(jobsubj);
        
    elseif strcmpi(b1map_defs.data,'RFmap')
        % processing B1 map from rf_map data
        P_trans  = calc_rf_map(jobsubj);
    end
else
    % return pre-processed B1 map
    disp('----- Loading pre-processed B1 map -----');
    P    = char(jobsubj.raw_fld.b1);   % the B1 map
    P_trans  = P(1:2,:);
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function P_trans = calc_AFI_b1map(jobsubj, b1map_defs)

disp('----- Calculation of B1 map (AFI protocol) -----');

% NB: both phase and magnitude images can be provided but only the
% magnitude images (first series) are used. Phase images (second series)
% are not used. In each series, first image = TR2 (long TR) and second
% image = TR1 (short TR).
P = char(jobsubj.raw_fld.b1);   % 2 or 4 images
fileTR1 = P(2,:);
fileTR2 = P(1,:);
V1 = spm_vol(fileTR1);
V2 = spm_vol(fileTR2);
Vol1 = spm_read_vols(V1);
Vol2 = spm_read_vols(V2);

TR1 = 1; % only the ratio [TR2/TR1=n] matters
TR2 = b1map_defs.TR2TR1ratio;
alphanom = b1map_defs.alphanom;

% Mask = squeeze(Vol1);
% threshold = (prctile(Mask(:),98)-prctile(Mask(:),2))*0.1+prctile(Mask(:),2);
% Mask = (Mask>threshold);

B1map = acos((Vol2./Vol1*TR2/TR1-1)./(TR2/TR1*ones(size(Vol1))-Vol2./Vol1))*180/pi;
B1map_norm = abs(B1map)*100/alphanom;

% smoothed map
smB1map_norm = zeros(size(B1map_norm));
pxs = sqrt(sum(V1.mat(1:3,1:3).^2)); % Voxel resolution
smth = 8./pxs;
spm_smooth(B1map_norm,smB1map_norm,smth);

% masking
% B1map = B1map.*Mask;
% B1map_norm = B1map_norm.*Mask;
% smB1map_norm = smB1map_norm.*Mask;

%-Save everything in OUTPUT dir
%-----------------------------------------------------------------------
% determine output directory path
if isfield(jobsubj.output,'indir')
    outpath = fileparts(V1.fname);
else
    outpath = jobsubj.output.outdir{1};
end

[~, sname] = fileparts(V1.fname);

VB1 = V1;
% VB1.pinfo = [max(B1map(:))/16384;0;0];
% VB1.fname = fullfile(outpath, [sname '_B1map.nii']);
% spm_write_vol(VB1,B1map);

% VB1.pinfo = [max(B1map_norm(:))/16384;0;0];
% VB1.fname = fullfile(outpath, [sname '_B1map_norm.nii']);
% spm_write_vol(VB1,B1map_norm);

VB1.pinfo = [max(smB1map_norm(:))/16384;0;0];
VB1.fname = fullfile(outpath, [sname '_smB1map_norm.nii']);
spm_write_vol(VB1,smB1map_norm);

% requires anatomic image + map
P_trans  = char(char(fileTR1),char(VB1.fname));

% VB1.fname = fullfile(outpath, [sname '_B1map_mask.nii']);
% spm_write_vol(VB1,Mask);

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function P_trans = calc_SESTE_b1map(jobsubj, b1map_defs)

disp('----- Calculation of B1 map (SE/STE EPI protocol) -----');

P    = char(jobsubj.raw_fld.b1); % B1 data - 11 pairs
Q    = char(jobsubj.raw_fld.b0); % B0 data - 3 volumes

V = spm_vol(P);
n = numel(V);
Y_tmptmp = zeros([V(1).dim(1:2) n]);
Y_ab = zeros(V(1).dim(1:3));
Y_cd = zeros(V(1).dim(1:3));
Index_Matrix = zeros([V(1).dim(1:3) b1map_defs.b1proc.Nonominalvalues]);
real_Y_tmp = zeros([V(1).dim(1:2) 2*b1map_defs.b1proc.Nonominalvalues]);

Ssq_matrix=sqrt(sum(spm_read_vols(V(1:2:end)).^2,4));

%-Start progress plot
%-----------------------------------------------------------------------
spm_progress_bar('Init',V(1).dim(3),'B1 map fit','planes completed');

%-Loop over planes computing result Y
%-----------------------------------------------------------------------
clear Temp_mat;
corr_fact = exp(b1map_defs.b1acq.TM/b1map_defs.b1proc.T1);
for p = 1:V(1).dim(3),%loop over the partition dimension of the data set
    B = spm_matrix([0 0 -p 0 0 0 1 1 1]);
    for i = 1:n/2
        M = inv(B*inv(V(1).mat)*V(1).mat); %#ok<*MINV>
        Y_tmptmp(:,:,((i-1)*2+1))  = real( ...
            acos(corr_fact*spm_slice_vol(V((i-1)*2+2),M,V(1).dim(1:2),0) ./ ...
            (spm_slice_vol(V((i-1)*2+1),M,V(1).dim(1:2),0)+b1map_defs.b1proc.eps))/pi*180/b1map_defs.b1acq.beta(i) ...
            ); % nearest neighbor interpolation
        Y_tmptmp(:,:,((i-1)*2+2))  = 180/b1map_defs.b1acq.beta(i) - Y_tmptmp(:,:,((i-1)*2+1));
        Temp_mat(:,:,i) = spm_slice_vol(V((i-1)*2+1),M,V(1).dim(1:2),0); %#ok<*AGROW>
    end
    
    [~,indexes] = sort(Temp_mat,3);
    for x_nr = 1:V(1).dim(1)
        for y_nr = 1:V(1).dim(2)
            for k=1:b1map_defs.b1proc.Nonominalvalues
                real_Y_tmp(x_nr,y_nr,2*k-1) = Y_tmptmp(x_nr,y_nr,2*indexes(x_nr,y_nr,n/2-k+1)-1);
                real_Y_tmp(x_nr,y_nr,2*k)   = Y_tmptmp(x_nr,y_nr,2*indexes(x_nr,y_nr,n/2-k+1));
                Index_Matrix(x_nr,y_nr,p,k) = indexes(x_nr,y_nr,indexes(x_nr,y_nr,n/2-k+1));
            end
        end
    end
    
    Y_tmp = sort(real(real_Y_tmp), 3); % take the real value due to noise problems
    Y_sd  = zeros([V(1).dim(1:2) (b1map_defs.b1proc.Nonominalvalues+1)]);
    Y_mn  = zeros([V(1).dim(1:2) (b1map_defs.b1proc.Nonominalvalues+1)]);
    for i = 1:(b1map_defs.b1proc.Nonominalvalues+1)
        Y_sd(:,:,i) = std(Y_tmp(:,:,i:(i + b1map_defs.b1proc.Nonominalvalues-1)), [], 3);
        Y_mn(:,:,i) = mean(Y_tmp(:,:,i:(i + b1map_defs.b1proc.Nonominalvalues-1)), 3);
    end
    
    [~,min_index] = min(Y_sd,[],3); % !! min_index is a 2D array. Size given by resolution along read and phase directions
    for x_nr = 1:V(1).dim(1)
        for y_nr = 1:V(1).dim(2)
            Y_ab(x_nr,y_nr,p) = Y_mn(x_nr,y_nr, min_index(x_nr,y_nr)); % Y_ab is the relative flip angle value averaged over the n flip angles (determined by minizing the SD i.e. keeping the most uniform relative flip angle values)
            Y_cd(x_nr,y_nr,p) = Y_sd(x_nr,y_nr, min_index(x_nr,y_nr)); % Y_cd is the corresponding standard deviation between the relative flip angle values
        end
    end
    spm_progress_bar('Set',p);
end

%-Save everything in OUTPUT dir
%-----------------------------------------------------------------------
% determine output directory path
if isfield(jobsubj.output,'indir')
    outpath = fileparts(V(1).fname);
else
    outpath = jobsubj.output.outdir{1};
end
Output_hdr_B1=struct('history',struct('procstep',[],'input',[],'output',[]));
Output_hdr_B1.history.procstep.version='TBD';
Output_hdr_B1.history.procstep.descrip='B1 mapping calculation';
Output_hdr_B1.history.procstep.procpar=b1map_defs;
% Output_hdr_B1.history.input=jobsubj.raw_fld.b1;
Input=jobsubj.raw_fld.b1;
% Input=cat(1,jobsubj.raw_fld.b1,jobsubj.raw_fld.b0);
for ctr=1:numel(Input)
    Output_hdr_B1.history.input{ctr}.filename=Input{ctr};
    input_hdr=hMRI_get_extended_hdr(Input{ctr});
    if ~isempty(input_hdr{1})
        Output_hdr_B1.history.input{ctr}.history=input_hdr{1}.history;
    else
        Output_hdr_B1.history.input{ctr}.history='';
    end
end
Output_hdr_B1.history.output.imtype='B1 map';
Output_hdr_B1.history.output.units='percent (%)';
Output_hdr_SD=Output_hdr_B1;Output_hdr_SSQ=Output_hdr_B1;
Output_hdr_SD.history.output.imtype='SD (error) map';
Output_hdr_SSQ.history.output.imtype='SSQ image';
Output_hdr_SSQ.history.output.units='A.U.';

V_save = struct('fname',V(1).fname,'dim',V(1).dim,'mat',V(1).mat,'dt',V(1).dt,'descrip','B1 map [%]');
[~,name,e] = fileparts(V_save.fname);
V_save.fname = fullfile(outpath,['B1map_' name e]);
V_save = spm_write_vol(V_save,Y_ab*100);
hMRI_set_extended_hdr(V_save.fname,Output_hdr_B1)

W_save = struct('fname',V(1).fname,'dim',V(1).dim,'mat',V(1).mat,'dt',V(1).dt,'descrip','SD [%]');
W_save.fname = fullfile(outpath,['SDmap_' name e]);
W_save = spm_write_vol(W_save,Y_cd*100);
hMRI_set_extended_hdr(W_save.fname,Output_hdr_SD)

X_save = struct('fname',V(1).fname,'dim',V(1).dim,'mat',V(1).mat,'dt',V(1).dt,'descrip','SE SSQ matrix');
X_save.fname = fullfile(outpath,['SumOfSq' e]);
X_save = spm_write_vol(X_save,Ssq_matrix); %#ok<*NASGU>
hMRI_set_extended_hdr(X_save.fname,Output_hdr_SSQ)




%-B0 undistortion
%-----------------------------------------------------------------------
% load default parameters and customize...

%         b1map_defs.b1proc=hmri_get_defaults('b1map.i3D_EPI.b1proc');


% b1_prot = hmri_get_defaults('b1_type.val');
% load the resulting default parameters:

[hdr,IsExtended]=hMRI_get_extended_hdr(jobsubj.raw_fld.b0{1});
b1_prot = jobsubj.b1_type;
if (~IsExtended)
    b0proc_defs = hmri_get_defaults('b1map.i3D_EPI.b0acq');
else
%     [hdr,~]=hMRI_get_extended_hdr(jobsubj.raw_fld.b0{1});
    TEs=hMRI_get_extended_hdr_val(hdr{1},'EchoTime');
    b0proc_defs.shortTE=TEs(1);    b0proc_defs.longTE=TEs(2);
%     b0proc_defs.HZTHRESH = hmri_get_defaults(['b1map.',b1_prot,'.b0proc' '.HZTHRESH']);
%     b0proc_defs.SDTHRESH = hmri_get_defaults(['b1map.',b1_prot,'.b0proc' '.SDTHRESH']);
%     b0proc_defs.ERODEB1 = hmri_get_defaults(['b1map.',b1_prot,'.b0proc' '.ERODEB1']);
%     b0proc_defs.PADB1 = hmri_get_defaults(['b1map.',b1_prot,'.b0proc' '.PADB1']);
%     b0proc_defs.B1FWHM = hmri_get_defaults(['b1map.',b1_prot,'.b0proc' '.B1FWHM']);
%     b0proc_defs.match_vdm = hmri_get_defaults(['b1map.',b1_prot,'.b0proc' '.match_vdm']);
%     b0proc_defs.b0maskbrain = hmri_get_defaults(['b1map.',b1_prot,'.b0proc' '.b0maskbrain']);
end
pm_defaults;
pm_defs = pm_def;
pm_defs.SHORT_ECHO_TIME = b0proc_defs.shortTE;
pm_defs.LONG_ECHO_TIME = b0proc_defs.longTE;
pm_defs.blipdir = b1map_defs.b1acq.blipDIR;
pm_defs.TOTAL_EPI_READOUT_TIME = b1map_defs.b1acq.EchoSpacing*b1map_defs.b1acq.nPEacq;
pm_defs.MASKBRAIN = b1map_defs.b1proc.b0maskbrain;
pm_defs.STDTHRESH = b1map_defs.b1proc.SDTHRESH;
pm_defs.HZTHRESH = b1map_defs.b1proc.HZTHRESH;
pm_defs.ERODEB1 = b1map_defs.b1proc.ERODEB1;
pm_defs.PADB1 = b1map_defs.b1proc.PADB1 ;
pm_defs.B1FWHM = b1map_defs.b1proc.B1FWHM; %For smoothing. FWHM in mm - i.e. it is divided by voxel resolution to get FWHM in voxels
pm_defs.match_vdm = b1map_defs.b1proc.match_vdm;
% USE OF PEDIR NOT CLEAR - WAIT FOR EB'S FEEDBACK
% if ~strcmp(b1_prot,'i3D_EPI_v2b') % also necessary for other sequences?
%     pm_defs.pedir = b1map_defs.PEDIR;
% end

mag1 = spm_vol(Q(1,:));
mag = mag1.fname;
phase1 = spm_vol(Q(3,:));
phase = phase1.fname;
scphase = FieldMap('Scale',phase);
% try to move generated map to the outpath
[~,name,e] = fileparts(scphase.fname);
try                
    movefile(scphase.fname,fullfile(outpath,[name e]));         
catch MExc          
    %fprintf(1,'\n%s\n', MExc.getReport);                  
    fprintf(1,'Output directory is identical to input directory. File doesn''t need to be moved! :)\n');       
end    
scphase.fname = fullfile(outpath,[name e]);
fm_imgs = char(scphase.fname,mag);

% anat_img1 = spm_vol(P_SsqMat);
anat_img1 = spm_vol(X_save.fname);

[path,name,e] = fileparts(anat_img1.fname);
anat_img = {strcat(path,filesep,name,e)};
other_img{1} = char(V_save.fname);
other_img{2} = char(W_save.fname);

[fmap_img,unwarp_img] = hmri_B1Map_unwarp(fm_imgs,anat_img,other_img,pm_defs);
uanat_img{1}=unwarp_img{1}.fname;
ub1_img{1} = unwarp_img{2}.fname;
ustd_img{1} = unwarp_img{3}.fname;

Output_hdr_B1=struct('history',struct('procstep',[],'input',[],'output',[]));
Output_hdr_B1.history.procstep.version='TBD';
Output_hdr_B1.history.procstep.descrip='B1 map - unwarping';
Output_hdr_B1.history.procstep.procpar=b0proc_defs;
Input=cat(1,anat_img,{fm_imgs(2,:)},other_img{1},other_img{2});
for ctr=1:numel(Input)
    Output_hdr_B1.history.input{ctr}.filename=Input{ctr};
    input_hdr=hMRI_get_extended_hdr(Input{ctr});
    if ~isempty(input_hdr{1})
        Output_hdr_B1.history.input{ctr}.history=input_hdr{1}.history;
    else
        Output_hdr_B1.history.input{ctr}.history='';
    end
%     Output_hdr_B1.history.input{ctr}.history=input_hdr{1}.history;
end
Output_hdr_B1.history.output.imtype='unwarped B1 map';
Output_hdr_B1.history.output.units='percent (%)';
Output_hdr_SD=Output_hdr_B1;Output_hdr_SSQ=Output_hdr_B1;
Output_hdr_SD.history.output.imtype='unwarped SD (error) map';
Output_hdr_SSQ.history.output.imtype='unwarped SSQ image';
Output_hdr_SSQ.history.output.units='A.U.';

hMRI_set_extended_hdr(ub1_img{1},Output_hdr_B1);
hMRI_set_extended_hdr(ustd_img{1},Output_hdr_SD);
hMRI_set_extended_hdr(uanat_img{1},Output_hdr_SSQ);

Output_hdr_Others=struct('history',struct('procstep',[],'input',[],'output',[]));
Output_hdr_Others.history.procstep.version='TBD';
Output_hdr_Others.history.procstep.descrip='Fieldmap toolbox outputs';
Output_hdr_Others.history.procstep.procpar=b0proc_defs;
Input=cat(1,{mag1.fname},{phase1.fname});
for ctr=1:numel(Input)
    Output_hdr_Others.history.input{ctr}.filename=Input{ctr};
    input_hdr=hMRI_get_extended_hdr(Input{ctr});
    if ~isempty(input_hdr{1})
        Output_hdr_B1.history.input{ctr}.history=input_hdr{1}.history;
    else
        Output_hdr_B1.history.input{ctr}.history='';
    end
%     Output_hdr_Others.history.input{ctr}.history=input_hdr{1}.history;
end
Output_hdr_Others.history.output.imtype='See FieldMap Toolbox';
Output_hdr_Others.history.output.units='See FieldMap Toolbox';

hMRI_set_extended_hdr(fmap_img{1}.fname,Output_hdr_Others);
hMRI_set_extended_hdr(fmap_img{2}.fname,Output_hdr_Others);
hMRI_set_extended_hdr(fm_imgs(1,:),Output_hdr_Others);


fpm_img{1} = fmap_img{1};
vdm_img{1} = fmap_img{2};
[allub1_img] = hmri_B1Map_process(uanat_img,ub1_img,ustd_img,vdm_img,fpm_img,pm_defs);

P_trans  = char(char(uanat_img),char(allub1_img{2}.fname));

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% this function is adapted from the function calc_AFI_b1map by T. Leutritz
function P_trans = calc_tfl_b1map(jobsubj)

disp('----- Calculation of B1 map (SIEMENS tfl_b1map protocol) -----');

P = char(jobsubj.raw_fld.b1); % scaled FA map from tfl_b1map sequence
Q = char(jobsubj.raw_fld.b0); % FLASH like anatomical from tfl_b1map sequence

% read header information and volumes
V1 = spm_vol(P); % image volume information
V2 = spm_vol(Q);
Vol1 = spm_read_vols(V1);
Vol2 = spm_read_vols(V2);

p = hmri_hinfo(P);
alphanom = p(1).fa; % nominal flip angle of tfl_b1map

% generating the map
B1map_norm = abs(Vol1)*10/alphanom;

% smoothed map
smB1map_norm = zeros(size(B1map_norm));
pxs = sqrt(sum(V1.mat(1:3,1:3).^2)); % Voxel resolution
smth = 8./pxs;
spm_smooth(B1map_norm,smB1map_norm,smth);

% Save everything in OUTPUT dir
%-----------------------------------------------------------------------
% determine output directory path
if isfield(jobsubj.output,'indir')
    outpath = fileparts(V1.fname);
else
    outpath = jobsubj.output.outdir{1};
end

[~, sname] = fileparts(V1.fname);

VB1 = V1;
VB1.pinfo = [max(smB1map_norm(:))/16384;0;0]; % what is this for? (TL)
VB1.fname = fullfile(outpath, [sname '_smB1map_norm.nii']);
spm_write_vol(VB1,smB1map_norm);

% requires anatomic image + map
P_trans  = char(Q,char(VB1.fname));

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function P_trans = calc_rf_map(jobsubj)

disp('----- Calculation of B1 map (SIEMENS rf_map protocol) -----');

P = char(jobsubj.raw_fld.b1); % scaled FA map from rf_map sequence
Q = char(jobsubj.raw_fld.b0); % anatomical image from rf_map sequence

% read header information and volumes
V1 = spm_vol(P); % image volume information
V2 = spm_vol(Q);
Vol1 = spm_read_vols(V1);
Vol2 = spm_read_vols(V2);

% generating the map
B1map_norm = (abs(Vol1)-2048)*180*100/(90*2048); % *100/90 to get p.u. 
% the formula (abs(Vol1)-2048)*180/2048 would result in an absolute FA map

% smoothed map
smB1map_norm = zeros(size(B1map_norm));
pxs = sqrt(sum(V1.mat(1:3,1:3).^2)); % Voxel resolution
smth = 8./pxs;
spm_smooth(B1map_norm,smB1map_norm,smth);

% Save everything in OUTPUT dir
%-----------------------------------------------------------------------
% determine output directory path
if isfield(jobsubj.output,'indir')
    outpath = fileparts(V1.fname);
else
    outpath = jobsubj.output.outdir{1};
end

[~, sname] = fileparts(V1.fname);

VB1 = V1;
VB1.pinfo = [max(smB1map_norm(:))/16384;0;0]; % what is this for? (TL)
VB1.fname = fullfile(outpath, [sname '_smB1map_norm.nii']);
spm_write_vol(VB1,smB1map_norm);

% requires anatomic image + map
P_trans  = char(Q,char(VB1.fname));

end