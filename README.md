# multimodal

This is a collection of scripts in Julia to preprocess the multimodal naturalistic data collected using Lab Streaming Layer and Pupil Core mobile eye-tracker. `Functions.jl` contains a collection of Julia functions designed for processing eye-tracking data, handling various data formats, and performing transformations. These functions are particularly tailored for working with data from the DGAME project. The data comes in .csv files for fixations, gazes and audio annotations, .mp4 files for video, and .xdf, .json and binaty formats for other files.

The DGAME project is a naturalistic interactive experimental setting, where two participant separated by an obstacle (a 4x4 wooden shelf) have to reorder the objects on the shelf. Objects may be unique (one signgle batter per shelf) or duplicated (two identical candles). the Director has a stack of cards with pictures of the two adjacent cells of the shelf holding objects, then they have to come up with the instructions for the Matcher to move one of the objects to match the picture. Some of the cells are closed from the side of the Director, so they cannot see all the objects. In half of the trials the Director and the Matcher cannot see the faces of each other. Every pair of participants have four sessions, 10 minutes each.

Please see the 'sample data structure DGAME. txt' for the structure of folders and files from the eye-tracker and annotations.

The object positions on the shelf annotations are done with computer vision (yolo)

The preprocessing is done in the following steps:
- Read all the Lab Streaming Layer timestamps from  .xdf files and aggregate them in one table
- Read all the eye-tracker timestamps from .json files from the eye-tracker raw data for the director and the matcher and aggregate them in one table
- Get all the frames of interest (200 milliseconds primary to the noun onset) and recognize object positions with pretrained yolo CV model.
- Get all coordinates for all recognized objects for all frames and write them to one dataset
- 
For each Director-Matcher pair, for each session:
 -   Read the audio transcription, select the target object mentions, tokenize all nouns (participant can call the same object with different words)
 -   Read all surface fixations files, clean by surface, combine into one dstaset, align timelines, filter by +- n milliseconds from target noun onset
 -   Get all the surface coordinates, perspective transform into picture pixel coordinates
 -   Get all the object coordinates from the preaggregated .csv
 -   Get all the gazes and fixations for the director and the Matcher: for target objects only, for all objects and the face of the other participant

In the last month the priority was to get everything to work, so I apologize for the lack of documentation. I am planning to get everything nicely documentd in the nearest time.

## Installation

To use the functions in this repository, ensure you have the following Julia packages installed:

```julia
using Pkg
Pkg.add("XDF")
Pkg.add("EzXML")
Pkg.add("XMLDict")
Pkg.add("JSON")
Pkg.add("LinearAlgebra")
Pkg.add("TextParse")
Pkg.add("MsgPack")
Pkg.add("CSV")
Pkg.add("DataFrames")
```

Run the pipeline: here is the script that runs the pipeline to get all fixations +- 1 sec from the noun onset, and separately target object fixations for the director and the matcher

```julia
# this is the main script, that runs the pipeline
include("functions.jl")
root_folder = "/Users/varya/Desktop/Julia/"
labels_folder = "/Users/varya/Desktop/Python/yoloo/yolo7Test/data/results/output/labels"

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

#get all surfaces for all recogized objects for every frame and write the aggregated table to a csv file
#it will be written to a cvs file "all_frame_objects.csv"
#and yolo coordinates for all objects recognized in the frames are in "all_yolo_coordinates.csv"
#surface_positions is a table with all the surfaces and their positions that we have put into "all_surface_matrices.csv"
img_width = 1920
img_height = 1080
all_frame_objects = get_surfaces_for_all_objects(yolo_coordinates, surface_positions, root_folder, frames, img_width, img_height)

#Get all the fixations for target objects only 
#(for the object called in the current noun, 1 sec before and after noun onset)
target_gazes = DataFrame()
target_fixations = DataFrame()
for set in sets
    gazes, fixations = get_gazes_and_fixations_by_frame_and_surface(set, all_frame_objects)
    target_gazes = vcat(all_gazes, gazes)
    target_fixations = vcat(all_fixations, fixations)
end   
CSV.write("/Users/varya/Desktop/Julia/Roberts ET data/target_gazes_1sec.csv", target_gazes)
CSV.write("/Users/varya/Desktop/Julia/Roberts ET data/target_fixations_1sec.csv", target_fixations)

```
## Functions
Please see the function list.md for the full documentation