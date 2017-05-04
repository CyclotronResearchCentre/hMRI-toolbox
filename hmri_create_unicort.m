function out = hmri_create_unicort(P_PDw, P_R1, jobsubj)
% function P = hmri_create_unicort(P_PDw, P_R1, jobsubj)
% P_PDw: proton density weighted FLASH image (small flip angle image) for
% masking
% P_R1: R1 (=1/T1) map estimated from dual flip angle FLASH experiment
%
% P_R1_unicort: filename of corrected R1 map (same as R1 map with "mh" prefix)
% P_B1: filename of UNICORT estimated B1 map (same as R1 map with "B1_" prefix)
%
% Applies UNICORT correction for RF transmit inhomogoeneities to R1 maps
% estimated from dual angle FLASH experiments. The correction is primarily
% based on the SPM8 "New Segment" toolbox.
% Corrected image and B1+ map is written to the same directory where R1 map is located.
%
% Note: Correction is optimized for 3T Magnetom Tim Trio (Siemens
% Healthcare, Erlangen, Germany) and may need to be re-optimized for other
% field strengths and RF coils. It is was also validated for 1mm isotropic
% whole brain human R1 data only. Smaller coverage and lower resolution may
% lead to suboptimal results. It is recommended to cross-validate with an established B1+
% mapping method (e.g., Lutti et al., MRM 2010) when first applied to different datasets.
%
% Warning and disclaimer: This software is for research use only.
% Do not use it for clinical or diagnostic purposes.
%
% For theory and validation, see
% Weiskopf et al. (2010), "Unified segmentation based correction of R1
% brain maps for RF transmit field inhomogeneities (UNICORT)", Neuroimage.
%
% Author: N. Weiskopf, WTCN, London
% 29 November 2010

%%
fprintf(1,'\n    -------- Apply UNICORT correction to R1 map --------\n');

% json metadata default options
json = hmri_get_defaults('json');

% Use default parameters of SPM8 "New Segment" toolbox except for
% adapted regularization and smoothness of bias field
% as determined for 3T Magnetom Tim Trio (Siemens Healthcare, Erlangen, Germany)
% see Weiskopf et al., Neuroimage 2010

unicort_params = hmri_get_defaults('unicort');
reg = unicort_params.reg;
FWHM = unicort_params.FWHM;
thr_factor = unicort_params.thr;

% output directories
mpmpath = jobsubj.path.mpmpath;
b1path = jobsubj.path.b1path;
respath = jobsubj.path.respath;

% create head mask
V_PDw = spm_vol(P_PDw);
Y_PDw = spm_read_vols(V_PDw);
thresh = thr_factor*mode(round(Y_PDw(:)));

% mask R1 map with head/neck mask
V_R1 = spm_vol(P_R1);
Y_R1 = spm_read_vols(V_R1);
Y_R1 = Y_R1.*(Y_PDw > thresh);
V_R1_mask = V_R1;
outfnam = spm_file(P_R1,'filename');
P_R1_mask = fullfile(mpmpath,spm_file(outfnam,'suffix','_masked'));
V_R1_mask.fname = P_R1_mask;
V_R1_mask.descrip = 'Masked R1 map';
spm_write_vol(V_R1_mask,Y_R1);

% set and save metadata
input_files = char(P_PDw,P_R1);
Output_hdr = init_unicort_output_metadata(input_files, unicort_params);
Output_hdr.history.output.imtype = 'Masked R1 map';
Output_hdr.history.output.units = 'ms-1';
set_metadata(P_R1_mask,Output_hdr,json);


%% preparation of spm structure for "New Segment" tool

% clear('matlabbatch');
tpm_nam = hmri_get_defaults('TPM'); % eTPM.nii instead of TPM.nii
% see http://www.unil.ch/lren/home/menuinst/data--utilities.html
% Lorio S, Fresard S, Adaszewski S, Kherif F, Chowdhury R, Frackowiak RS,
% Ashburner J, Helms G, Weiskopf N, Lutti A, Draganski B. New tissue priors
% for improved automated classification of subcortical brain structures on MRI.
% Neuroimage. 2016 Apr 15;130:157-66. doi: 10.1016/j.neuroimage.2016.01.062

