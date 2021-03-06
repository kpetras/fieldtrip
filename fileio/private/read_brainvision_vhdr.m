function [hdr] = read_brainvision_vhdr(filename)

% READ_BRAINVISION_VHDR reads the known items from the BrainVision EEG
% header file and returns them in a structure
%
% Use as
%   hdr = read_brainvision_vhdr(filename)
%
% See also READ_BRAINVISION_EEG, READ_BRAINVISION_VMRK

% Copyright (C) 2003, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

hdr.DataFile         = read_asa(filename, 'DataFile=', '%s');
hdr.MarkerFile       = read_asa(filename, 'MarkerFile=', '%s');
hdr.DataFormat       = read_asa(filename, 'DataFormat=', '%s');
hdr.DataOrientation  = read_asa(filename, 'DataOrientation=', '%s');
hdr.BinaryFormat     = read_asa(filename, 'BinaryFormat=', '%s');
hdr.NumberOfChannels = read_asa(filename, 'NumberOfChannels=', '%d');
hdr.SamplingInterval = read_asa(filename, 'SamplingInterval=', '%f');   % microseconds

if ~isempty(hdr.NumberOfChannels)
  for i=1:hdr.NumberOfChannels
    chan_str  = sprintf('Ch%d=', i);
    chan_info = read_asa(filename, chan_str, '%s');
    t = tokenize(chan_info, ',');
    hdr.label{i} = t{1};
    hdr.reference{i} = t{2};
    resolution = str2num(t{3});          % in microvolt
    if ~isempty(resolution)
      hdr.resolution(i) = resolution;
    else
      ft_warning('unknown resolution (i.e. recording units) for channel %d in %s', i, filename);
      hdr.resolution(i) = 1;
    end
  end
end

% compute the sampling rate in Hz
hdr.Fs = 1e6/(hdr.SamplingInterval);

% the number of samples is unkown to start with
hdr.nSamples = Inf;

% confirm the names of the .vmrk and .eeg files
[p, f, x] = fileparts(filename);
datafile = fullfile(p, hdr.DataFile); % add full-path to datafile
sameEEGname=fullfile(p,[f '.eeg']);
sameVMRKname=fullfile(p,[f '.vmrk']);
markerFile=fullfile(p,hdr.MarkerFile);

info = dir(datafile);
if isempty(info)
  info = dir(filename);
  if ~isempty(info)
    hdr.DataFile=sameEEGname;
    disp(['Note: Could not find .eeg file (' datafile ') named in .vhdr file so will use .eeg file with same stem as .vhdr file (' sameEEGname ').']);
    datafile=sameEEGname;
  else
    ft_error('cannot determine the location of the data file %s', datafile);
  end;
else
  if ~strcmp(datafile,sameEEGname)
    disp(['Note: Name of the .eeg file (' datafile ') listed in the .vhdr file is different than the current stem of the .vhdr file (' sameEEGname ').']);
  end;
end

info = dir(markerFile);
if isempty(info)
  info = dir(sameVMRKname);
  if ~isempty(info)
    hdr.MarkerFile=[f '.vmrk'];
    disp(['Note: Could not find .vmrk file (' markerFile ') named in .vhdr file so will use .vrmk file with same stem as .vhdr file (' sameVMRKname ').']);
  else
    ft_error('cannot determine the location of the marker file %s', markerFile);
  end;
else
  if ~strcmp(markerFile,sameVMRKname)
    disp(['Note: Name of the .vmrk file (' markerFile ') listed in the .vhdr file is different than the current stem of the .vhdr file (' sameVMRKname ').']);
  end;
end

% determine the number of samples by looking at the binary file
if strcmpi(hdr.DataFormat, 'binary')
  % the data file is supposed to be located in the same directory as the header file
  % but that might be on another location than the present working directory
  
  info = dir(datafile);
  switch lower(hdr.BinaryFormat)
    case 'int_16';
      hdr.nSamples = info.bytes./(hdr.NumberOfChannels*2);
    case 'int_32';
      hdr.nSamples = info.bytes./(hdr.NumberOfChannels*4);
    case 'ieee_float_32';
      hdr.nSamples = info.bytes./(hdr.NumberOfChannels*4);
  end
  
