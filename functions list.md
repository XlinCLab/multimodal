### Documentation for Functions in `functions.jl`

#### 1. `get_json_timestamp`

- **Description**: Extracts the start time and duration from a JSON file.
- **Input**:
  - `participant::String`: Participant ID.
  - `session::String`: Session ID.
  - `root_folder::String` (optional): Root folder containing the data.
- **Output**:
  - `(start_time_synced_s::Float64, duration::Float64)`: Tuple containing the start time and duration.
- **Functionality**: Reads the `info.player.json` file, extracts `start_time_synced_s` and `duration_s`.

#### 2. `read_timestamps_from_xdf`

- **Description**: Reads timestamps from XDF files and aggregates them.
- **Input**:
  - `setting::String`: Setting identifier.
  - `root_folder::String` (optional): Root folder containing the XDF data.
- **Output**:
  - `timestamps::DataFrame`: DataFrame with aggregated timestamps.
- **Functionality**: Reads XDF files, extracts and processes timestamps for audio and pupil capture streams.

#### 3. `get_all_timestamps_xdf`

- **Description**: Aggregates all XDF timestamps for a set of settings.
- **Input**:
  - `sets::Vector{String}`: List of settings.
  - `root_folder::String`: Root folder for storing the CSV output.
- **Output**:
  - `timestamps_xdf::DataFrame`: DataFrame with all aggregated timestamps.
- **Functionality**: Combines timestamps from multiple settings, converts them to milliseconds, and writes to a CSV file.

#### 4. `get_all_timestamps_json`

- **Description**: Aggregates all JSON timestamps for a set of settings.
- **Input**:
  - `sets::Vector{String}`: List of settings.
  - `root_folder::String` (optional): Root folder for storing the CSV output.
- **Output**:
  - `timestamps_json::DataFrame`: DataFrame with all aggregated timestamps.
- **Functionality**: Combines timestamps from multiple settings, converts them to milliseconds, and writes to a CSV file.

#### 5. `get_lag_ET`

- **Description**: Calculates the lag between timestamps from XDF and JSON files.
- **Input**:
  - `reprocess::String` (optional): Flag to reprocess data.
  - `root_folder::String` (optional): Root folder containing the data.
- **Output**:
  - `lag::DataFrame`: DataFrame with calculated lags.
- **Functionality**: Reads and processes timestamps, calculates lags, and writes to a CSV file.

#### 6. `get_all_yolo_coordinates`

- **Description**: Reads YOLO coordinates from label files and aggregates them.
- **Input**:
  - `labels_folder::String`: Folder containing YOLO label files.
- **Output**:
  - `all_yolo_coordinates::DataFrame`: DataFrame with all YOLO coordinates.
- **Functionality**: Reads YOLO label files, processes coordinates, and writes to a CSV file.

#### 7. `read_surfaces`

- **Description**: Reads surface data for a given participant and session.
- **Input**:
  - `participant::String`: Participant ID.
  - `session::String`: Session ID.
  - `data_type::String` (optional): Type of data (default is `fixations_on_surface`).
  - `root_folder::String` (optional): Root folder containing the data.
- **Output**:
  - `fixations_positions::DataFrame`: DataFrame with surface data.
- **Functionality**: Reads surface data files, processes timestamps and coordinates, and returns the data.

#### 8. `get_joint_attention_fixations`

- **Description**: Extracts joint attention fixations for a given set and session.
- **Input**:
  - `set::String`: Set identifier.
  - `session::String`: Session identifier.
- **Output**:
  - `joint_attention::DataFrame`: DataFrame with joint attention fixations.
- **Functionality**: Reads surface data for director and matcher, and identifies joint attention fixations.

#### 9. `get_joint_attention_gaze_positions`

- **Description**: Extracts joint attention gaze positions for a given set and session.
- **Input**:
  - `set::String`: Set identifier.
  - `session::String`: Session identifier.
- **Output**:
  - `joint_attention::DataFrame`: DataFrame with joint attention gaze positions.
- **Functionality**: Reads gaze position data for director and matcher, and identifies joint attention gaze positions.

#### 10. `get_frames_from_fixations`

