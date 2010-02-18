function ft_clusterplot(cfg, stat)

% CLUSTERPLOT plots a series of topoplots with found clusters highlighted.
% stat is 2D or 1D data from TIMELOCKSTATISTICS or FREQSTATISTICS with 'cluster'
% as cfg.correctmc. 2D: stat from timelockstatistics not averaged over
% time, or stat from freqstatistics averaged over frequency not averaged over
% time. 1D: averaged over time as well.
%
% use as: clusterplot(cfg,stat)
%
% configuration options
% cfg.alpha                     = number, highest cluster p-value to be plotted
%                                 max 0.3 (default = 0.05)
% cfg.highlightseries           = 1x5 cell-array, highlight option series ('on','labels','numbers')
%                                 default {'on','on','on','on','on'} for p < [0.01 0.05 0.1 0.2 0.3]
% cfg.highlightsymbolseries     = 1x5 vector, highlight marker symbol series
%                                 default ['*','x','+','o','.'] for p < [0.01 0.05 0.1 0.2 0.3]
% cfg.highlightsizeseries       = 1x5 vector, highlight marker size series
%                                 default [6 6 6 6 6] for p < [0.01 0.05 0.1 0.2 0.3]
% cfg.highlightcolorpos         = color of highlight marker for positive clusters
%                                 default = [0 0 0]
% cfg.highlightcolorneg         = color of highlight marker for negative clusters
%                                 default = [0 0 0]
% cfg.saveaspng                 = string, path where figure has to be saved to (default = 'no')
%                                 When multiple figures figure gets extension with fignum
%
% It is also possible to specify other cfg options that apply to TOPOPLOTER.
% You CANNOT specify cfg.xlim, any of the TOPOPLOTER highlight
% options, cfg.comment and cfg.commentpos.
%
% See also:
%   topoplotER, singleplotER

% Copyright (C) 2007, Ingrid Nieuwenhuis, F.C. Donders Centre
%
% Subversion does not use the Log keyword, use 'svn log <filename>' or 'svn -v log | less' to get detailled information

fieldtripdefs

% check if given data is appropriate
if isfield(stat,'freq') && length(stat.freq) > 1
  error('stat contains multiple frequencies which is not allowed because it should be averaged over frequencies')
end

% old config options
cfg = checkconfig(cfg, 'renamed',     {'hlmarkerseries',       'highlightsymbolseries'});
cfg = checkconfig(cfg, 'renamed',     {'hlmarkersizeseries',   'highlightsizeseries'});
cfg = checkconfig(cfg, 'renamed',     {'hlcolorpos',           'highlightcolorpos'});
cfg = checkconfig(cfg, 'renamed',     {'hlcolorneg',           'highlightcolorneg'});
cfg = checkconfig(cfg, 'deprecated',  {'hllinewidthseries'});

% added several forbidden options  
cfg = checkconfig(cfg, 'forbidden',  {'highlight'});
cfg = checkconfig(cfg, 'forbidden',  {'highlightchannel'});
cfg = checkconfig(cfg, 'forbidden',  {'highlightsymbol'});
cfg = checkconfig(cfg, 'forbidden',  {'highlightcolor'});
cfg = checkconfig(cfg, 'forbidden',  {'highlightsize'});
cfg = checkconfig(cfg, 'forbidden',  {'highlightfontsize'});
cfg = checkconfig(cfg, 'forbidden',  {'xlim'});
cfg = checkconfig(cfg, 'forbidden',  {'comment'});
cfg = checkconfig(cfg, 'forbidden',  {'commentpos'});


% set the defaults
if ~isfield(cfg,'alpha'),                  cfg.alpha = 0.05;                                    end;
if ~isfield(cfg,'highlightseries'),        cfg.highlightseries = {'on','on','on','on','on'};    end;
if ~isfield(cfg,'highlightsymbolseries'),  cfg.highlightsymbolseries = ['*','x','+','o','.'];   end;
if ~isfield(cfg,'highlightsizeseries'),    cfg.highlightsizeseries = [6 6 6 6 6];               end;
if ~isfield(cfg,'hllinewidthseries'),      cfg.hllinewidthseries = [1 1 1 1 1];                 end;
if ~isfield(cfg,'highlightcolorpos'),      cfg.highlightcolorpos = [0 0 0];                     end;
if ~isfield(cfg,'highlightcolorneg'),      cfg.highlightcolorneg = [0 0 0];                     end;
if ~isfield(cfg,'zparam'),                 cfg.zparam = 'stat';                                 end;
if ~isfield(cfg,'saveaspng'),              cfg.saveaspng = 'no';                                end;

