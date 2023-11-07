% TIME SHUFFLE  
% Disrupts temporal domain.
% INPUT - 
    % num_shuffles: integer
    % thresholded_decoded_thetaSeq_option: 1 if using theta sequences that have passed the position threshold (not happening neither at the
    % start or end of track)

function time_shuffle = average_theta_sequences_timebins_shuffle(num_shuffles,thresholded_decoded_thetaSeq_option)

parameters = list_of_parameters;
cd([pwd '\Theta'])
if thresholded_decoded_thetaSeq_option == 1
    load theta_sequence_quantification_thresholded.mat
else
    load theta_sequence_quantification.mat
end
cd ..

fields = fieldnames(centered_averaged_thetaSeq);
num_tracks = length(centered_averaged_thetaSeq.direction1);
for d = 1 : length(fields)
    for t = 1 : num_tracks
        decoded_sequences.(strcat(fields{d}))(t).mean_relative_position = centered_averaged_thetaSeq.direction2(t).mean_relative_position;
    end
end

% Find number of cores available 
p = gcp; % Starting parallel pool
if isempty(p)
    num_cores = 0;
else
    num_cores = p.NumWorkers; 
end
loops = ceil(num_shuffles/num_cores);

% Run shuffles
parfor jj = 1 : num_cores
    [out{jj}.shuffled_thetaseq,out2{jj}] = run_time_bin_shuffles(num_shuffles,loops,decoded_sequences);
end

%time_bin_shuffles = matrix_shuffles;
for d = 1 : length(fields)    
    for t = 1 : num_tracks
        cellArray1 = cellfun(@(x) x.(strcat(fields{d}))(t).mean_relative_position, out2,'UniformOutput',0)';
        time_bin_shuffles.(strcat(fields{d}))(t).mean_relative_position = vertcat(cellArray1{:});
        time_bin_shuffles.(strcat(fields{d}))(t).mean_relative_position = time_bin_shuffles.(strcat(fields{d}))(t).mean_relative_position(1:num_shuffles,:);
    end
end
    
% Save in final structure
for d = 1 : length(fields)
    for j = 1 : num_tracks
        for jj = 1 : num_cores
            num_col = size(out{jj}.shuffled_thetaseq.(strcat(fields{d}))(j).quadrant_ratio,2);
            if jj == 1
                time_shuffle.(strcat(fields{d}))(j).quadrant_ratio(:,(jj:num_col)) = out{jj}.shuffled_thetaseq.(strcat(fields{d}))(j).quadrant_ratio;
                time_shuffle.(strcat(fields{d}))(j).weighted_corr(:,(jj:num_col)) = out{jj}.shuffled_thetaseq.(strcat(fields{d}))(j).weighted_corr;
                time_shuffle.(strcat(fields{d}))(j).linear_score(:,(jj:num_col)) = out{jj}.shuffled_thetaseq.(strcat(fields{d}))(j).linear_score;
            else
                time_shuffle.(strcat(fields{d}))(j).quadrant_ratio(:,((jj-1)*num_col+1:jj*num_col)) = out{jj}.shuffled_thetaseq.(strcat(fields{d}))(j).quadrant_ratio;
                time_shuffle.(strcat(fields{d}))(j).weighted_corr(:,((jj-1)*num_col+1:jj*num_col)) = out{jj}.shuffled_thetaseq.(strcat(fields{d}))(j).weighted_corr;
                time_shuffle.(strcat(fields{d}))(j).linear_score(:,((jj-1)*num_col+1:jj*num_col)) = out{jj}.shuffled_thetaseq.(strcat(fields{d}))(j).linear_score;
            end
        end
    end
end

cd([pwd '\Theta'])
if thresholded_decoded_thetaSeq_option == 1
    save averaged_thetaSeq_time_shuffle_thresholded time_shuffle
    save shuffles_theta_sequences_thresholded time_bin_shuffles
else
    save averaged_thetaSeq_time_shuffle time_shuffle
    save shuffles_theta_sequences time_bin_shuffles
end
cd ..

end


