# multimodal

This is a collection of scripts in Julia to preprocess the multimodal naturalistic data collected using Lab Streaming Layer. `Functions.jl` contains a collection of Julia functions designed for processing eye-tracking data, handling various data formats, and performing transformations. These functions are particularly tailored for working with data from the DGAME project. The data comes in .csv files for fixations, gazes and audio annotations, .mp4 files for video, and .xdf, .json and binaty formats for other files.

The DGAME project is a naturalistic interactive experimental setting, where two participant separated by an obstacle (a 4x4 wooden shelf) have to reorder the objects on the shelf. Objects may be unique (one signgle batter per shelf) or duplicated (two identical candles). the Director has a stack of cards with pictures of the two adjacent cells of the shelf holding objects, then they have to come up with the instructions for the Matcher to move one of the objects to match the picture. Some of the cells are closed from the side of the Director, so they cannot see all the objects. In half of the trials the Director and the Matcher cannot see the faces of each other. Every pair of participants have four sessions, 10 minutes each.

The preprocessing is done in several steps, object positions on the shelf is done with computer vision (yolo)

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
Pkg.add("PrettyTables")
Pkg.add("MsgPack")
Pkg.add("CSV")
Pkg.add("DataFrames")
```

## Functions


1. read_intrinsics(file_path)

Reads binary file contents and unpacks them using the MsgPack format.

Arguments:

    •	file_path::String: Path to the binary file.

Returns:

    •	Unpacked data.

2. get_json_timestamp(participant, session, root_folder="/Users/varya/Desktop/Julia/DGAME data/")
Extracts timestamps from a JSON file for a specific participant and session.
Arguments:

    •	participant::String: Participant ID.
    •	session::String: Session ID.
    •	root_folder::String: Root folder path.
Returns:

    •	Tuple containing start_time_synced_s and duration.

3. read_surfaces(participant, session, data_type="fixations_on_surface", root_folder="/Users/varya/Desktop/Julia/DGAME data/")
Reads and processes surface data for a given participant and session.
Arguments:

    •	participant::String: Participant ID.
    •	session::String: Session ID.
    •	data_type::String: Type of data to read (default is “fixations_on_surface”).
    •	root_folder::String: Root folder path.
Returns:

    •	DataFrame containing the processed surface data.

4. get_joint_attention_fixations(set, session)
Combines fixation data for joint attention analysis.
Arguments:

    •	set::String: Set ID.
    •	session::String: Session ID.
Returns:

    •	DataFrame with joint attention fixations.

5. get_joint_attention_gaze_positions(set, session)
Combines gaze position data for joint attention analysis.
Arguments:

    •	set::String: Set ID.
    •	session::String: Session ID.
Returns:

    •	DataFrame with joint attention gaze positions.

6. get_and_reannotate_words(set, session, root_folder="/Users/varya/Desktop/Julia/Roberts ET data/Dyaden_Analyse")
Reannotates and retrieves words from audio data for a given set and session.
Arguments:

    •	set::String: Set ID.
    •	session::String: Session ID.
    •	root_folder::String: Root folder path.
Returns:

    •	DataFrame with reannotated words.

7. get_all_surface_coordinates_for_frames(frames=DataFrame())
Retrieves all surface coordinates for specified frames.
Arguments:

    •	frames::DataFrame: DataFrame containing frame information.
Returns:

    •	DataFrame with all surface coordinates.

8. get_surface_coordinates(participant, session, framenumbers, root_folder="/Users/varya/Desktop/Julia/DGame data")
Gets surface coordinates for specific frames.
Arguments:

    •	participant::String: Participant ID.
    •	session::String: Session ID.
    •	framenumbers::Vector{Int}: Frame numbers.
    •	root_folder::String: Root folder path.
Returns:

    •	DataFrame with surface coordinates.

9. get_set_fixations_for_nouns(set)
Retrieves fixations for nouns within a specific set.
Arguments:

    •	set::String: Set ID.
Returns:

    •	DataFrame with fixations for nouns.

10. read_timestamps_from_xdf(setting::String, root_folder::String="/Users/varya/Desktop/Julia/DGAME data/xdf")
Reads timestamps from XDF files.
Arguments:

    •	setting::String: Setting ID.
    •	root_folder::String: Root folder path.
Returns:

    •	DataFrame with timestamps.

11. get_all_timestamps_xdf(sets, root_folder="/Users/varya/Desktop/Julia/DGAME data")
Retrieves all timestamps from XDF files for specified sets.
Arguments:

    •	sets::Vector{String}: Vector of set IDs.
    •	root_folder::String: Root folder path.
Returns:

    •	DataFrame with all timestamps from XDF files.

12. get_all_timestamps_json(sets, root_folder="/Users/varya/Desktop/Julia/DGAME data")
Retrieves all timestamps from JSON files for specified sets.
Arguments:

    •	sets::Vector{String}: Vector of set IDs.
    •	root_folder::String: Root folder path.
Returns:

    •	DataFrame with all timestamps from JSON files.

13. get_lag_ET(reprocess="no", root_folder="/Users/varya/Desktop/Julia/DGAME data")
Calculates the lag between timestamps in JSON and XDF files.
Arguments:

    •	reprocess::String: Flag to reprocess data (default is “no”).
    •	root_folder::String: Root folder path.
Returns:

    •	DataFrame with lag data.

14. get_tokens_for_nouns(words=DataFrame(), root_folder="/Users/varya/Desktop/Julia/Roberts ET data/Dyaden_Analyse")
Maps nouns to tokens.
Arguments:

    •	words::DataFrame: DataFrame containing words.
    •	root_folder::String: Root folder path.
Returns:

    •	DataFrame with mapped tokens.

15. yolo_to_pixel_center(x, y, img_width, img_height)
Converts YOLO bounding box center coordinates to pixel coordinates.
Arguments:

    •	x::Float64: Normalized x-coordinate.
    •	y::Float64: Normalized y-coordinate.
    •	img_width::Int: Image width.
    •	img_height::Int: Image height.
Returns:

    •	Tuple containing pixel coordinates (x_pixel, y_pixel).

16. yolo_to_normalized_ET(x, y)
Converts YOLO coordinates to normalized eye-tracking coordinates.
Arguments:

    •	x::Float64: Normalized x-coordinate.
    •	y::Float64: Normalized y-coordinate.
Returns:

    •	Tuple containing normalized coordinates (x_norm, y_norm).

17. transform_image_to_surface_coordinates(x, y, transform_matrix)
Transforms image coordinates to surface coordinates.
Arguments:

    •	x::Float64: x-coordinate.
    •	y::Float64: y-coordinate.
    •	transform_matrix::Matrix{Float64}: Transformation matrix.
Returns:

    •	Tuple containing transformed coordinates (x_surf, y_surf).

18. transform_surface_to_image_coordinates(x, y, transform_matrix)
Transforms surface coordinates to image coordinates.
Arguments:

    •	x::Float64: x-coordinate.
    •	y::Float64: y-coordinate.
    •	transform_matrix::Matrix{Float64}: Transformation matrix.
Returns:

    •	Tuple containing transformed coordinates (x_img, y_img).

19. parse_transformation_matrix(matrix_str)
Parses a transformation matrix from a string.
Arguments:

    •	matrix_str::String: String representation of the matrix.
Returns:

    •	Matrix of type Matrix{Float64}.

20. get_all_yolo_coordinates(labels_folder)
Reads YOLO object detection labels and compiles them into a DataFrame.
Arguments:

    •	labels_folder::String: Path to the folder containing YOLO label files.
Returns:

    •	DataFrame with YOLO coordinates.

Example Usage

Here is an example of how to use some of the functions in your script:

```julia
#get_fixations_for_words
# this is the main script, that runs the pipeline
include("functions.jl")
root_folder = "/Users/varya/Desktop/Julia/"