preproc8.channel.write = [1 1];
preproc8.tissue(1).tpm = {[tpm_nam ',1']};
preproc8.tissue(1).ngaus = 2;
preproc8.tissue(1).native = [0 0];
preproc8.tissue(1).warped = [0 0];
preproc8.tissue(2).tpm = {[tpm_nam ',2']};
preproc8.tissue(2).ngaus = 2;
preproc8.tissue(2).native = [0 0];
preproc8.tissue(2).warped = [0 0];
preproc8.tissue(3).tpm = {[tpm_nam ',3']};
preproc8.tissue(3).ngaus = 2;
preproc8.tissue(3).native = [0 0];
preproc8.tissue(3).warped = [0 0];
preproc8.tissue(4).tpm = {[tpm_nam ',4']};
preproc8.tissue(4).ngaus = 3;
preproc8.tissue(4).native = [0 0];
preproc8.tissue(4).warped = [0 0];
preproc8.tissue(5).tpm = {[tpm_nam ',5']};
preproc8.tissue(5).ngaus = 4;
preproc8.tissue(5).native = [0 0];
preproc8.tissue(5).warped = [0 0];
preproc8.tissue(6).tpm = {[tpm_nam ',6']};
preproc8.tissue(6).ngaus = 2;
preproc8.tissue(6).native = [0 0];
preproc8.tissue(6).warped = [0 0];
preproc8.warp.reg = [0   0.001   0.5   0.05   0.2];
preproc8.warp.affreg = 'mni';
preproc8.warp.samp = 3;
preproc8.warp.write = [0 0];
preproc8.warp.mrf = 0;
% set parameters different from defaults
preproc8.channel.biasfwhm = FWHM;
preproc8.channel.biasreg = reg;
preproc8.channel.vols = {P_R1_mask};

%% run prepared "New Segment" job
output_list = spm_preproc_run(preproc8);

%% calculate B1+ map from bias field
P_biasmap = output_list.channel.biasfield{1};

% set and save metadata
input_files = P_R1_mask;
Output_hdr = init_unicort_output_metadata(input_files, unicort_params);
Output_hdr.history.output.imtype = 'BiasField for corrected R1 UNICORT map calculation';
Output_hdr.history.output.units = 'a.u.';
set_metadata(P_biasmap,Output_hdr,json);

%% create B1+ map from bias field
V_biasmap = spm_vol(P_biasmap);
Y_biasmap = spm_read_vols(V_biasmap);
Y_B1 = sqrt(Y_biasmap)*100.*(Y_PDw > thresh);
V_B1 = V_R1;
P_B1 = fullfile(b1path,spm_file(outfnam,'prefix','B1u_'));
V_B1.fname = P_B1;
V_B1.descrip = 'UNICORT estimated B1+ map (p.u.)';
spm_write_vol(V_B1,Y_B1);

% set and save metadata
input_files = P_biasmap;
Output_hdr = init_unicort_output_metadata(input_files, unicort_params);
Output_hdr.history.output.imtype = 'UNICORT estimated B1+ map';
Output_hdr.history.output.units = 'p.u.';
set_metadata(P_B1,Output_hdr,json);

% Bias corrected R1 map
P_R1_unicort = output_list.channel.biascorr{1};

% set and save metadata
input_files = char(P_PDw,P_R1);
Output_hdr = init_unicort_output_metadata(input_files, unicort_params);
Output_hdr.history.output.imtype = 'Bias corrected R1 UNICORT map';
Output_hdr.history.output.units = 'ms-1';
set_metadata(P_R1_unicort,Output_hdr,json);

% define output file names
out.R1u = {fullfile(respath,spm_file(outfnam,'suffix','_UNICORT'))};
out.B1u = {fullfile(respath,spm_str_manip(P_B1,'t'))};

% now copy files from calc directory into results directory (nii & json!)
copyfile(P_R1_unicort,out.R1u{1});
try copyfile([spm_str_manip(P_R1_unicort,'r') '.json'],[spm_str_manip(out.R1u{1},'r') '.json']); end %#ok<*TRYNC>
copyfile(P_B1,out.B1u{1});
try copyfile([spm_str_manip(P_B1,'r') '.json'],[spm_str_manip(out.B1u{1},'r') '.json']); end %#ok<*TRYNC>

% save unicort params as json-file
spm_jsonwrite(fullfile(spm_file(out.R1u{1},'path'), 'MPM_map_creation_unicort_params.json'),unicort_params,struct('indent','\t'));

end

%% =======================================================================%
% To arrange the metadata structure for B1 map calculation output.
%=========================================================================%
function metastruc = init_unicort_output_metadata(input_files, unicort_params)

proc.descrip = 'UNICORT';
proc.version = hmri_get_version;
proc.params = unicort_params;

output.imtype = 'B1+ map';
output.units = 'p.u.';

metastruc = init_output_metadata_structure(input_files, proc, output);

end