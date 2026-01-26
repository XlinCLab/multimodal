#  Functions Documentation

## Functions List
- [get_json_timestamp](#get_json_timestamp)
- [read_timestamps_from_xdf](#read_timestamps_from_xdf)
- [get_all_timestamps_xdf](#get_all_timestamps_xdf)
- [get_all_timestamps_json](#get_all_timestamps_json)
- [get_lag_ET](#get_lag_et)
- [get_all_yolo_coordinates](#get_all_yolo_coordinates)
- [read_surfaces](#read_surfaces)
- [get_and_reannotate_words](#get_and_reannotate_words)
- [get_set_fixations_for_nouns](#get_set_fixations_for_nouns)
- [check_april_tags_for_frames](#check_april_tags_for_frames)
- [get_all_surface_matrices_for_frames](#get_all_surface_matrices_for_frames)
- [get_surface_matrices](#get_surface_matrices)
- [get_gazes_and_fixations_by_frame_and_surface](#get_gazes_and_fixations_by_frame_and_surface)
- [get_all_gazes_and_fixations_by_frame](#get_all_gazes_and_fixations_by_frame)
- [get_surfaces_for_all_objects](#get_surfaces_for_all_objects)
- [get_surface_for_frame_objects](#get_surface_for_frame_objects)
- [collect_image_dimensions](#collect_image_dimensions)
- [get_joint_attention_fixations](#get_joint_attention_fixations)
- [get_joint_attention_gaze_positions](#get_joint_attention_gaze_positions)
- [read_intrinsics](#read_intrinsics)

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

### Writes CSV
- "timestamps_xdf.csv" in the root folder

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

### Writes CSV
- "timestamps_xdf.csv" in the root folder

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

### Writes CSV
- "timestamps_ET.csv" in the root folder

### Description
Collects timestamp information from JSON files for specified sets.

---

## get_lag_ET

```julia
get_lag_ET(sets, reprocess="no", root_folder=root_folder)
```

Calculates lag in eye-tracking data.

### Arguments
- `sets`: Array of set identifiers
- `reprocess`: Optional. Whether to reprocess data
- `root_folder`: Optional. Root directory path

### Returns
- DataFrame with lag information

### Writes CSV
- "lag_data.csv" in the root folder

### Description
Computes lag between XDF and JSON timestamps for eye-tracking data.

---

## get_all_yolo_coordinates

```julia
get_all_yolo_coordinates(labels_folder)
```

Extracts YOLO coordinates from label files.

### Arguments
- `labels_folder`: Path to the folder containing YOLO label files

### Returns
- DataFrame with YOLO coordinates

### Writes CSV
- "all_yolo_coordinates.csv" in the root folder

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

### Returns
- DataFrame with fixations or gaze positions for nouns

### Description
Aggregates fixation or gaze position data for nouns in a specific set.

---

## check_april_tags_for_frames

```julia
check_april_tags_for_frames(frames)
```

Verifies April tags for given frames.

### Arguments
- `frames`: DataFrame of frames to check

### Returns
- DataFrame with updated frame numbers

### Writes CSV
- "frame_numbers_corrected_with_tokens.csv" in the root folder

### Description
Checks and corrects frame numbers based on April tag recognition.

---

## get_all_surface_matrices_for_frames

```julia
get_all_surface_matrices_for_frames(frames=DataFrame())
```

Retrieves surface matrices for all frames.

### Arguments
- `frames`: Optional. DataFrame of frames

### Returns
- DataFrame with surface matrices for all frames

### Writes CSV
- "all_surface_matrices.csv" in the root folder

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

## get_gazes_and_fixations_by_frame_and_surface

```julia
get_gazes_and_fixations_by_frame_and_surface(all_frame_objects, all_trial_surfaces_gazes, all_trial_surfaces_fixations, gazes_file="", fixations_file="")
```

Combines gaze and fixation data with frame and surface information.

### Arguments
- `all_frame_objects`: DataFrame with frame object information
- `all_trial_surfaces_gazes`: DataFrame with gaze data
- `all_trial_surfaces_fixations`: DataFrame with fixation data
- `gazes_file`: Optional. Path to CSV file with gaze data
- `fixations_file`: Optional. Path to CSV file with fixation data

### Returns
- Tuple of (target_gazes, target_fixations) DataFrames

### Description
Joins gaze and fixation data with frame and surface information.

---

## get_all_gazes_and_fixations_by_frame

```julia
get_all_gazes_and_fixations_by_frame(sets)
```

Collects all gazes and fixations for given sets.

### Arguments
- `sets`: Array of set identifiers

### Returns
- Tuple of (all_gazes, all_fixations) DataFrames

### Writes CSVs
- "all_trial_gazes.csv" in the root folder
- "all_trial_fixations.csv" in the root folder

### Description
Aggregates gaze and fixation data across multiple sets and calculates trial times.

---

## get_surfaces_for_all_objects

```julia
get_surfaces_for_all_objects(yolo_coordinates, surface_positions, root_folder, frames_corrected, image_sizes)
```

Assigns surfaces to objects for all frames.

### Arguments
- `yolo_coordinates`: DataFrame with YOLO object coordinates
- `surface_positions`: DataFrame with surface position data
- `root_folder`: Root directory path
- `frames_corrected`: DataFrame with corrected frame numbers
- `image_sizes`: DataFrame with image dimensions

### Returns
- DataFrame with objects and their assigned surfaces

### Writes CSV
- "all_frame_objects_surfaces.csv" in the root folder

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

## collect_image_dimensions

```julia
collect_image_dimensions(recognized_images_folder_path::String)
```

Collects dimensions of images in a folder.

### Arguments
- `recognized_images_folder_path`: Path to the folder containing images

### Returns
- DataFrame with image dimensions

### Writes CSV
- "image_sizes.csv" in the root folder

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