function [all_shuffles,matrix_shuffles] = run_time_bin_shuffles(num_shuffles,loops,decoded_sequences)


    parameters = list_of_parameters;

    fields = fieldnames(decoded_sequences);
    num_tracks = length(decoded_sequences.direction1);
    
    % creates template structure to save all position shuffles
    for d = 1 : length(fields)
        for t = 1 : num_tracks
            all_shuffles.(strcat(fields{d}))(t).quadrant_ratio = zeros(1,loops);
            all_shuffles.(strcat(fields{d}))(t).weighted_corr= zeros(1,loops);
            all_shuffles.(strcat(fields{d}))(t).linear_score = zeros(1,loops);
        end
    end
    
    % preallocate
    for t = 1 : num_tracks
        matrix_shuffles.direction1(t).mean_relative_position = repmat(cellfun(@(x) NaN(size(x)), {decoded_sequences.direction1(t).mean_relative_position},'UniformOutput',0),loops,1);
        matrix_shuffles.direction2(t).mean_relative_position = repmat(cellfun(@(x) NaN(size(x)), {decoded_sequences.direction2(t).mean_relative_position},'UniformOutput',0),loops,1);
        matrix_shuffles.unidirectional(t).mean_relative_position = repmat(cellfun(@(x) NaN(size(x)), {decoded_sequences.unidirectional(t).mean_relative_position},'UniformOutput',0),loops,1);
    end

    %all_shuffles.shuffled_thetaseq = shuffled_thetaseq;
    %matrix_shuffles = time_bin_shuffles;

    for s = 1 : loops
        
        shuffled_struct = decoded_sequences;
        
        % For each shuffle, creates a new structure where the time bins in each decoded event have been shuffled
        for d = 1 : length(fields)
            for j = 1 : num_tracks
                matrix_size = size(decoded_sequences.(strcat(fields{d}))(j).mean_relative_position);
                shuffled_struct.(strcat(fields{d}))(j).mean_relative_position= shuffled_struct.(strcat(fields{d}))(j).mean_relative_position(:,randperm(matrix_size(2)));
            end
        end
        
        % keep shuffled theta window matrices
        for t = 1 : num_tracks
            matrix_shuffles.direction1(t).mean_relative_position{s} = shuffled_struct.direction1(t).mean_relative_position;
            matrix_shuffles.direction2(t).mean_relative_position{s} = shuffled_struct.direction2(t).mean_relative_position;
            matrix_shuffles.unidirectional(t).mean_relative_position{s} = shuffled_struct.unidirectional(t).mean_relative_position;
        end
        %(loops*(jj-1))+s
        
        %%%% For each new shuffled structure, runs quantification methods
        
        % Quadrant Ratio
        centered_averaged_thetaSeq = quadrant_ratio_shuffle(shuffled_struct); %quadrant_ratio_shuffle
        
        % Weighted correlation
        for d = 1 : length(fields) %for each direction
            thetaseq = centered_averaged_thetaSeq.(strcat(fields{d}));
            for t = 1 : num_tracks % for each track
                central_cycle = thetaseq(t).central_sequence;
                centered_averaged_thetaSeq.(strcat(fields{d}))(t).weighted_corr = weighted_correlation(central_cycle);
            end
        end
        
        % Line fitting
        time_bins_length = size(centered_averaged_thetaSeq.direction1(1).central_sequence,2); % all matrices should have the same size
        [all_tstLn,spd2Test]= construct_all_lines(time_bins_length);
        
        for d = 1 : length(fields) % for each direction
            thetaseq = centered_averaged_thetaSeq.(strcat(fields{d}));
            for t = 1 : length(thetaseq) % for each track
                central_cycle = thetaseq(t).central_sequence;
                [centered_averaged_thetaSeq.(strcat(fields{d}))(t).linear_score,~,~] = line_fitting2(central_cycle,all_tstLn(size(central_cycle,2)==time_bins_length),spd2Test);
            end
        end
        
        % Adds the scoring results of each shuffle to the same structure
        for d = 1 : length(fields)
            for j = 1 : num_tracks
                all_shuffles.(strcat(fields{d}))(j).quadrant_ratio(s) = centered_averaged_thetaSeq.(strcat(fields{d}))(j).quadrant_ratio;
                all_shuffles.(strcat(fields{d}))(j).weighted_corr(s) = centered_averaged_thetaSeq.(strcat(fields{d}))(j).weighted_corr;
                all_shuffles.(strcat(fields{d}))(j).linear_score(s) = centered_averaged_thetaSeq.(strcat(fields{d}))(j).linear_score;
            end
        end
        
    end
end