# every set has two participants and four sessions
sets = ["04", "05", "06", "07", "08", "10", "11", "12"]

#Read all the Lab Streaming Layer timestamps from .xdf files and aggregate them in one table
get_all_timestamps_from_xdf(sets, root_folder)
#Read all the eye-tracker timestamps from .json files from the eye-tracker raw data for the director and the matcher and aggregate them in one table
get_all_timestamps_json(sets, root_folder)

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
end
close(log_file)
# get frames of interest (200 ms before the noun onset)
frames = get_frames_from_fixations(all_fixations)
#correct frame numbers according to april tags recognized
frames_corrected = check_april_tags_for_frames(frames)

# get all transformation matrices for all frames in one aggregated table
#it will be written to a cvs file "all_surface_matrices.csv"
surface_positions = get_all_surface_matrices_for_frames(frames)

#Get all coordinates for all recognized objects for all frames and write them to one dataset
#it will be written to a cvs file "all_yolo_coordinates.csv"
#lables_folder is a folder with labels .txt files for tne frames woth objects recognized by Yolo
yolo_coordinates = get_all_yolo_coordinates(labels_folder)

#Read the audio transcription, select the target object mentions, tokenize all nouns (participant can call the same object with different words)
#Read all surface fixations files, clean by surface, combine into one dstaset, align timelines, filter by +- n milliseconds from target noun onset
#At the moment tjis is +- 1 sec from the word onset
all_surfaces_gazes, all_surfaces_fixations = get_all_gazes_and_fixations_by_frame(sets)

#get all surfaces for all recogized objects for every frame and write the aggregated table to a csv file
#it will be written to a cvs file "all_frame_objects.csv"
#and yolo coordinates for all objects recognized in the frames are in "all_yolo_coordinates.csv"
#surface_positions is a table with all the surfaces and their positions that we have put into "all_surface_matrices.csv"
img_width = 1920
img_height = 1080
all_frame_objects = get_surfaces_for_all_objects(yolo_coordinates, surface_positions, root_folder, frames, img_width, img_height)

#Get all the fixations for target objects only 
#(for the object called in the current noun, 1 sec before and after noun onset)
all_gazes = DataFrame()
all_fixations = DataFrame()
for set in sets
    gazes, fixations = get_gazes_and_fixations_by_frame_and_surface(set, all_frame_objects)
    all_gazes = vcat(all_gazes, gazes)
    all_fixations = vcat(all_fixations, fixations)
end   
CSV.write("/Users/varya/Desktop/Julia/Roberts ET data/all_gazes_1sec.csv", all_gazes)
CSV.write("/Users/varya/Desktop/Julia/Roberts ET data/all_fixations_1sec.csv", all_fixations)



```