% error if cfg.highlightseries is not a cell, for possible confusion with cfg-options
if ~iscell(cfg.highlightseries)
  error('cfg.highlightseries should be a cell-array of strings')
end

% set additional options for topoplotting
if isfield(cfg, 'marker'),                cfgtopo.marker         = cfg.marker ;         end
if ~isfield(cfg,'marker'),                cfgtopo.marker         = 'off';               end
if isfield(cfg, 'markersymbol'),          cfgtopo.markersymbol   = cfg.markersymbol;    end
if isfield(cfg, 'markercolor'),           cfgtopo.markercolor    = cfg.markercolor;     end
if isfield(cfg, 'markersize'),            cfgtopo.markersize     = cfg.markersize;      end
if isfield(cfg, 'markerfontsize'),        cfgtopo.markerfontsize = cfg.markerfontsize;  end
if isfield(cfg, 'style'),                 cfgtopo.style          = cfg.style ;          end
if isfield(cfg, 'gridscale'),             cfgtopo.gridscale      = cfg.gridscale;       end
if isfield(cfg, 'interplimits'),          cfgtopo.interplimits   = cfg.interplimits;    end
if isfield(cfg, 'interpolation'),         cfgtopo.interpolation  = cfg.interpolation;   end
if isfield(cfg, 'contournum'),            cfgtopo.contournum     = cfg.contournum;      end
if isfield(cfg, 'colorbar'),              cfgtopo.colorbar       = cfg.colorbar;        end
if isfield(cfg, 'shading'),               cfgtopo.shading        =  cfg.shading';       end
cfgtopo.zparam = cfg.zparam;

% prepare the layout, this only has to be done once
cfgtopo.layout = prepare_layout(cfg, stat);

% detect 2D or 1D
is2D = isfield(stat,'time');

% add .time field to 1D data, topoplotER wants it
if ~is2D
  stat.time = 0; %doesn't matter what it is, so just choose 0
end;  

% find significant clusters
sigpos = [];
signeg = [];
haspos = isfield(stat,'posclusters');
hasneg = isfield(stat,'negclusters');

if haspos == 0 && hasneg == 0
  fprintf('%s\n','no significant clusters in data; nothing to plot')
