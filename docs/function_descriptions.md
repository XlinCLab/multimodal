#  Functions Documentation

## Functions List
- [write_results_csv](#write_results_csv)
- [pad2zero](#pad2zero)
- [get_json_timestamp](#get_json_timestamp)
- [read_timestamps_from_xdf](#read_timestamps_from_xdf)
- [get_all_timestamps_xdf](#get_all_timestamps_xdf)
- [get_all_timestamps_json](#get_all_timestamps_json)
- [get_lag_ET](#get_lag_et)
- [load_object_labels_from_yaml](#load_object_labels_from_yaml)
- [get_all_yolo_coordinates](#get_all_yolo_coordinates)
- [read_surfaces](#read_surfaces)
- [get_frames_from_fixations](#get_frames_from_fixations)
- [get_and_reannotate_words](#get_and_reannotate_words)
- [get_set_fixations_for_nouns](#get_set_fixations_for_nouns)
- [check_april_tags_for_frames](#check_april_tags_for_frames)
- [get_all_surface_matrices_for_frames](#get_all_surface_matrices_for_frames)
- [get_surface_matrices](#get_surface_matrices)
- [parse_transformation_matrix](#parse_transformation_matrix)
- [transform_surface_to_image_coordinates](#transform_surface_to_image_coordinates)
- [transform_surface_corners](#transform_surface_corners)
- [get_gazes_and_fixations_by_frame_and_surface](#get_gazes_and_fixations_by_frame_and_surface)
- [get_all_gazes_and_fixations_by_frame](#get_all_gazes_and_fixations_by_frame)
- [get_surfaces_for_all_objects](#get_surfaces_for_all_objects)
- [get_surface_for_frame_objects](#get_surface_for_frame_objects)
- [transform_yolo_to_pixels](#transform_yolo_to_pixels)
- [get_object_position_for_all_trial_fixations](#get_object_position_for_all_trial_fixations)
- [get_all_surfaces_for_a_frame](#get_all_surfaces_for_a_frame)
- [plot_surfaces](#plot_surfaces)
- [collect_image_dimensions](#collect_image_dimensions)
- [get_joint_attention_fixations](#get_joint_attention_fixations)
- [get_joint_attention_gaze_positions](#get_joint_attention_gaze_positions)
- [read_intrinsics](#read_intrinsics)

---
## write_results_csv

```julia
write_results_csv(results, dir, outcsv, label = "")
```

Writes a DataFrame of results to a specified output CSV file in a specified output directory.

### Arguments
- `results`: DataFrame
- `dir`: Output directory in which to write CSV file.
- `outcsv`: Name of CSV file to write.
- `label`: Optional. Label for data contained in results DataFrame.

### Returns
None.

### Writes
- `outcsv` within `dir` 

### Description
Writes a DataFrame of results to a specified output CSV file in a specified output directory and logs the operation.

---

## pad2zero

```julia
pad2zero(obj)
```

Pads an integer to two digits with zeroes.

### Arguments
- `obj`: Integer or string object.

### Returns
- String padded with zeroes to be minimum two characters long.

### Description
Takes an integer or string as input, and if fewer than two characters long, pads the front with zeroes, e.g. `pad2zero(3)` returns `"03"`.

---

## get_json_timestamp

```julia
get_json_timestamp(participant, session, root_folder=root_folder)
```

Retrieves the start time and duration of a session from a JSON file.

### Arguments
- `participant`: String identifier for the participant
- `session`: String identifier for the session
- `root_folder`: Optional. Root directory path

### Returns
- Tuple of (start_time_synced_s, duration)

### Description
Reads a JSON file containing session information and extracts the start time and duration.

---

## read_timestamps_from_xdf

```julia
read_timestamps_from_xdf(setting::String, root_folder::String="")
```

Reads timestamps from XDF files for a given setting.

### Arguments
- `setting`: String identifier for the setting
- `root_folder`: Optional. Root directory path

### Returns
- DataFrame containing timestamp information

### Description
Processes XDF files to extract timestamp information for audio and eye-tracking data.

---

## get_all_timestamps_xdf

```julia
get_all_timestamps_xdf(sets, root_folder=root_folder)
```

Collects timestamps from XDF files for multiple sets.

### Arguments
- `sets`: Array of set identifiers
- `root_folder`: Optional. Root directory path

### Returns
- DataFrame with combined timestamp data

### Description
Aggregates timestamp data from XDF files across multiple sets.

---

## get_all_timestamps_json

```julia
get_all_timestamps_json(sets, root_folder=root_folder)
```

Retrieves timestamps from JSON files for multiple sets.

### Arguments
- `sets`: Array of set identifiers
- `root_folder`: Optional. Root directory path

### Returns
- DataFrame with timestamp data from JSON files

### Description
Collects timestamp information from JSON files for specified sets.

---

## get_lag_ET

```julia
get_lag_ET(sets, root_folder=root_folder)
```

Calculates lag in eye-tracking data.

### Arguments
- `sets`: Array of set identifiers
- `root_folder`: Optional. Root directory path

### Returns
- DataFrame with lag information

### Description
Computes lag between XDF and JSON timestamps for eye-tracking data.

---

## load_object_labels_from_yaml

```julia
load_object_labels_from_yaml(yaml_path)
```

Creates mapping between YOLO output labels and object names/labels.

### Arguments
- `yaml_path`: Path to the YOLO model's YAML containing the object names/labels

### Returns
- Dict with object label/name and YOLO ID mapping.

### Description
Loads the object names/labels from the YOLO model's YAML file and creates mapping to YOLO output labels.

---

## get_all_yolo_coordinates

```julia
get_all_yolo_coordinates(labels_folder, yaml_path)
```

Extracts YOLO coordinates from label files.

### Arguments
- `labels_folder`: Path to the folder containing YOLO label files
- `yaml_path`: Path to the YOLO model's YAML containing the object names/labels

### Returns
- DataFrame with YOLO coordinates

### Description
Processes YOLO label files to extract object coordinates and information.

---

## read_surfaces

```julia
read_surfaces(participant, session, data_type = "fixations_on_surface", root_folder=root_folder)
```

Reads surface data for a participant's session.

### Arguments
- `participant`: String identifier for the participant
- `session`: String identifier for the session
- `data_type`: Optional. Type of data to read (default: "fixations_on_surface")
- `root_folder`: Optional. Root directory path

### Returns
- DataFrame with surface data

### Description
Extracts surface data (fixations or gaze positions) for a specific participant and session.

---

## get_frames_from_fixations

```julia
get_frames_from_fixations(all_fixations, root_folder=root_folder)
```

Filters a DataFrame of fixations to those within the relevant time window.

### Arguments
- `all_fixations`: DataFrame containing fixation data.
- `root_folder`: Optional. Root directory path

### Returns
- Filtered fixations DataFrame containing only fixations relevant time window.


### Description
Filters a DataFrame of fixations to those within the relevant time window surrounding nouns of interest.

---

## get_and_reannotate_words

```julia
get_and_reannotate_words(set, session, root_folder=root_folder)
```

Retrieves and reannotates words from audio files.

### Arguments
- `set`: String identifier for the set
- `session`: String identifier for the session
- `root_folder`: Optional. Root directory path

### Returns
- DataFrame with reannotated words

### Description
Processes audio word lists, filtering for target words and reannotating them.

---

## get_set_fixations_for_nouns

```julia
get_set_fixations_for_nouns(set::String, data_type)
```

Collects fixations or gaze positions for nouns in a set.

### Arguments
- `set`: String identifier for the set
- `data_type`: Type of data to process ("fixations_on_surface" or "gaze_positions_on_surface")
- `epoch_start`: Number of seconds prior to noun onset to define time window start.
- `epoch_end`: Number of seconds after noun onset to define time window end.

### Returns
- DataFrame with fixations or gaze positions for nouns

### Description
Aggregates fixation or gaze position data for nouns in a specific set.

---

## check_april_tags_for_frames

```julia
check_april_tags_for_frames(frames)
```

Verifies AprilTags for given frames and optimizes frame selection.

### Arguments
- `frames`: DataFrame of frames to check

### Returns
- DataFrame with updated frame numbers

### Description
Checks numbers of recognized AprilTags in each frame.
If fewer than the required number (6) are found, adjacent frames within the valid time window are checked to see if a better frame can be used instead. If so, the frame is replaced/corrected with the optimal nearby frame.

---

## get_all_surface_matrices_for_frames

```julia
get_all_surface_matrices_for_frames(frames=DataFrame())
```

Retrieves surface matrices for all frames.

### Arguments
- `frames`: DataFrame of frames
- `root_folder`: Optional. Root directory path

### Returns
- DataFrame with surface matrices for all frames

### Description
Collects surface transformation matrices for specified frames across all sets and sessions.

---

## get_surface_matrices

```julia
get_surface_matrices(participant, session, framenumbers, root_folder=root_folder)
```

Extracts surface matrices for specific frames.

### Arguments
- `participant`: String identifier for the participant
- `session`: String identifier for the session
- `framenumbers`: Array of frame numbers
- `root_folder`: Optional. Root directory path

### Returns
- DataFrame with surface matrices for specified frames

### Description
Retrieves surface transformation matrices for given frame numbers of a participant's session.

---

## parse_transformation_matrix

```julia
parse_transformation_matrix(matrix_str)
```

Parses a transformation matrix string into a 3x3 matrix.

### Arguments
- `matrix_str`: String representing a 3x3 transformation matrix.

### Returns
- Parsed 3x3 transformation matrix

### Description
Processes a string input (most likely read from file) representing a 3x3 transformation matrix and returns the parsed matrix.

---

## transform_surface_to_image_coordinates

```julia
transform_surface_to_image_coordinates(x, y, transform_matrix)
```

Converts x and y surface coordinates to coordinates in an image.

### Arguments
- `x`: Surface x coordinate
- `y`: Surface y coordinate
- `transform_matrix`: 3x3 transformation matrix

### Returns
- Tuple of transformed x and y coordinates within image

### Description
Performs a matrix transformation on x and y coordinates from a surface into coordinates within an image, given a 3x3 transformation matrix representing the conversion. 

---

## transform_surface_corners

```julia
transform_surface_corners(pos, matrix)
```

Applies a matrix transformation to a matrix of surface corner coordinates.

### Arguments
- `pos`: Matrix representing coordinates of corners of a surface.
- `transform_matrix`: 3x3 transformation matrix

### Returns
- Transformed `pos` matrix with transformed corner coordinates.

### Description
Performs a matrix transformation on a matrix containing corner coordinates (of a surface), given a 3x3 transformation matrix.

---

## get_gazes_and_fixations_by_frame_and_surface

```julia
get_gazes_and_fixations_by_frame_and_surface(all_frame_objects, all_trial_surfaces_gazes, all_trial_surfaces_fixations)
```

Combines gaze and fixation data with frame and surface information.

### Arguments
- `all_frame_objects`: DataFrame with frame object information
- `all_trial_surfaces_gazes`: DataFrame with gaze data
- `all_trial_surfaces_fixations`: DataFrame with fixation data

### Returns
- Tuple of (target_gazes, target_fixations) DataFrames

### Description
Joins gaze and fixation data with frame and surface information.

---

## get_all_gazes_and_fixations_by_frame

```julia
get_all_gazes_and_fixations_by_frame(sets, root_folder, epoch_start, epoch_end)
```

Collects all gazes and fixations for given sets.

### Arguments
- `sets`: Array of set identifiers
- `root_folder`: Root directory path
- `epoch_start`: Number of seconds prior to noun onset to define time window start.
- `epoch_end`: Number of seconds after noun onset to define time window end.

### Returns
- Tuple of (all_gazes, all_fixations) DataFrames

### Description
Aggregates gaze and fixation data across multiple sets and calculates trial times.

---

## get_surfaces_for_all_objects

```julia
get_surfaces_for_all_objects(yolo_coordinates, surface_positions, frames_corrected, image_sizes)
```

Assigns surfaces to objects for all frames.

### Arguments
- `yolo_coordinates`: DataFrame with YOLO object coordinates
- `surface_positions`: DataFrame with surface position data
- `frames_corrected`: DataFrame with corrected frame numbers
- `image_sizes`: DataFrame with image dimensions

### Returns
- DataFrame with objects and their assigned surfaces

### Description
Determines which surface each object belongs to for all frames.

---

## get_surface_for_frame_objects

```julia
get_surface_for_frame_objects(frame_objects, frame_surfaces, img_width, img_height)
```

Assigns surfaces to objects in a single frame.

### Arguments
- `frame_objects`: DataFrame with objects in the frame
- `frame_surfaces`: DataFrame with surface data for the frame
- `img_width`: Width of the image
- `img_height`: Height of the image

### Returns
- DataFrame with objects and their assigned surfaces

### Description
Determines which surface each object belongs to in a specific frame.

---

## transform_yolo_to_pixels

```julia
transform_yolo_to_pixels(x, y, w, h, img_width, img_height)
```

Transform YOLO bounding box output into pixel units for a specific image.

### Arguments
- `x`: x coordinate of bounding box center
- `y`: y coordinate of bounding box center
- `w`: width of bounding box
- `h`: height of bounding box
- `img_width`: Width of the image in pixels
- `img_height`: Height of the image in pixels

### Returns
- Tuple of `new_x`, `new_y`, `new_w`, `new_h`

### Description
Transforms YOLO bounding box coordinates to image pixel coordinates.

---

## get_object_position_for_all_trial_fixations

```julia
get_object_position_for_all_trial_fixations(all_frame_objects, all_trial_surfaces_gazes, all_trial_surfaces_fixations)
```

Combine surface information for recognized objects with gaze and fixation data.

### Arguments
- `all_frame_objects`: 
- `all_trial_surfaces_gazes`:
- `all_trial_surfaces_fixations`:

### Returns
- Tuple of `joined_fixations` and `joined_gazes` DataFrames

### Description
Combines surface positions of recognized objects in video frames with gaze and fixation data, such that the result indicates which object on which surface was fixated upon or gazed at.

---

## get_all_surfaces_for_a_frame

```julia
get_all_surfaces_for_a_frame(frame_number, set_surface_positions)
```

Get a dictionary of surface IDs and their transformed corner coordinates in a given video frame image.

### Arguments
- `frame_number`: Frame number or ID
- `set_surface_positions`: DataFrame containing world surface coordinates

### Returns
- Dict of surface IDs to transformed surface corner coordinates within an image

### Description
Get a dictionary of surface IDs and their transformed corner coordinates in a given video frame image.

---

## plot_surfaces

```julia
plot_surfaces(surface_coordinates, img_width, img_height, background_image_path)
```

Plots and displays the bounding boxes of surfaces onto a video frame image, which can be used to plot a frame if there is something suspicious going on with the surfaces.

### Arguments
- `surface_coordinates`: Dict of surface IDs to transformed surface corner coordinates within an image
- `img_width`: Width of the image in pixels
- `img_height`: Height of the image in pixels
- `background_image_path`: Path to (video frame) image

### Returns
None

### Description
Plots and displays the bounding boxes of surfaces onto a video frame image.

---

## collect_image_dimensions

```julia
collect_image_dimensions(recognized_images_folder_path::String)
```

Collects dimensions of images in a folder.

### Arguments
- `recognized_images_folder_path`: Path to the folder containing images

### Returns
- DataFrame with image dimensions

### Description
Processes images in a folder to extract their dimensions.

---

## get_joint_attention_fixations

```julia
get_joint_attention_fixations(set, session)
```

Calculates joint attention based on fixations.

### Arguments
- `set`: String identifier for the set
- `session`: String identifier for the session

### Returns
- DataFrame with joint attention fixations

### Description
Computes joint attention by joining fixation data from director and matcher.

---

## get_joint_attention_gaze_positions

```julia
get_joint_attention_gaze_positions(set, session)
```

Calculates joint attention based on gaze positions.

### Arguments
- `set`: String identifier for the set
- `session`: String identifier for the session

### Returns
- DataFrame with joint attention gaze positions

### Description
Computes joint attention by joining gaze position data from director and matcher.

---

## read_intrinsics

```julia
read_intrinsics(file_path)
```

Reads camera intrinsics from a binary file.

### Arguments
- `file_path`: Path to the binary file

### Returns
- Dictionary with camera intrinsics data

### Description
Extracts camera intrinsics information from a binary file using MsgPack.
