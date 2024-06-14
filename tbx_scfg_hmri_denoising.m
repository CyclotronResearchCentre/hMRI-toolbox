function denoise = tbx_scfg_hmri_denoising

%--------------------------------------------------------------------------
% To enable/disable pop-up messages for all warnings - recommended when
% piloting the data processing.
%--------------------------------------------------------------------------
popup        = cfg_menu;
popup.tag    = 'popup';
popup.name   = 'Pop-up warnings';
popup.help   = {['The user can review and keep track of all the information ' ...
    'collected, including warnings and other messages coming up during ' ...
    'the creation of the maps. By default, the information is logged in ' ...
    'the Matlab Command Window, in a log file saved in the "Results" ' ...
    'directory, and when more critical, displayed as a pop-up message.'], ...
    ['The latter must be disabled for processing series of datasets (since it ' ...
    'blocks the execution of the code) but it is strongly recommended to ' ...
    'leave it enabled when piloting the data processing (single subject) ' ...
    'to read through and acknowledge every message and make sure ' ...
    'everything is set up properly before running the processing on a ' ...
    'whole group.'], ...
    ['More information about the various messages and action to be taken ' ...
    '(or not) accordingly can be found on the hMRI-Toolbox WIKI (http://hmri.info). ' ...
    'In particular, see the "Debug tips & tricks" section.']};
popup.labels = {'Disable' 'Enable'};
popup.values = {false true};
popup.val = {true};

%--------------------------------------------------------------------------
% Denoising (DN) defaults file
%--------------------------------------------------------------------------
DNdefaults         = cfg_files;
DNdefaults.tag     = 'DNdefaults';
DNdefaults.name    = 'Customised DN defaults file';
DNdefaults.help    = {['Select the [hmri_denoising*_defaults_*.m] file containing ' ...
    'the parameters to process the denoising.'], ...
    ['Please make sure that the modified denoising (optional) parameters ' ...
    'are correct for your data. To create your own customised defaults file, ' ...
    'edit the distributed version and save it with a meaningful name such as ' ...
    '[hmri_denoising_local_defaults.m].']};
DNdefaults.filter  = 'm';
DNdefaults.dir     = fullfile(fileparts(mfilename('fullpath')),'config','local');
DNdefaults.ufilter = [...
    '(?i)',   ... ignore case
    '^hmri_', ... filename starts with 'hmri_'
    '.*denoising.*', ... filename includes 'denoising' somewhere in the middle
    '\.m$'    ... filename ends with '.m'
    ];
DNdefaults.num     = [1 1];

% ---------------------------------------------------------------------
% Use metadata or standard defaults (no customization)
% ---------------------------------------------------------------------
DNmetadata         = cfg_entry;
DNmetadata.tag     = 'DNmetadata';
DNmetadata.name    = 'Use metadata or standard defaults';
DNmetadata.help    = {''};
DNmetadata.strtype = 's';
DNmetadata.num     = [1 Inf];
DNmetadata.val     = {'yes'};

%--------------------------------------------------------------------------
% DN processing parameters
%--------------------------------------------------------------------------
DNparameters        = cfg_choice;
DNparameters.tag    = 'DNparameters';
DNparameters.name   = 'Processing parameters';
DNparameters.help   = {['You can either stick with metadata and standard ' ...
    'defaults parameters (recommended) or select your own customised defaults file. ' ...
    'For possible modification of default parameters, please be careful about which parameters are '...
    'required and which parameters are optional.']};
DNparameters.values = {DNmetadata DNdefaults};
DNparameters.val    = {DNmetadata};

% ---------------------------------------------------------------------
% Magnitude input images
% ---------------------------------------------------------------------
mag_img         = cfg_files;
mag_img.tag     = 'mag_input';
mag_img.name    = 'Magnitude input (required)';
mag_img.help    = {'Select the (required) magnitude images to be denoised'};
mag_img.filter  = 'image';
mag_img.ufilter = '.*';
mag_img.num     = [1 Inf];

% ---------------------------------------------------------------------
% Phase input images
% ---------------------------------------------------------------------
phase_img         = cfg_files;
phase_img.tag     = 'phase_input';
phase_img.name    = 'Phase input (optional)';
phase_img.help    = {'Select the (optional) phase images to be denoised'};
phase_img.filter  = 'image';
phase_img.ufilter = '.*';
phase_img.num     = [0 Inf];
phase_img.val     = {''};

% ---------------------------------------------------------------------
% Standard deviation parameter
% ---------------------------------------------------------------------
std         = cfg_entry;
std.tag     = 'std';
std.name    = 'Standard deviation cut-off';
std.val     = {1.05};
std.strtype = 'e';
std.num     = [1 1];
std.help    = {'Specify the standard deviation cut off for denoising', ['This parameter' ...
    ' is the factor of the local noise level to remove PCA components. Higher values remove more components.' ...
    ' The optimal cutoff can be increased when including more images. ' ...
    ' We recommend the following cut-off sizes for various image numbers:' ...
    ' 5-10: 1.05, 10-20: 1.10, 20+: 1.20']};

% ---------------------------------------------------------------------
% Neighborhood size
% ---------------------------------------------------------------------
ngbsize         = cfg_entry;
ngbsize.tag     = 'ngbsize';
ngbsize.name    = 'Neighborhood size';
ngbsize.val     = {4};
ngbsize.strtype = 'e';
ngbsize.num     = [1 1];
ngbsize.help    = {'Specify the neghborhood size', ['This parameter' ...
    ' sets the size of the local PCA neighborhood.' ...
    ' Though the default size is 4, a size of 3 works better in lower resolutions.']};