- **Description**: Extracts frame numbers from fixation data.
- **Input**:
  - `all_fixations::DataFrame`: DataFrame with all fixations.
- **Output**:
  - `frame_numbers::DataFrame`: DataFrame with frame numbers.
- **Functionality**: Processes fixation data to extract unique frame numbers.

#### 11. `get_and_reannotate_words`

- **Description**: Reads and reannotates words from audio files.
- **Input**:
  - `set::String`: Set identifier.
  - `session::String`: Session identifier.
  - `root_folder::String` (optional): Root folder containing the data.
- **Output**:
  - `target_words::DataFrame`: DataFrame with reannotated words.
- **Functionality**: Reads word list files, processes and reannotates words, and returns the data.

#### 12. `get_set_fixations_for_nouns`

- **Description**: Extracts fixations for nouns within a given set and session.
- **Input**:
  - `set::String`: Set identifier.
  - `root_folder::String` (optional): Root folder containing the data.
  - `data_type::String` (optional): Type of data (default is `fixations_on_surface`).
- **Output**:
  - `fixations_for_set::DataFrame`: DataFrame with fixations for nouns.
- **Functionality**: Reads fixation data and word list files, processes and combines the data, and returns fixations for nouns.

#### 13. `check_april_tags_for_frames`

- **Description**: Checks April tags for frames and corrects frame numbers.
- **Input**:
  - `frames::DataFrame`: DataFrame with frame numbers.
- **Output**:
  - `frames::DataFrame`: DataFrame with corrected frame numbers.
- **Functionality**: Reads surface data, checks and corrects frame numbers based on April tag detections, and writes to a CSV file.

#### 14. `get_all_surface_matrices_for_frames`

- **Description**: Extracts surface matrices for all frames.
- **Input**:
  - `frames::DataFrame` (optional): DataFrame with frame numbers.
- **Output**:
  - `all_surface_coordinates::DataFrame`: DataFrame with all surface matrices.
- **Functionality**: Reads frame numbers, processes surface data, and writes to a CSV file.

#### 15. `get_surface_matrices`

- **Description**: Extracts surface matrices for a given participant and session.
- **Input**:
  - `participant::String`: Participant ID.
  - `session::String`: Session ID.
  - `framenumbers::Vector{Int}`: List of frame numbers.
  - `root_folder::String` (optional): Root folder containing the data.
- **Output**:
  - `surface_coordinates::DataFrame`: DataFrame with surface matrices.
- **Functionality**: Reads surface data files, processes matrices, and returns the data.

#### 16. `parse_transformation_matrix`

- **Description**: Parses a transformation matrix from a string.
- **Input**:
  - `matrix_str::String`: String representation of a matrix.
- **Output**:
  - `matrix::Matrix{Float64}`: Parsed 3x3 transformation matrix.
- **Functionality**: Parses a string to extract and reshape it into a transformation matrix.

#### 17. `transform_image_to_surface_coordinates`

- **Description**: Transforms image coordinates to surface coordinates.
- **Input**:
  - `x::Float64`: X coordinate.
  - `y::Float64`: Y coordinate.
  - `transform_matrix::Matrix{Float64}`: Transformation matrix.
- **Output**:
  - `(new_x::Float64, new_y::Float64)`: Transformed coordinates.
- **Functionality**: Applies a transformation matrix to convert image coordinates to surface coordinates.

#### 18. `transform_surface_to_image_coordinates`

- **Description**: Transforms surface coordinates to image coordinates.
- **Input**:
  - `x::Float64`: X coordinate.
  - `y::Float64`: Y coordinate.
  - `transform_matrix::Matrix{Float64}`: Transformation matrix.
- **Output**:
  - `(new_x::Float64, new_y::Float64)`: Transformed coordinates.
- **Functionality**: Applies a transformation matrix to convert surface coordinates to image coordinates.

#### 19. `transform_surface_corners`

- **Description**: Transforms surface corners using a transformation matrix.
- **Input**:
  - `pos::Matrix{Float64}`: Positions matrix.
  - `matrix::Matrix{Float64}`: Transformation matrix.
- **Output**:
  - `new_pos::Matrix{Float64}`: Transformed positions.
