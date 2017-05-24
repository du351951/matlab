function im = read_image(filename, filetype, roi)
% Reads 'tif', 'img', 'dar', 'ref', and 'edf' images and all the files
% MATLAB's imread function can read without additional arguments than file
% format.
%
% filename: string. Absolute filename.
% filetype: string. Suffix of image file format. Default: ''
%
% Written by Julian Moosmann. Modified: 2016-11-07
%
% im = read_image(filename, filetype)

%% Default arguments 
if nargin < 2
    filetype = '';
end
if nargin < 3
    roi = [];
end

%% TODO: roi support for edf and tiff files

%% Main %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
warning( 'off', 'MATLAB:imagesci:rtifc:missingPhotometricTag');

if isempty( filetype )
    [~, ~, filetype] = fileparts(filename);
end
if strcmp( filetype(1), '.')
    filetype(1) = [];
end

switch lower( filetype )
    case 'edf'
        im = pmedfread( filename );
    case {'tif', 'tiff'}
        im = imread( filename, 'tif' )';
    case {'img', 'dar', 'ref'}
        %im = read_dat( filename, roi );
        im = read_dat_jm( filename, roi );
    otherwise
        im = imread( filename, filetype )';
end