% ---------------------------------------------------------------------
% LCPCA Denoising protocol
% ---------------------------------------------------------------------
denoisinginput_lcpca      = cfg_branch;
denoisinginput_lcpca.tag  = 'lcpca_denoise';
denoisinginput_lcpca.name = 'LCPCA denoising';
denoisinginput_lcpca.help = {'Input Magnitude/Phase images for Lcpca-denoising'
    ['Regarding processing parameters, you can either stick with metadata and standard ' ...
    'defaults parameters (recommended) or select your own [hmri_denoising_local_defaults_*.m] customised defaults file.']};
denoisinginput_lcpca.val  = {mag_img phase_img DNparameters std ngbsize};

% ---------------------------------------------------------------------
% menu denoisingtype
% ---------------------------------------------------------------------
denoisingtype        = cfg_choice;
denoisingtype.tag    = 'denoisingtype';
denoisingtype.name   = 'Denoising method for raw/processed images';
denoisingtype.help   = {'Choose the methods for denoising.'
    ['Various types of denoising methods can be handled by the hMRI ' ...
    'toolbox. See list below for a ' ...
    'brief description of each type.']
    ['- Lcpca denoising: Bazin, et al. (2019) Denoising High-Field Multi-Dimensional MRI With Local'...
    'Complex PCA, Front. Neurosci. doi:10.3389/fnins.2019.01066']
    ' - No denoising:...'};
denoisingtype.values = {denoisinginput_lcpca};
denoisingtype.val    = {denoisinginput_lcpca};

% ---------------------------------------------------------------------
% indir Input directory as output directory
% ---------------------------------------------------------------------
indir         = cfg_entry;
indir.tag     = 'indir';
indir.name    = 'Input directory';
indir.help    = {['Output files will be written to the same folder ' ...
    'as each corresponding input file.']};
indir.strtype = 's';
indir.num     = [1 Inf];
indir.val     = {'yes'};

% ---------------------------------------------------------------------
% outdir Output directory
% ---------------------------------------------------------------------
outdir         = cfg_files;
outdir.tag     = 'outdir';
outdir.name    = 'Output directory';
outdir.help    = {'Select a directory where output files will be written to.'};
outdir.filter = 'dir';
outdir.ufilter = '.*';
outdir.num     = [1 1];

% ---------------------------------------------------------------------
% output Output choice
% ---------------------------------------------------------------------
output         = cfg_choice;
output.tag     = 'output';
output.name    = 'Output choice';
output.help    = {['Output directory can be the same as the input ' ...
    'directory for each input file or user selected']};
output.values  = {indir outdir};
output.val = {indir};

% ---------------------------------------------------------------------
% subj Subject
% ---------------------------------------------------------------------
subj            = cfg_branch;
subj.tag        = 'subj';
subj.name       = 'Subject';
subj.help       = {'Specify a subject for denoising.'};
subj.val        = {output denoisingtype popup};

% ---------------------------------------------------------------------
% data Data
% ---------------------------------------------------------------------
sdata           = cfg_repeat;
sdata.tag       = 'data';
sdata.name      = 'Few Subjects';
sdata.help      = {'Specify the number of subjects.'};
sdata.num       = [1 Inf];
sdata.val       = {subj};
sdata.values    = {subj};

% ---------------------------------------------------------------------
% denoise images
% ---------------------------------------------------------------------
denoise         = cfg_exbranch;
denoise.tag     = 'denoise';
denoise.name    = 'Denoising';
denoise.val     = { sdata };
denoise.help    = {'Denoising of raw/processed images with different methods'};
denoise.prog    = @hmri_run_denoising;
denoise.vout    = @vout_create;

end

% ========================================================================
%% VOUT & OTHER SUBFUNCTIONS
% ========================================================================
% The RUN function:
% - out = hmri_run_denoising(job)
% is defined separately.
%_______________________________________________________________________

function dep = vout_create(job)
% This depends on job contents, which may not be present when virtual
% outputs are calculated, depending on the denoising type.

dnfield = fieldnames(job.subj.denoisingtype);
denoisingmethod = dnfield{1};

switch denoisingmethod
    case 'lcpca_denoise'
        % define variables and initialize cfg_dep based on availibility of phase images
        arrayLength = numel(job.subj.denoisingtype.lcpca_denoise.mag_input);
        % phase_bool= any(~cellfun(@isempty, job.subj.denoisingtype.lcpca_denoise.phase_input));
        phase_bool = isempty(job.subj.denoisingtype.lcpca_denoise.phase_input);
        if phase_bool
            cdep(1,2*arrayLength) = cfg_dep;
        else
            cdep(1,arrayLength) = cfg_dep;
        end

        % iterate to generate dependency tags for outputs
        for i=1:numel(job.subj)
            for k =1:2*arrayLength
                if k<=arrayLength
                    cdep(k)            = cfg_dep;
                    cdep(k).sname      = sprintf('lcpcaDenoised_magnitude%d',k);
                    idxstr = ['DenoisedMagnitude' int2str(k)];
                    cdep(k).src_output = substruct('.','subj','()',{i},'.',idxstr,'()',{':'});
                    cdep(k).tgt_spec   = cfg_findspec({{'filter','image','strtype','e'}});

                elseif k>arrayLength && ~phase_bool
                    cdep(k)            = cfg_dep;
                    cdep(k).sname      = sprintf('lcpcaDenoised_phase%d',k-arrayLength);
                    idxstr = ['DenoisedPhase' int2str(k-arrayLength)];
                    cdep(k).src_output = substruct('.','subj','()',{i},'.',idxstr,'()',{':'});
                    cdep(k).tgt_spec   = cfg_findspec({{'filter','image','strtype','e'}});
                else
                    break
                end
            end
        end
        dep = cdep;
end
end