- **Functionality**: Applies a transformation matrix to transform surface corners.

#### 20. `read_intrinsics`

- **Description**: Reads intrinsic parameters from a file.
- **Input**:
  - `file_path::String`: Path to the file.
- **Output**:
  - `data::Dict`: Dictionary with intrinsic parameters.
- **Functionality**: Reads and unpacks intrinsic parameters from a binary file.

#### 21. `get_gazes_and_fixations_by_frame_and_surface`

- **Description**: Extracts gazes and fixations for frames and surfaces.
- **Input**:
  - `set::String`: Set identifier.
  - `surfaces_file::DataFrame`: DataFrame with surface information.
- **Output**:
  - `(gazes::DataFrame, fixations::DataFrame)`: DataFrames with gazes and fixations.
- **Functionality**: Reads and processes gaze and fixation data, matching it with surfaces information.

#### 22. `get_all_gazes_and_fixations_by_frame`

- **Description**: Extracts all gazes and fixations for multiple sets.
- **Input**:
  - `sets::Vector{String}`: List of sets.
- **Output**:
  - `(all_gazes::DataFrame, all_fixations::DataFrame)`: DataFrames with all gazes and fixations.
- **Functionality**: Reads and processes gaze and fixation data for multiple sets, and returns the combined data.

#### 23. `plot_surfaces`

- **Description**: Plots surface data.
- **Input**:
  - `surface_coordinates::DataFrame`: DataFrame with surface coordinates.
- **Output**:
  - `fig::Figure`: Plot figure.
- **Functionality**: Plots surfaces with their corners on a 2D plane.

#### 24. `pixel_center_and_flip`

- **Description**: Centers and flips image coordinates.
- **Input**:
  - `x::Float64`: X coordinate.
  - `y::Float64`: Y coordinate.
  - `img_width::Int`: Image width.
  - `img_height::Int`: Image height.
- **Output**:
  - `(new_x::Float64, new_y::Float64)`: Transformed coordinates.
- **Functionality**: Flips image coordinates horizontally and vertically.

#### 25. `get_surfaces_for_all_objects`

- **Description**: Maps objects to surfaces for all frames.
- **Input**:
  - `yolo_coordinates::DataFrame`: DataFrame with YOLO coordinates.
  - `surface_positions::DataFrame`: DataFrame with surface positions.
  - `root_folder::String`: Root folder containing the data.
  - `frames_corrected::DataFrame`: DataFrame with corrected frame numbers.
  - `img_width::Int`: Image width.
  - `img_height::Int`: Image height.
- **Output**:
  - `all_frame_objects::DataFrame`: DataFrame with mapped objects and surfaces.
- **Functionality**: Reads and processes YOLO and surface data, maps objects to surfaces, and writes to a CSV file.

#### 26. `get_surface_for_frame_objects`

- **Description**: Maps objects to surfaces for a specific frame.
- **Input**:
  - `frame_objects::DataFrame`: DataFrame with frame objects.
  - `frame_surfaces::DataFrame`: DataFrame with frame surfaces.
  - `img_width::Int`: Image width.
  - `img_height::Int`: Image height.
- **Output**:
  - `frame_objects::DataFrame`: DataFrame with mapped objects and surfaces.
- **Functionality**: Checks if objects are inside surfaces and maps them accordingly.

#### 27. `transform_yolo_to_pixels`

- **Description**: Transforms YOLO coordinates to pixel coordinates.
- **Input**:
  - `x::Float64`: X coordinate.
  - `y::Float64`: Y coordinate.
  - `w::Float64`: Width.
  - `h::Float64`: Height.
  - `img_width::Int`: Image width.
  - `img_height::Int`: Image height.
- **Output**:
  - `(new_x::Float64, new_y::Float64, new_w::Float64, new_h::Float64)`: Transformed coordinates.
- **Functionality**: Converts normalized YOLO coordinates to pixel coordinates.

#### 28. `print_folder_structure`

- **Description**: Prints the folder structure of a given path.
- **Input**:
  - `path::String`: Path to the directory.
  - `indent::String` (optional): Indentation for nested directories.
- **Output**:
  - `None`
- **Functionality**: Recursively prints the directory and file structure.