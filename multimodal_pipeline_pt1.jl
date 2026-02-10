include("functions.jl")


function multimodal_pipeline_pt1(args)
    data_root_dir = abspath(args["data_root_dir"])
    outdir = abspath(args["outdir"])
    mkpath(outdir)
    log_dir = joinpath(outdir, "logs")
    mkpath(log_dir)
    @info "Data root: $data_root_dir"
    @info "Logs: $log_dir"
    
    # Default output if no output log file specified
    out = stdout
    
    sets = args["sets"]
    @info "Processing set(s): $(join(sets, ", "))"
    # NB: every set has two participants and four sessions

    # Read all the Lab Streaming Layer timestamps from .xdf and .json files and aggregate them in one table
    log_file = joinpath(log_dir, "timestamp_extraction_from_xdf.log")
    @info "Loading timestamps from .xdf files...\nLog file: $log_file"
    log_file = open(log_file, "w")
    timestamps_xdf = get_all_timestamps_xdf(sets, data_root_dir; out=log_file)
    write_results_csv(timestamps_xdf, outdir, "timestamps_xdf.csv", "timestamps from xdf files"; out=log_file)
    close(log_file)

    log_file = joinpath(log_dir, "timestamp_extraction_from_json.log")
    @info "Loading timestamps from .json files...\nLog file: $log_file"
    log_file = open(log_file, "w")
    timestamps_json = get_all_timestamps_json(sets, data_root_dir; out=log_file)
    write_results_csv(timestamps_json, outdir, "timestamps_ET.csv", "timestamps from json files"; out=log_file)
    close(log_file)

    log_file = joinpath(log_dir, "compute_eyetracker_lag.log")
    @info "Computing eye-tracker lag...\nLog file: $log_file"
    log_file = open(log_file, "w")
    et_lag = get_lag_ET(data_root_dir; out=log_file)
    write_results_csv(et_lag, outdir, "lag_data.csv", "eyetracker lag data"; out=log_file)
    close(log_file)

    # Get all the frames of interest (200 milliseconds prior to the noun onset)
    # Define epoch size for the fixation data, in seconds
    # epoch_start is the time before the noun onset, epoch_end is the time after the noun onset
    epoch_start, epoch_end = -1,1
    log_file = joinpath(log_dir, "combine_fixations_by_nouns.log")
    @info "Starting gaze and fixation extraction per frame...\nLog file: $log_file" epoch_start epoch_end
    log_file = open(log_file, "w")
    all_trial_surfaces_gazes, all_trial_surfaces_fixations = get_all_gazes_and_fixations_by_frame(sets, data_root_dir, epoch_start, epoch_end; out=log_file)
    write_results_csv(all_trial_surfaces_gazes, outdir, "all_trial_gazes.csv", "trial gaze data"; out=log_file)
    write_results_csv(all_trial_surfaces_fixations, outdir, "all_trial_fixations.csv", "trial fixations data"; out=log_file)
    close(log_file)

    # Get frames of interest (200 ms before noun onset)
    @info "Extracting frames of interest (200 ms before noun onset)..."
    frames = get_frames_from_fixations(all_trial_surfaces_fixations, data_root_dir)

    # Correct frame numbers according to AprilTags recognized
    # Select the frame with the maximum number of AprilTags during the period from 1 sec to the noun onset
    log_file = joinpath(log_dir, "correcting_frame_numbers.log")
    @info "Selecting optimal frames...\nLog file: $log_file"
    log_file = open(log_file, "w")
    frames_corrected = check_april_tags_for_frames(frames; out=log_file)
    write_results_csv(frames_corrected, outdir, "frame_numbers_corrected_with_tokens.csv", "corrected frame numbers"; out=log_file)
    close(log_file)
end
