# multimodal

## Table of Contents
* [Introduction](#introduction)
    * [DGAME](#dgame)
* [Setup](#setup)
    * [Submodules](#submodules)
    * [Installation](#installation)
* [Data structure](#data-structure)
* [Pipeline](#pipeline)
    * [Part 1: Data preprocessing, identification of relevant time windows, and optimal video frame selection](#part-1-data-preprocessing-identification-of-relevant-time-windows-and-optimal-video-frame-selection)
    * [Part 2: Video frame extraction and computer vision object detection](#part-2-video-frame-extraction-and-computer-vision-object-detection)
    * [Part 3: Object position detection and postprocessing](#part-3-object-position-detection-and-postprocessing)

## Introduction
This repo contains a collection of Julia scripts to preprocess multimodal, naturalistic data collected using Lab Streaming Layer and Pupil Core mobile eye-tracker.

[`functions.jl`](./functions.jl) contains a collection of Julia functions designed for processing eye-tracking data, handling various data formats, and performing transformations. These functions are specifically designed for working with data from the DGAME project (see [description below](#dgame)). [`function_descriptions.md`](./docs/function_descriptions.md) contains documentation for all functions.

### DGAME
The DGAME project is a naturalistic interactive experimental setting, where two participants separated by an obstacle (in this case, a wooden shelf with 4x4 compartments) have to reorder the objects on the shelf. Objects may be unique (e.g. only a single candle across all shelf compartments) or duplicated (e.g. two identical candles). One of the two participants, the so-called "Director", has a stack of cards depicting two adjacent shelf compartment containing objects. The Director must instruct the other participant, the so-called "Matcher", to move one of the objects in order to match the object positions in picture. Some of the shelf compartments are closed on the Director's side, so they cannot see all the objects, whereas the Matcher can see all objects in all compartments. In half of the trials the Director and the Matcher cannot see each other's faces. Each pair of participants has four sessions, 10 minutes each.

## Setup
### Submodules
This project makes use of `git` submodules. To sync and pull all updates from all submodules, use the following command
```
git submodule update --init --recursive

git submodule sync --recursive
```

Please also see the [`README` of the `multimodal-yolo` submodule](https://github.com/XlinCLab/multimodal-yolo/blob/master/README.md) in order to set up the environment for [Part 2](#part-2-video-frame-extraction-and-computer-vision-object-detection) of this pipeline. 

### Installation
If not yet installed on your machine, please first install [Julia](https://julialang.org/) by using one of the following commands or visit https://julialang.org/downloads/ for instructions.

Linux and Mac OS: 
```bash
curl -fsSL https://install.julialang.org | sh
```
Windows:
```bash
winget install --name Julia --id 9NJNWW8PVKMN -e -s msstore
```

If you use [Visual Studio Code](https://code.visualstudio.com/) as your IDE, there is an [extension](https://code.visualstudio.com/docs/languages/julia) available for Julia.

After installing Julia, you can install package dependencies by instantiating this repo as a Julia project:
- Navigate to the directory containing this repo, e.g. with `cd ..`:
```bash
~/Documents/projects/multimodal$ cd ..
~/Documents/projects$ 
```
- Start a Julia session by typing `julia` and then enter the Julia `Pkg` REPL by typing `]`, e.g.
```
~/Documents/projects$ julia
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.12.4 (2026-01-06)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org release
|__/                   |

julia> ]
```
See the [Julia documentation](https://docs.julialang.org/en/v1/stdlib/Pkg/) for more details.
- From the Julia `Pkg` REPL, activate this repo as a Julia project with the command `activate multimodal`. (NB: If you cloned this repo to something other than `multimodal`, please replace `multimodal` with that name.)
```julia
(@v1.12) pkg> activate multimodal
  Activating project at `~/Documents/projects/multimodal`
```
- Instantiate the Julia `multimodal` project with the command `instantiate`:
```
(multimodal) pkg> instantiate
```

After this you can verify the packages that are installed using the status `st` command, e.g.
```
(multimodal) pkg> st
Status `~/Documents/projects/multimodal/Project.toml`
⌃ [336ed68f] CSV v0.10.14
  [13f3f980] CairoMakie v0.15.8
⌃ [a93c6f00] DataFrames v1.6.1
⌃ [8f5d6c58] EzXML v1.2.0
⌃ [5789e2e9] FileIO v1.16.3
  [916415d5] Images v0.26.2
⌃ [682c06a0] JSON v0.21.4
  [99f44e22] MsgPack v1.2.1
⌃ [e0df1984] TextParse v1.0.2
  [31bc19ec] XDF v0.2.0
  [228000da] XMLDict v0.4.1
  [ddb6d928] YAML v0.4.16
  [37e2e46d] LinearAlgebra v1.12.0
Info Packages marked with ⌃ have new versions available and may be upgradable.
```

You can then exit the `Pkg` REPL by entering the backspace, and then exit Julia by entering `exit()`, e.g.
```
julia> exit()
```

## Data structure
Please see [`sample_DGAME_data_structure.txt`](./docs/sample_DGAME_data_structure.txt) for an example of the expected directory and file structure required as input to this pipeline. An accompanying description of the relevant files and directories can be found in [`data_structure_description.txt`](./docs/data_structure_description.txt).

Various file formats are expected and handled for different types of data, including:
- `.csv` : fixation, gaze, and audio annotation data
- `.mp4` : video data
- `.xdf` : Lab Streaming Layer timestamps
- `.json` : eye-tracker raw data and timestamps

## Pipeline
This data processing pipeline consists of three major parts.
- [Part 1](#part-1-data-preprocessing-identification-of-relevant-time-windows-and-optimal-video-frame-selection): Extract, preprocess, and combine data from various data sources (eye-tracking, timestamps, audio transcription) in order to determine time windows of interest and select corresponding video frames.
- [Part 2](#part-2-video-frame-extraction-and-computer-vision-object-detection): Extract video frames at time points of interest and use computer vision to detect objects of interest and their coordinates (submodule [`multimodal-yolo`](https://github.com/XlinCLab/multimodal-yolo/)).
- [Part 3](#part-3-object-position-detection-and-postprocessing): Detect positions of identified objects on shelf surfaces and combine with eye-tracking data.

### Part 1: Data preprocessing, identification of relevant time windows, and optimal video frame selection
- Extract Lab Streaming Layer timestamps from all `.xdf` files and aggregate them into a single dataframe.
- Extract timestamps from all raw eye-tracker `.json` files (for both the director and the matcher) and aggregate them into a single dataframe.
- Compute time lag between Lab Streaming Layer and eye-tracker timestamps in order to align timelines.
- Tokenize references to items of interest in audio transcriptions to canonical object names.
- Identify time points of interest. By default, these are 200 milliseconds prior to the onsets of (noun) tokens referring to objects of interest.
- Extract surface fixations from eye-tracker data for the time periods of interest.
- Select optimal video frame numbers at or near time points of interest where the maximum number of AprilTags was recognized.

Part 1 of the pipeline is handled by the Julia script [`main.jl`](./main.jl). Before running, ensure you enter the path your data directory as `data_root_dir`, to a desired output directory as `outdir`, and specify the relevant set IDs to be processed, e.g.:
```julia
data_root_dir = "~/Documents/projects/dgame_data/"
outdir = "./out"
sets = ["11"]  # expected to be immediately under data_root_dir
```

Run the script with the following command:
```bash
julia --project=./ main.jl
```

### Part 2: Video frame extraction and computer vision object detection
- Extract video frames of interest that were selected/identified in [Part 1](#part-1-data-preprocessing-identification-of-relevant-time-windows-and-optimal-video-frame-selection).
- (Optionally: Train a new computer vision model to detect objects of interest.)
- Perform computer vision with pretrained [`YOLO`](https://github.com/WongKinYiu/yolov7) model to detect objects of interest and their coordinates in extracted video frames.

Part 2 of the pipeline is handled by the [`multimodal-yolo`](https://github.com/XlinCLab/multimodal-yolo/) submodule. Please see the submodule's [`README`](https://github.com/XlinCLab/multimodal-yolo/blob/master/README.md) for more detailed instructions on how to run this step. The output file `frame_numbers_corrected_with_tokens.csv` from Part 1 will be required as input to Part 2. This file can be found in the output directory that was specified as `outdir` in Part 1.

### Part 3: Object position detection and postprocessing
- Perspective transform surface coordinate matrices into pixel coordinates in video frames. 
- Detect positions of objects recognized by the computer vision model in [Part 2](#part-2-video-frame-extraction-and-computer-vision-object-detection) relative to surfaces of interest.
- Combine surface positions of recognized objects with eye-tracking gaze and fixation data.

Part 3 of the pipeline is handled by the Julia script [`main_pt2.jl`](./main_pt2.jl). Before running, ensure you enter the path your data directory as `data_root_dir` and an output directory as `outdir`, as well as the paths to the `YOLO` computer vision output from Step 2 and to the `.yaml` file where the object labels/names are defined, e.g.:
```julia
data_root_dir = "~/Documents/projects/dgame_data/"
outdir = "./out"
# YOLO output paths
labels_folder = "~/Documents/projects/multimodal/multimodal-yolo/results/output/labels"
yolo_output_path = "~/Documents/projects/multimodal/multimodal-yolo/results/output"
labels_yaml = "./multimodal-yolo/data/dataset/data.yaml
```

Run the script with the following command:
```bash
julia --project=./ main_pt2.jl
```