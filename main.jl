
# this is the main script, that runs the pipeline
include("functions.jl")
#indicate the defalut output for the functions, we change it for the log file for some fucnctions
out=stdout
root_folder = "/Users/varya/Desktop/Julia/DGAME data"
#these are paths to object coordinates and images, we will only get them in part two
labels_folder = "/Users/varya/Desktop/Python/multimodal-yolo/data/results/output/labels"
yolo_output_path = "/Users/varya/Desktop/Python/multimodal-yolo/data/results/output"

# every set has two participants and four sessions
sets = ["04", "05", "06", "07", "08", "10", "11", "12"]
surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])

#Read all the Lab Streaming Layer timestamps from .xdf and .json files and aggregate them in one table
get_all_timestamps_xdf(sets, root_folder)
get_all_timestamps_json(sets, root_folder)
get_lag_ET(sets, root_folder)
#Get all the frames of interest (200 milliseconds primary to the noun onset
#check if all the april tags are recognized, if not

# Here we define the epoch size for the fixation data, in seconds
# the epoch_start is the time before the noun onset, the epoch_end is the time after the noun onset
epoch_start, epoch_end = -1,1

# Open a log file for writing
log_file = open("combine_fixations_by_nouns.log", "w")
# pass the logfile into a function, it has a named parameter "out" which is by default stdout

all_trial_surfaces_gazes, all_trial_surfaces_fixations = get_all_gazes_and_fixations_by_frame(sets, epoch_start, epoch_end; out=log_file)
# Yolo may change image size deleting the black borders, so we need to check the image sizes
close(log_file)


# get frames of interest (200 ms before the noun onset)
frames = get_frames_from_fixations(all_trial_surfaces_fixations)
#correct frame numbers according to april tags recognized
#get a frame with maximum april tags from 1 sec to the noun onset period

log_file = open("correcting frame numbers.log", "w")
frames_corrected = check_april_tags_for_frames(frames; out=log_file)
close(log_file)
#read from file if needed, CSV package cannot handle surface transformation matrices, so use TextParse
#frames_corrected = CSV.read("$root_folder/frame_numbers_corrected_with_tokens.csv", DataFrame)

# get all transformation matrices for all frames in one aggregated table
#it will be written to a cvs file "all_surface_matrices.csv"
surface_positions = get_all_surface_matrices_for_frames(frames_corrected)
#in case, you'd like to download it from file
if isempty(surface_positions)
    data, surf_names = TextParse.csvread(joinpath(root_folder,"all_surface_matrices.csv"))
    surface_positions =  DataFrame()
    for (i, surf_name) in enumerate(surf_names)
        surface_positions[!, Symbol(surf_name)] = data[i]
    end
end


#Get all coordinates for all recognized objects for all frames and write them to one dataset
#it will be written to a cvs file "all_yolo_coordinates.csv"
#lables_folder is a folder with labels .txt files for tne frames woth objects recognized by Yolo
yolo_coordinates = get_all_yolo_coordinates(labels_folder)
image_sizes = collect_image_dimensions(yolo_output_path)

#uncomment the following lines if you want to load yolo_coordinates and surface positions from files that were made by the previous run
#yolo_coordinates = CSV.read(joinpath(root_folder,"all_yolo_coordinates.csv", DataFrame)
# data, surf_names = TextParse.csvread(joinpath(root_folder,"all_surface_matrices.csv")
# surface_positions =  DataFrame()
# for (i, surf_name) in enumerate(surf_names)
#     surface_positions[!, Symbol(surf_name)] = data[i]
# end
# frames_corrected = CSV.read(joinpath(root_folder,"frame_numbers_corrected_with_tokens.csv", DataFrame)
# image_sizes = CSV.read(joinpath(root_folder,"image_sizes.csv", DataFrame)


log_file = open("objects coordinates.log", "w")
all_frame_objects = get_surfaces_for_all_objects(yolo_coordinates, surface_positions, root_folder, frames_corrected, image_sizes; out=log_file)
close(log_file)
#read from file if needed
#all_frame_objects = CSV.read(joinpath(root_folder,"all_frame_objects_surfaces.csv"), DataFrame)
#all_trial_surfaces_fixations = CSV.read(joinpath(root_folder,"all_trial_fixations.csv"), DataFrame)
#all_trial_surfaces_gazes = CSV.read(joinpath(root_folder,"all_trial_gazes.csv"), DataFrame)
#now let's join this with the gazes and fixations, so we have all objects for all frames of interest
all_trial_gazes_with_objects, all_trial_fixations_with_objects = get_object_position_for_all_trial_fixations(all_frame_objects, all_trial_surfaces_gazes, all_trial_surfaces_fixations)
describe(all_trial_gazes_with_objects)
#uncomment the following line if you want to load all gazes and fixations from a file that was made by the previous run
#all_trial_surfaces_gazes_file=joinpath(root_folder,"all_trial_surfaces_gazes.csv")
#all_trial_surfaces_fixations_file=joinpath(root_folder,"all_trial_surfaces_fixations.csv")
#Uncomment if you want to load all_frame_objects from files that were made by the previous run
#all_frame_objects = CSV.read(joinpath(root_folder,"all_frame_objects_surfaces.csv"), DataFrame)

#check the join here, we need inner but with face#or add an extra column which tells where is the target object
#check where the gazes go - I have 4,5 million observtions
target_gazes, target_fixations =  get_gazes_and_fixations_by_frame_and_surface(all_frame_objects, all_trial_surfaces_gazes, all_trial_surfaces_fixations)

#this is an optional part to plot a frame if there is something suspicious going on with the surfaces
#surface_coordinates=get_all_surfaces_for_a_frame(19787, frame_surfaces)
#plot_surfaces(surface_coordinates, img_width, img_height, "/Users/varya/Desktop/Python/multimodal-yolo/data/results/output/set05_01_session2_frame_9690.jpg")

### analysis
    #fit the model
    #model = fit(MixedModel, @formula(dependant_variable ~ fixed_effects + (1|random_effects)), data)