else
  for iPos = 1:length(stat.posclusters)
    sigpos(iPos) = stat.posclusters(iPos).prob < cfg.alpha;
  end
  for iNeg = 1:length(stat.negclusters)
    signeg(iNeg) = stat.negclusters(iNeg).prob < cfg.alpha;
  end
  sigpos = find(sigpos == 1);
  signeg = find(signeg == 1);
  Nsigpos = length(sigpos);
  Nsigneg = length(signeg);
  Nsigall = Nsigpos + Nsigneg;
  
  if Nsigall == 0
    error('no clusters present with a p-value lower than the specified alpha, nothing to plot')
  end    

  % make clusterslabel matrix per significant cluster
  posCLM = squeeze(stat.posclusterslabelmat);
  sigposCLM = zeros(size(posCLM));
  probpos = [];
  for iPos = 1:length(sigpos)
    sigposCLM(:,:,iPos) = (posCLM == sigpos(iPos));
    probpos(iPos) = stat.posclusters(iPos).prob;
    hlsignpos(iPos) = prob2hlsign(probpos(iPos), cfg.highlightsymbolseries);
  end

  negCLM = squeeze(stat.negclusterslabelmat);
  signegCLM = zeros(size(negCLM));
  probneg = [];
  for iNeg = 1:length(signeg)
    signegCLM(:,:,iNeg) = (negCLM == signeg(iNeg));
    probneg(iNeg) = stat.negclusters(iNeg).prob;
    hlsignneg(iNeg) = prob2hlsign(probneg(iNeg), cfg.highlightsymbolseries);
  end

  fprintf('%s%i%s%g%s\n','There are ',Nsigall,' clusters smaller than alpha (',cfg.alpha,')')

  if is2D
    % define time window per cluster
    for iPos = 1:length(sigpos)
      possum_perclus = sum(sigposCLM(:,:,iPos),1); %sum over Chans for each timepoint
      ind_min = min(find(possum_perclus~=0));
      ind_max = max(find(possum_perclus~=0));
      time_perclus = [stat.time(ind_min) stat.time(ind_max)];
      fprintf('%s%s%s%s%s%s%s%s%s%s%s\n','Positive cluster: ',num2str(sigpos(iPos)),', pvalue: ',num2str(probpos(iPos)),' (',hlsignpos(iPos),')',', t = ',num2str(time_perclus(1)),' to ',num2str(time_perclus(2)))
    end
    for iNeg = 1:length(signeg)
      negsum_perclus = sum(signegCLM(:,:,iNeg),1);
      ind_min = min(find(negsum_perclus~=0));
      ind_max = max(find(negsum_perclus~=0));
      time_perclus = [stat.time(ind_min) stat.time(ind_max)];
      fprintf('%s%s%s%s%s%s%s%s%s%s%s\n','Negative cluster: ',num2str(signeg(iNeg)),', pvalue: ',num2str(probneg(iNeg)),' (',hlsignneg(iNeg),')',', t = ',num2str(time_perclus(1)),' to ',num2str(time_perclus(2)))
    end

    % define timewindow containing all significant clusters
    possum = sum(sigposCLM,3); %sum over Chans for timevector
    possum = sum(possum,1);
    negsum = sum(signegCLM,3);
    negsum = sum(negsum,1);
    allsum = possum + negsum;

    ind_timewin_min = min(find(allsum~=0));
    ind_timewin_max = max(find(allsum~=0));
    timewin = stat.time(ind_timewin_min:ind_timewin_max);
    
  else
    for iPos = 1:length(sigpos)
      fprintf('%s%s%s%s%s%s%s\n','Positive cluster: ',num2str(sigpos(iPos)),', pvalue: ',num2str(probpos(iPos)),' (',hlsignpos(iPos),')')
    end
    for iNeg = 1:length(signeg)
      fprintf('%s%s%s%s%s%s%s\n','Negative cluster: ',num2str(signeg(iNeg)),', pvalue: ',num2str(probneg(iNeg)),' (',hlsignneg(iNeg),')')
    end
  end
  
  % setup highlight options for all clusters and make comment for 1D data
  compos = [];
  comneg = [];
  for iPos = 1:length(sigpos)
    if stat.posclusters(sigpos(iPos)).prob < 0.01
      cfgtopo.highlight{iPos}         = cfg.highlightseries{1};
      cfgtopo.highlightsymbol{iPos}   = cfg.highlightsymbolseries(1);
      cfgtopo.highlightsize{iPos}     = cfg.highlightsizeseries(1);
    elseif stat.posclusters(sigpos(iPos)).prob < 0.05
      cfgtopo.highlight{iPos}         = cfg.highlightseries{2};
      cfgtopo.highlightsymbol{iPos}   = cfg.highlightsymbolseries(2);
      cfgtopo.highlightsize{iPos}     = cfg.highlightsizeseries(2);
    elseif stat.posclusters(sigpos(iPos)).prob < 0.1
      cfgtopo.highlight{iPos}         = cfg.highlightseries{3};
      cfgtopo.highlightsymbol{iPos}   = cfg.highlightsymbolseries(3);
      cfgtopo.highlightsize{iPos}     = cfg.highlightsizeseries(3);
    elseif stat.posclusters(sigpos(iPos)).prob < 0.2
      cfgtopo.highlight{iPos}         = cfg.highlightseries{4};
      cfgtopo.highlightsymbol{iPos}   = cfg.highlightsymbolseries(4);
      cfgtopo.highlightsize{iPos}     = cfg.highlightsizeseries(4);
    elseif stat.posclusters(sigpos(iPos)).prob < 0.3
      cfgtopo.highlight{iPos}         = cfg.highlightseries{5};
      cfgtopo.highlightsymbol{iPos}   = cfg.highlightsymbolseries(5);
      cfgtopo.highlightsize{iPos}     = cfg.highlightsizeseries(5);
    end
    cfgtopo.highlightcolor{iPos}        = cfg.highlightcolorpos;
    compos = strcat(compos,cfgtopo.highlightsymbol{iPos}, 'p=',num2str(probpos(iPos)),' '); % make comment, only used for 1D data
  end
  
  for iNeg = 1:length(signeg)
    if stat.negclusters(signeg(iNeg)).prob < 0.01
      cfgtopo.highlight{length(sigpos)+iNeg}         = cfg.highlightseries{1};
      cfgtopo.highlightsymbol{length(sigpos)+iNeg}   = cfg.highlightsymbolseries(1);
      cfgtopo.highlightsize{length(sigpos)+iNeg}     = cfg.highlightsizeseries(1);
    elseif stat.negclusters(signeg(iNeg)).prob < 0.05
      cfgtopo.highlight{length(sigpos)+iNeg}         = cfg.highlightseries{2};
      cfgtopo.highlightsymbol{length(sigpos)+iNeg}   = cfg.highlightsymbolseries(2);
      cfgtopo.highlightsize{length(sigpos)+iNeg}     = cfg.highlightsizeseries(2);
    elseif stat.negclusters(signeg(iNeg)).prob < 0.1
      cfgtopo.highlight{length(sigpos)+iNeg}         = cfg.highlightseries{3};
      cfgtopo.highlightsymbol{length(sigpos)+iNeg}   = cfg.highlightsymbolseries(3);
      cfgtopo.highlightsize{length(sigpos)+iNeg}     = cfg.highlightsizeseries(3);
    elseif stat.negclusters(signeg(iNeg)).prob < 0.2
      cfgtopo.highlight{length(sigpos)+iNeg}         = cfg.highlightseries{4};
      cfgtopo.highlightsymbol{length(sigpos)+iNeg}   = cfg.highlightsymbolseries(4);
      cfgtopo.highlightsize{length(sigpos)+iNeg}     = cfg.highlightsizeseries(4);
    elseif stat.negclusters(signeg(iNeg)).prob < 0.3
      cfgtopo.highlight{length(sigpos)+iNeg}         = cfg.highlightseries{5};
      cfgtopo.highlightsymbol{length(sigpos)+iNeg}   = cfg.highlightsymbolseries(5);
      cfgtopo.highlightsize{length(sigpos)+iNeg}     = cfg.highlightsizeseries(5);
    end 
    cfgtopo.highlightcolor{length(sigpos)+iNeg}        = cfg.highlightcolorneg;
    comneg = strcat(comneg,cfgtopo.highlightsymbol{length(sigpos)+iNeg}, 'p=',num2str(probneg(iNeg)),' '); % make comment, only used for 1D data
  end

  if is2D
    Npl = length(timewin);
  else
    Npl = 1;
  end
  Nfig = ceil(Npl/15);

  % put channel indexes in list
  if is2D
    for iPl = 1:Npl
      for iPos = 1:length(sigpos)
        list{iPl}{iPos} = find(sigposCLM(:,ind_timewin_min+iPl-1,iPos) == 1);
      end
      for iNeg = 1:length(signeg)
        list{iPl}{length(sigpos)+iNeg} = find(signegCLM(:,ind_timewin_min+iPl-1,iNeg) == 1);
      end
    end
  else
   for iPl = 1:Npl
      for iPos = 1:length(sigpos)
        list{iPl}{iPos} = find(sigposCLM(:,iPos) == 1);
      end
      for iNeg = 1:length(signeg)
        list{iPl}{length(sigpos)+iNeg} = find(signegCLM(:,iNeg) == 1);
      end
    end
  end
  
       
  % make plots
  for iPl = 1:Nfig
    figure;
    if is2D
      if iPl < Nfig
        for iT = 1:15
          PlN = (iPl-1)*15 + iT; %plotnumber
          cfgtopo.xlim = [stat.time(ind_timewin_min+PlN-1) stat.time(ind_timewin_min+PlN-1)];
          cfgtopo.highlightchannel = list{PlN};
          cfgtopo.comment = strcat('time: ',num2str(stat.time(ind_timewin_min+PlN-1)), ' s');
          cfgtopo.commentpos = 'title';
          subplot(3,5,iT);
          topoplotER(cfgtopo, stat);
        end
      elseif iPl == Nfig
        for iT = 1:Npl-(15*(Nfig-1))
          PlN = (iPl-1)*15 + iT; %plotnumber
          cfgtopo.xlim = [stat.time(ind_timewin_min+PlN-1) stat.time(ind_timewin_min+PlN-1)];
          cfgtopo.highlightchannel   = list{PlN};
          cfgtopo.comment = strcat('time: ',num2str(stat.time(ind_timewin_min+PlN-1)), ' s');
          cfgtopo.commentpos = 'title';
          subplot(3,5,iT);
          topoplotER(cfgtopo, stat);
        end
      end
    else
      cfgtopo.highlightchannel = list{1};
      cfgtopo.xparam = 'time';
      cfgtopo.yparam = '';
      cfgtopo.comment = strcat(compos,comneg);
      cfgtopo.commentpos = 'title';
      topoplotER(cfgtopo, stat);
    end
    % save figure
    if isequal(cfg.saveaspng,'no');
    else
      filename = strcat(cfg.saveaspng, '_fig', num2str(iPl));
      print(gcf,'-dpng',filename);
    end
  end
end

%% subfunctions %%
function sign = prob2hlsign(prob, hlsign)
if prob < 0.01
  sign = hlsign(1);
elseif prob < 0.05
  sign = hlsign(2);
elseif prob < 0.1
  sign = hlsign(3);
elseif prob < 0.2
  sign = hlsign(4);
elseif prob < 0.3
  sign = hlsign(5);
end
