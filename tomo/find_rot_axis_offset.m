function [vol, m] = find_rot_axis_offset(proj, angles, slice, offsets, tilt, take_neg_log, number_of_stds, vol_shape, lamino, fixed_tilt, gpu_index, offset_shift)
% Reconstruct slices from sinogram for a range of rotation axis positoin
% offsets.
%
% RETURN
% vol : 3D array. stack of slices with different rotation axis position
% offsets
% m : struct containing different metrics: mean of all values,
% mean of all absolute values, mean non-negative values, mean of isotropic
% modulus of gradient, mean of Laplacian, entropy
% 
% Written by Julian Moosmann. Last modification: 2017-04-05
%
% [vol, m] = find_rot_axis_offset(proj, angles, slice, offsets, tilt, take_neg_log, number_of_stds, vol_shape)

%% Default arguments %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin < 3
    slice = [];
end
if nargin < 4
    offsets = -10:10;
end
if nargin < 5
    tilt = 0; 
end
if nargin < 6
   take_neg_log = 1;
end
if nargin < 7
    number_of_stds = 4;
end
if nargin < 8
    vol_shape = [];
end
if nargin < 9
    lamino = 0;
end
if nargin < 10
    fixed_tilt = 0;
end
if nargin < 11
    gpu_index = [];
end
if nargin < 12
    offset_shift = 0;
end
mask_rad = 0.95;
mask_val = 0;
butterworth_filtering = 0;
astra_pixel_size = 1;
link_data = 1;
filter_histo_roi = 0.25;

%% Main %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
angles = double( angles );
offsets = double( offsets );
[num_pix, num_row, ~] = size( proj );
if isempty( vol_shape )
    vol_shape = [num_pix, num_pix, 1];
else
    vol_shape(3) = 1;
end
vol_size = [-num_pix/2 num_pix/2 -num_pix/2 num_pix/2 -0.5 0.5];
if isempty( slice )
    slice = round( num_row / 2 );
end

% Calculate required slab
rot_axis_pos = offsets + vol_shape(1) / 2;
l = max( max( rot_axis_pos) , max( abs( vol_shape(1) - rot_axis_pos ) ) );
dz = ceil( sin( abs( tilt ) ) * l ); % maximum distance between sino plane and reco plane
if slice - dz < 0 || slice + dz > num_row
    fprintf( '\nWARNING: Inclination of reconstruction plane, slice %u, exceeds sinogram volume. Better choose a more central slice or a smaller tilts.', slice)
end

% Slab
y_range = slice + (-dz:dz);
sino = proj(:, y_range, :);

% Ramp filter
filt = iradonDesignFilter('Ram-Lak', 2 * num_pix, 0.9);

% Butterworth filter
if butterworth_filtering(1)
    [b, a] = butter(1, 0.5);
    bw = freqz(b, a, numel(filt) );
    filt = filt .* bw;
end

% Apply filters
sino = padarray( NegLog(sino, take_neg_log), [num_pix 0 0 ], 'symmetric', 'post');
sino = real( ifft( bsxfun(@times, fft( sino, [], 1), filt), [], 1, 'symmetric') );
sino = sino(1:num_pix,:,:);

% Metrics
m(1).name = 'mean';
m(2).name = 'abs';
m(3).name = 'neg';
m(4).name = 'iso-grad';
m(5).name = 'laplacian';
m(6).name = 'entropy';
m(7).name = 'entropy-ML';

% Preallocation
vol = zeros(vol_shape(1), vol_shape(2), numel(offsets));
for nn = 1:numel(m)
    m(nn).val = zeros( numel(offsets), 1);
end

% Backprojection
for nn = 1:numel( offsets )
    offset = offsets(nn) + offset_shift + eps;
    
    %% Reco
    if ~lamino
        im = astra_parallel3D( permute( sino, [1 3 2]), angles, offset, vol_shape, vol_size, astra_pixel_size, link_data, tilt, gpu_index, fixed_tilt);
    else
        im = astra_parallel3D( permute( sino, [1 3 2]), angles, offset, vol_shape, vol_size, astra_pixel_size, link_data, fixed_tilt, gpu_index, tilt);
    end

    vol(:,:,nn) = FilterHisto(im, number_of_stds, filter_histo_roi);    
    %% Metrics    
    im = double( MaskingDisc( im, mask_rad, mask_val) ) * 2^16;
    % mean    
    m(1).val(nn) = mean2( im );
    % mean abs
    m(2).val(nn) = mean2( abs( im ) );
    % mean negativity
    m(3).val(nn) = - mean( im( im <= 0 ) );
    % isotropic gradient
    [g1, g2] = gradient(im);
    m(4).val(nn) = mean2( sqrt( g1.^2 + g2.^2 ) );
    % laplacian
    m(5).val(nn) = mean2( abs( del2( im ) ) );
    % entropy
    p = histcounts( im(:) );
    p = p(p>0);
    p = p / sum( p );
    m(6).val(nn) = -sum( p .* log2( p ) );
    % entropy built-in
    m(7).val(nn) = -entropy( im );

end

% Normalize for ease of plotting and comparison
for nn = 1:numel(m)
    m(nn).val = normat( m(nn).val );
end
