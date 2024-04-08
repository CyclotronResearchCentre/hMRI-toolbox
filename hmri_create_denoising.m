function varargout = hmri_create_denoising(job)

% retrieve effective acquisition & processing parameters
jobsubj = job.subj;
denoisedout = get_denoising_params(jobsubj);
protocolfield = fieldnames(jobsubj.denoisingtype);
denoising_protocol = protocolfield{1};

%execute the chosen denoising method and define output
switch denoising_protocol
    case 'lcpca_denoise'
[output_mag, output_phase] = hmri_calc_lcpcadenoise(denoisedout);
varargout{1} = output_mag;
varargout{2} = output_phase;
end
end

%=========================================================================%
% Write/Arrange denoising parameters tp the denoising_params.
%=========================================================================%
function denoising_params = get_denoising_params(jobsubj)

% get denoising method
dntypename = fieldnames(jobsubj.denoisingtype);
denoising_protocol = dntypename{1};

% init defaults filename and optional-defaults bool 
deffnam = '';
custom_def = false;

% load customized defaults parameters from customized denoising defaults file if any
% (the customized defaults file must be run to overwrite the standard
% defaults parameters)
if isfield(jobsubj.denoisingtype.(denoising_protocol),'DNparameters')
    % first reinitialise processing parameters to standard defaults:
    hmri_denoising_defaults;
    deffnam = fullfile(fileparts(mfilename('fullpath')),'config','hmri_denoising_defaults.m');
    custom_def = false;

    % then, if customized defaults file available, run it to overwrite
    % standard defaults parameters.
    if isfield(jobsubj.denoisingtype.(denoising_protocol).DNparameters,'DNdefaults')
        deffnam = jobsubj.denoisingtype.(denoising_protocol).DNparameters.DNdefaults;
        spm('Run',deffnam);
        custom_def = true;
    end
end

% set all denoising defaults and set the defaults file to be true
denoising_params = hmri_get_defaults(['denoising.' denoising_protocol]);
denoising_params.defaults_file = deffnam;
denoising_params.custom_defaults = custom_def;

% flags for logging information and warnings
denoising_params.defflags = jobsubj.log.flags; % default flags
denoising_params.nopuflags = jobsubj.log.flags; % force no Pop-Up
denoising_params.nopuflags.PopUp = false;

% save SPM version (slight differences may appear in the results depending
% on the SPM version!)
[v,r] = spm('Ver');
denoising_params.SPMver = sprintf('%s (%s)', v, r);

%Denoising method-specific parameters
%Load all the batch entered and possibly user-modified parameters
switch denoising_protocol
    case 'lcpca_denoise'
        denoising_params.mag_input = cellstr(char(spm_file(jobsubj.denoisingtype.(denoising_protocol).mag_input,'number','')));
        denoising_params.phase_input = cellstr(char(spm_file(jobsubj.denoisingtype.(denoising_protocol).phase_input,'number','')));
        denoising_params.phase_bool = any(~cellfun(@isempty, denoising_params.phase_input));
        denoising_params.mag_bool = any(~cellfun(@isempty, denoising_params.mag_input));
        
        
        %processing can continue if only magnitude images were entered but
        %only warn that optional phase img are missing
        
        if ~denoising_params.phase_bool || ~isfield(jobsubj.denoisingtype.(denoising_protocol),'phase_input')
        hmri_log('No (optional) phase images were entered, Lcpca-denoising continues with only magnitude images', denoising_params.nopuflags);
        warning('No (optional) phase images were entered, Lcpca-denoising continues with only magnitude images')
        end
        

        dnstruct = jobsubj.denoisingtype.lcpca_denoise;
        denoising_params.ngbsize =dnstruct.ngbsize;
        denoising_params.std =dnstruct.std;
        denoising_params.output_path = jobsubj.path.dnrespath;
        denoising_params.supp_path = jobsubj.path.supplpath;

        %Print lcpca denoising parameters ngbsize and std cut off
        print_lcpca_params.Neighborhood_Size = denoising_params.ngbsize;
        print_lcpca_params.Standard_Deviation_Cuttoff =  denoising_params.std;
        printdnstruct = printstruct(print_lcpca_params);
        hmri_log(sprintf('Lcpca Denoising Parameters:\n\n%s\n\n%s\n\n%s\n\n\n', ...
        printdnstruct{2}, printdnstruct{3}, printdnstruct{4}),denoising_params.nopuflags);

end

end

%===============================================================================================%
% Calculate LCPCA-denoising: Java-Matlab interface for Lcpca-denoising(P. Bazin et al.)
%=================================================================================================%
function [output_mag, output_phase] = hmri_calc_lcpcadenoise(lcpcadenoiseparams)

%get the path to the jar files
[mfilepath, ~,~] = fileparts(mfilename("fullpath"));
jarcommons = fullfile(fullfile(mfilepath,'jar'),'commons-math3-3.5.jar');
jarmipav = fullfile(fullfile(mfilepath,'jar'),'Jama-mipav.jar');
jarlcpca = fullfile(fullfile(mfilepath,'jar'),'lcpca2.jar');

%add required .jar files to the path
javaaddpath(jarcommons)
javaaddpath(jarmipav)
javaaddpath(jarlcpca)

%Read from the input the processing parameters
image_list = cellstr(lcpcadenoiseparams.mag_input);
phase_list = cellstr(lcpcadenoiseparams.phase_input);
ngb_size = lcpcadenoiseparams.ngbsize;
stdev_cutoff = lcpcadenoiseparams.std;
min_dimension = lcpcadenoiseparams.min_dimension;
max_dimension = lcpcadenoiseparams.max_dimension;
unwrap = lcpcadenoiseparams.unwrap;
rescale_phs = lcpcadenoiseparams.rescale_phs;
process_2d = lcpcadenoiseparams.process_2d;
use_rmt = lcpcadenoiseparams.use_rmt;
output_path = cellstr(lcpcadenoiseparams.output_path);
supp_path = cellstr(lcpcadenoiseparams.supp_path);
lcpcaflags = lcpcadenoiseparams.defflags;

%Get the full input file list
phase_bool = any(~cellfun(@isempty,phase_list));
if phase_bool
    fullim_list = [image_list; phase_list];
else
    fullim_list = image_list;
end

%set the metadata mod
json = hmri_get_defaults('json');

%Create denoising object
noiseObj= javaObject('nl.uva.imcn.algorithms.LocalComplexPCADenoising');

%Get the image_number and dimensions from the first image of magnitude
%images
imdatavol = spm_vol(image_list{1});
resolutions = sqrt(sum(imdatavol.mat(1:3,1:3).^2)); 
imdatamatrix = spm_read_vols(imdatavol);
dimensions = size(imdatamatrix);
image_number = length(image_list)+1;

%Set the image_number, dimensions and resolution for processing
noiseObj.setImageNumber(image_number); %number of echoes

%Set dimensions based on whether it is 3D or 4D data
%Throw an error if neither
if length(dimensions) == 3
noiseObj.setDimensions(dimensions(1),dimensions(2),dimensions(3));
elseif length(dimensions) == 4
noiseObj.setDimensions(dimensions(1),dimensions(2),dimensions(3), dimensions(4));
else
    hmri_log('The raw data does not have the correct dimensions (must be 3D or 4D data) for processing: please check your data!', lcpcaflags);
    error('The raw data does not have the correct dimensions (must be 3D or 4D data) for processing: please check your data!')
end
noiseObj.setResolutions(resolutions(1),resolutions(2), resolutions(3)); % see also mpm_denoise

end