# this is the main script, that runs the pipeline
include("functions.jl")
root_folder = "/Users/varya/Desktop/Julia/"
labels_folder = "/Users/varya/Desktop/Python/multimodal-yolo/data/results/output/labels"

# every set has two participants and four sessions
sets = ["04", "05", "06", "07", "08", "10", "11", "12"]
surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])

#Read all the Lab Streaming Layer timestamps from .xdf files and aggregate them in one table
get_all_timestamps_xdf(sets, root_folder)

#Get all the frames of interest (200 milliseconds primary to the noun onset
#check if all the april tags are recognized, if not
#get a frame with maximum april tags from 1 sec to the noun onset period

# Open a log file for writing
log_file = open("combine_fixations_by_nouns.log", "w")
# Redirect stdout to the log file
redirect_stdout(log_file) do
    @info "This is the log file of the processing of the fixations by nouns, you can find all the missing values and errors here"
    # get all the fixations for all participants I have
    all_fixations = DataFrame()
    for set in sets
        println("set $set")
        #it would be great to make time limits function arguments
        fixations = get_set_fixations_for_nouns(set)
        all_fixations = vcat(all_fixations, fixations)
    end
    CSV.write("/Users/varya/Desktop/Julia/all_fixations.csv", all_fixations)
end
close(log_file)
# get frames of interest (200 ms before the noun onset)
frames = get_frames_from_fixations(all_fixations)
#correct frame numbers according to april tags recognized
frames_corrected = check_april_tags_for_frames(frames)

#read from file if needed, CSV package cannot handle surface transformation matrices, so use TextParse
frames_corrected = CSV.read("/Users/varya/Desktop/Julia/frame_numbers_corrected_with_tokens.csv", DataFrame)
if isempty(surface_positions)
    data, surf_names = TextParse.csvread("/Users/varya/Desktop/Julia/all_surface_matrices.csv")
    surface_positions =  DataFrame()
    for (i, surf_name) in enumerate(surf_names)
        surface_positions[!, Symbol(surf_name)] = data[i]
    end
end

# get all transformation matrices for all frames in one aggregated table
#it will be written to a cvs file "all_surface_matrices.csv"
surface_positions = get_all_surface_matrices_for_frames(frames_corrected)

#Get all coordinates for all recognized objects for all frames and write them to one dataset
#it will be written to a cvs file "all_yolo_coordinates.csv"
#lables_folder is a folder with labels .txt files for tne frames woth objects recognized by Yolo
yolo_coordinates = get_all_yolo_coordinates(labels_folder)

#Read the audio transcription, select the target object mentions, tokenize all nouns (participant can call the same object with different words)
#Read all surface fixations files, clean by surface, combine into one dstaset, align timelines, filter by +- n milliseconds from target noun onset
#At the moment tjis is +- 1 sec from the word onset
all_trial_surfaces_gazes, all_trial_surfaces_fixations = get_all_gazes_and_fixations_by_frame(sets)
# Yolo may change image size deleting the black borders, so we need to check the image sizes

yolo_output_path = "/Users/varya/Desktop/Python/multimodal-yolo/data/results/output"
image_sizes = collect_image_dimensions(yolo_output_path)


#get all surfaces for all recogized objects for every frame and write the aggregated table to a csv file
#it will be written to a cvs file "all_frame_objects.csv"
#and yolo coordinates for all objects recognized in the frames are in "all_yolo_coordinates.csv"
#surface_positions is a table with all the surfaces and their positions that we have put into "all_surface_matrices.csv"
#check your recognized image sizes and correct them if needed, otherwise the coordinates will not be calculated properly
#!NB not all frames have recognized surfaces, even if all the april tags are visible
#it might be the case that there are no surfaces for 30 frames in a row (e.g. 08_01, session 3, frames 19763-1979, no surfaces recognized)
# in this case object position will be 'outside all'
all_frame_objects = get_surfaces_for_all_objects(yolo_coordinates, surface_positions, root_folder, frames_corrected, image_sizes)

#Get all the fixations for target objects only 
#(for the object called in the current noun, 1 sec before and after noun onset)

#this will not work before new rercognized frames are ready
target_gazes = DataFrame()
target_fixations = DataFrame()
for set in sets
    gazes, fixations = get_gazes_and_fixations_by_frame_and_surface(set, all_frame_objects)
    target_gazes = vcat(all_gazes, gazes)
    target_fixations = vcat(all_fixations, fixations)
end   
CSV.write("/Users/varya/Desktop/Julia/Roberts ET data/target_gazes_1sec.csv", target_gazes)
CSV.write("/Users/varya/Desktop/Julia/Roberts ET data/target_fixations_1sec.csv", target_fixations)

surface_coordinates=get_all_surfaces_for_a_frame(19787, frame_surfaces)
plot_surfaces(surface_coordinates, img_width, img_height, "/Users/varya/Desktop/Python/multimodal-yolo/data/results/output/set05_01_session2_frame_9690.jpg")


