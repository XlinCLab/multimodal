# multimodal

This is a collection of scripts in Julia to preprocess the multimodal data collected using Lab Streaming Layer. `Functions.jl` contains a collection of Julia functions designed for processing eye-tracking data, handling various data formats, and performing transformations. These functions are particularly tailored for working with data from the DGAME project.

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


using DataFrames
using CSV
include("/Users/varya/Desktop/Julia/functions.jl")
sets = ["04", "05", "06", "07", "08","09", "10", "11", "12"]
surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])  
# Open a log file for writing
log_file = open("combine_fixations_by_nouns.log", "w")

# Redirect stdout to the log file
redirect_stdout(log_file) do
    @info "This is the log file of the processing of the fixations by nouns, you can find all the missing values and errors here"
    # get all the fixations for all participants I have
    all_fixations = DataFrame()
    for set in sets
        println("set $set")
        fixations = get_set_fixations_for_nouns(set)
        all_fixations = vcat(all_fixations, fixations)
    end
end
close(log_file)
# Redirect back to the console
redirect_stdout(stdout)

frame_numbers = select(all_fixations, :frame_number, :participant, :session, :noun)
frame_numbers = unique!(frame_numbers)
#take only matcher videos
frame_numbers = filter(row -> endswith(row.participant, "_01"), frame_numbers)
frame_numbers.time_sec = [frame.frame_number/30 for frame in eachrow(frame_numbers)]
frame_numbers.video_path .= ""

#frame_numbers = CSV.read("/Users/varya/Desktop/Julia/frame_numbers.csv", DataFrame)
for row in eachrow(frame_numbers)
    #row=eachrow(frame_numbers)[1]
    session = lpad(row.session,2,"0")
    session = surface_sessions[session]
    row.video_path = joinpath(root_folder, "DGAME3_"*row.participant, session , "world.mp4")
end
frame_numbers= get_tokens_for_nouns(frame_numbers)
CSV.write("frame_numbers_with_tokens.csv", frame_numbers)
CSV.write("all_fixations.csv", all_fixations)

```
