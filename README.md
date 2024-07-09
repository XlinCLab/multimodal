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
## Functions


1. `get_json_timestamp(participant, session, root_folder="/Users/varya/Desktop/Julia/DGAME data/")`
Retrieves timestamp information from a JSON file for a specific participant and session.
   - Arguments: participant ID, session number, root folder path
   - Output: Tuple of (start_time_synced_s, duration) or empty Dict if file not found

2. `read_timestamps_from_xdf(setting::String, root_folder::String="")`
Reads timestamps from XDF files for a given setting and root folder.
   - Arguments: setting string, root folder path
   - Output: DataFrame with timestamp information for different streams

3. `get_all_timestamps_xdf(sets, root_folder="/Users/varya/Desktop/Julia/DGAME data")`
Collects all timestamps from XDF files for multiple sets.
   - Arguments: array of set numbers, root folder path
   - Output: DataFrame with all XDF timestamps and writes to CSV file

4. `get_all_timestamps_json(sets, root_folder="/Users/varya/Desktop/Julia/DGAME data")`
Retrieves all timestamps from JSON files for multiple sets.
   - Arguments: array of set numbers, root folder path
   - Output: DataFrame with all JSON timestamps and writes to CSV file

5. `get_lag_ET(reprocess="no",root_folder="/Users/varya/Desktop/Julia/DGAME data")`
Calculates the lag between eye-tracking data and other timestamps.
   - Arguments: reprocess flag, root folder path
   - Output: DataFrame with lag information between ET and XDF data

6. `get_all_yolo_coordinates(labels_folder)`
Reads surface data (fixations or gaze positions) for a specific participant and session.
   - Arguments: path to labels folder
   - Output: DataFrame with YOLO coordinates and writes to CSV file

7. `read_surfaces(participant, session, data_type = "fixations_on_surface", root_folder="")`
Combines fixation data for director and matcher participants.
   - Arguments: participant ID, session number, data type, root folder path
   - Output: DataFrame with surface data (fixations or gaze positions)

8. `get_joint_attention_fixations(set, session)`
Combines gaze position data for director and matcher participants.
   - Arguments: set number, session number
   - Output: DataFrame with combined fixation data for director and matcher

9. `get_joint_attention_gaze_positions(set, session)`
Extracts frame information from fixation data.
   - Arguments: set number, session number
   - Output: DataFrame with combined gaze position data for director and matcher

10. `get_frames_from_fixations(all_fixations)`
Retrieves and processes word annotations for a specific set and session.
    - Arguments: DataFrame of all fixations
    - Output: DataFrame with frame numbers and video paths

11. `get_and_reannotate_words(set, session, root_folder="")`
Retrieves and processes word annotations for a specific set and session.
    - Arguments: set number, session number, root folder path
    - Output: DataFrame with reannotated word data

12. `get_set_fixations_for_nouns(set::String, root_folder::String="", data_type::String = "fixations_on_surface")`
Collects fixations or gaze positions related to nouns for a given set.
    - Arguments: set number, root folder path, data type
    - Output: DataFrame with fixations or gaze positions for nouns

13. `check_april_tags_for_frames(frames)`
Verifies and adjusts frame numbers based on April tag detection.
    - Arguments: DataFrame of frames
    - Output: Updated DataFrame with corrected frame numbers

14. `get_all_surface_matrices_for_frames(frames=DataFrame())`
Retrieves surface matrices for all frames in the dataset.
    - Arguments: DataFrame of frames (optional)
    - Output: DataFrame with surface matrices for all frames

15. `get_surface_matrices(participant,session,framenumbers, root_folder="/Users/varya/Desktop/Julia/DGame data")`
Extracts surface matrices for specific frame numbers.
    - Arguments: participant ID, session number, array of frame numbers, root folder path
    - Output: DataFrame with surface matrices for specified frames

16. `parse_transformation_matrix(matrix_str)`
Parses a string representation of a transformation matrix.
    - Arguments: string representation of matrix
    - Output: 3x3 Float64 matrix

17. `transform_image_to_surface_coordinates(x, y, transform_matrix)`
Transforms image coordinates to surface coordinates.
    - Arguments: x and y coordinates, transformation matrix
    - Output: Tuple of transformed (x, y) coordinates

18. `transform_surface_to_image_coordinates(x, y, transform_matrix)`
Transforms surface coordinates to image coordinates.
    - Arguments: x and y coordinates, transformation matrix
    - Output: Tuple of transformed (x, y) coordinates

19. `transform_surface_corners(pos, matrix)`
Transforms surface corner coordinates.
    - Arguments: array of positions, transformation matrix
    - Output: Array of transformed positions

20. `read_intrinsics(file_path)`
Reads intrinsic camera parameters from a binary file.
    - Arguments: path to binary file
    - Output: Decoded MsgPack data structure

21. `get_gazes_and_fixations_by_frame_and_surface(set, surfaces_file)`
Retrieves gaze and fixation data for specific frames and surfaces.
    - Arguments: set number, DataFrame of surfaces
    - Output: Tuple of (gazes DataFrame, fixations DataFrame)

22. `get_all_gazes_and_fixations_by_frame(sets)`
Collects all gaze and fixation data for multiple sets.
    - Arguments: array of set numbers
    - Output: Tuple of (all gazes DataFrame, all fixations DataFrame)

23. `plot_surfaces(surface_coordinates)`
Visualizes surface coordinates in a plot.
    - Arguments: array of surface coordinates
    - Output: Displays a plot of the surfaces

24. `pixel_center_and_flip(x, y, img_width, img_height)`
Adjusts pixel coordinates for center and flipping.
    - Arguments: x and y coordinates, image width and height
    - Output: Tuple of adjusted (x, y) coordinates

25. `get_surfaces_for_all_objects(yolo_coordinates, surface_positions=DataFrame(), root_folder="/Users/varya/Desktop/Julia/", frames=DataFrame(), img_width = 1920, img_height = 1080)`
Maps detected objects to surfaces for all frames.
    - Arguments: YOLO coordinates, surface positions, root folder, frames, image dimensions
    - Output: DataFrame mapping objects to surfaces for all frames

26. `get_surface_for_frame_objects(frame_objects, frame_surfaces)`
 Determines which surface an object belongs to in a specific frame
    - Arguments: DataFrame of frame objects, DataFrame of frame surfaces
    - Output: Updated DataFrame of frame objects with surface assignments

These descriptions provide an overview of what each function expects as input and what it produces as output, which should help in understanding their roles within the larger project.