elseif strcmpi(hdr.DataFormat, 'ascii')
  hdr.skipLines = 0;
  hdr.skipColumns = 0;
  
  % Read ascii info from header (if available).
  dataPoints = read_asa(filename, 'DataPoints=', '%d');
  skipLines = read_asa(filename, 'SkipLines=', '%d');
  skipColumns = read_asa(filename, 'SkipColumns=', '%d');
  decimalSymbol = read_asa(filename, 'DecimalSymbol=', '%s'); % This is not used in reading dataset yet
  
  if ~isempty(dataPoints); hdr.nSamples = dataPoints; end;
  if ~isempty(skipLines); hdr.skipLines = skipLines; end;
  if ~isempty(skipColumns); hdr.skipColumns = skipColumns; end;
  if ~isempty(decimalSymbol); hdr.decimalSymbol = decimalSymbol; end;
  
  if isempty(dataPoints) && strcmpi(hdr.DataOrientation, 'vectorized')
    % this is a very inefficient fileformat to read data from, it looks like this:
    % Fp1   -2.129 -2.404 -18.646 -15.319 -4.081 -14.702 -23.590 -8.650 -3.957
    % AF3   -24.023 -23.265 -30.677 -17.053 -24.889 -35.008 -21.444 -15.896 -12.050
    % F7    -10.553 -10.288 -19.467 -15.278 -21.123 -25.066 -14.363 -10.774 -15.396
    % F3    -28.696 -26.314 -35.005 -27.244 -31.401 -39.445 -30.411 -20.194 -16.488
    % FC1   -35.627 -29.906 -38.013 -33.426 -40.532 -49.079 -38.047 -26.693 -22.852
    % ...
    fid = fopen_or_error(datafile, 'rt');
    tline = fgetl(fid);             % read the complete first line
    fclose(fid);
    t = tokenize(tline, ' ', true); % cut the line into pieces
    hdr.nSamples = length(t) - 1;   % the first element is the channel label
  end;
end

if isinf(hdr.nSamples)
  ft_warning('cannot determine number of samples for this sub-fileformat');
end

% the number of trials is unkown, assume continuous data
hdr.nTrials     = 1;
hdr.nSamplesPre = 0;

% ensure that the labels are in a column
hdr.label      = hdr.label(:);
hdr.reference  = hdr.reference(:);
hdr.resolution = hdr.resolution(:);

%read in impedance values
hdr.impedances.channels=[];
hdr.impedances.reference=[];
hdr.impedances.ground=NaN;
hdr.impedances.refChan=[];

try
  fid = fopen_or_error(filename, 'rt');
catch err
  % quash
  % TODO: Are we sure we want this to just silently return, instead of raising
  % an error or printing a warning?
  return
end
while ~feof(fid)
  tline = fgetl(fid);
  if (length(tline) >= 9) && strcmp(tline(1:9),'Impedance')
    chanCounter=0;
    refCounter=0;
    impCounter=0;
    while chanCounter<hdr.NumberOfChannels && ~feof(fid)
      chan_info = fgetl(fid);
      if ~isempty(chan_info)
        impCounter=impCounter+1;
        [chanName,impedances] = strtok(chan_info,':');
        spaceList=strfind(chanName,' ');
        if ~isempty(spaceList)
          chanName=chanName(spaceList(end)+1:end);
        end;
        if strfind(chanName,'REF_')==1 %for situation where there is more than one reference
          refCounter=refCounter+1;
          hdr.impedances.refChan(refCounter)=impCounter;
          if ~isempty(impedances)
            hdr.impedances.reference(refCounter) = str2double(impedances(2:end));
          else
            hdr.impedances.reference(refCounter) = NaN;
          end
        elseif strcmpi(chanName,'ref') %single reference
          refCounter=refCounter+1;
          hdr.impedances.refChan(refCounter)=impCounter;
          if ~isempty(impedances)
            hdr.impedances.reference(refCounter) = str2double(impedances(2:end));
          else
            hdr.impedances.reference(refCounter) = NaN;
          end
        else
          chanCounter=chanCounter+1;
          if ~isempty(impedances)
            hdr.impedances.channels(chanCounter,1) = str2double(impedances(2:end));
          else
            hdr.impedances.channels(chanCounter,1) = NaN;
          end
        end;
      end;
    end
    if ~feof(fid)
      tline='';
      while ~feof(fid) && isempty(tline)
        tline = fgetl(fid);
      end;
      if ~isempty(tline)
        if strcmp(tline(1:4),'Ref:')
          refCounter=refCounter+1;
          [chanName,impedances] = strtok(tline,':');
          if ~isempty(impedances)
            hdr.impedances.reference(refCounter) = str2double(impedances(2:end));
          else
            hdr.impedances.reference(refCounter) = NaN;
          end
        end
        if strcmpi(tline(1:4),'gnd:')
          [chanName,impedances] = strtok(tline,':');
          hdr.impedances.ground = str2double(impedances(2:end));
        end
      end;
    end;
    if ~feof(fid)
      tline='';
      while ~feof(fid) && isempty(tline)
        tline = fgetl(fid);
      end;
      if ~isempty(tline)
        if strcmpi(tline(1:4),'gnd:')
          [chanName,impedances] = strtok(tline,':');
          hdr.impedances.ground = str2double(impedances(2:end));
        end
      end;
    end;
  end;
end;
fclose(fid);
