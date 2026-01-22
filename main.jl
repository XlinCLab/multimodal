root_folder = ""
log_dir = joinpath(root_folder, "logs")
mkpath(log_dir)
@info "Data root: $root_folder"
@info "Logs: $log_dir"

# Default output if no output log file specified
out = stdout

@info "Loading environment..."
include("functions.jl")

# every set has two participants and four sessions
sets = ["04", "05", "06", "07", "08", "10", "11", "12"]
surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])

#Read all the Lab Streaming Layer timestamps from .xdf and .json files and aggregate them in one table
log_file = joinpath(root_folder, "logs", "timestamp_extraction_from_xdf.log")
@info "Loading timestamps from .xdf files...\nLog file: $log_file"
log_file = open(log_file, "w")
get_all_timestamps_xdf(sets, root_folder; out=log_file)
close(log_file)

log_file = joinpath(root_folder, "logs", "timestamp_extraction_from_json.log")
@info "Loading timestamps from .json files...\nLog file: $log_file"
log_file = open(log_file, "w")
get_all_timestamps_json(sets, root_folder; out=log_file)
close(log_file)

log_file = joinpath(root_folder, "logs", "compute_eyetracker_lag.log")
@info "Computing eye-tracker lag...\nLog file: $log_file"
log_file = open(log_file, "w")
get_lag_ET(root_folder; out=log_file)
close(log_file)

#Get all the frames of interest (200 milliseconds primary to the noun onset
#check if all the april tags are recognized, if not
# Define epoch size for the fixation data, in seconds
# epoch_start is the time before the noun onset, epoch_end is the time after the noun onset
epoch_start, epoch_end = -1,1
log_file = joinpath(root_folder, "logs", "combine_fixations_by_nouns.log")
@info "Starting gaze and fixation extraction per frame...\nLog file: $log_file" epoch_start epoch_end
log_file = open(log_file, "w")
all_trial_surfaces_gazes, all_trial_surfaces_fixations = get_all_gazes_and_fixations_by_frame(sets, epoch_start, epoch_end; out=log_file)
# Yolo may change image size deleting the black borders, so we need to check the image sizes
close(log_file)

# Get frames of interest (200 ms before noun onset)
@info "Extracting frames of interest (200 ms before noun onset)..."
frames = get_frames_from_fixations(all_trial_surfaces_fixations)

# Correct frame numbers according to april tags recognized
# Select the frame with the maximum number of april tags during the period from 1 sec to the noun onset
log_file = joinpath(root_folder, "logs", "correcting_frame_numbers.log")
@info "Selecting optimal frames...\nLog file: $log_file"
log_file = open(log_file, "w")
frames_corrected = check_april_tags_for_frames(frames; out=log_file)
close(log_file)
#read from file if needed, CSV package cannot handle surface transformation matrices, so use TextParse
#frames_corrected = CSV.read("$root_folder/frame_numbers_corrected_with_tokens.csv", DataFrame)

# Get all transformation matrices for all frames in one aggregated table
# it will be written to a CSV file "all_surface_matrices.csv"
surface_positions = get_all_surface_matrices_for_frames(frames_corrected)
#in case, you'd like to download it from file
# if isempty(surface_positions)
#     data, surf_names = TextParse.csvread(joinpath(root_folder,"all_surface_matrices.csv"))
#     surface_positions =  DataFrame()
#     for (i, surf_name) in enumerate(surf_names)
#         surface_positions[!, Symbol(surf_name)] = data[i]
#     end
# end

