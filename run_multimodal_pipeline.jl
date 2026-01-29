using ArgParse

@info "Loading environment..."
include("functions.jl")
include("multimodal_pipeline_pt1.jl")
include("multimodal_pipeline_pt2.jl")
include("multimodal_pipeline_pt3.jl")


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--data_root_dir"
            help = "Path to root directory containing DGAME data."
            required = true
        "--outdir"
            help = "Path to desired output directory. Defaults to a subdirectory 'out' of the current working directory."
            default = abspath(joinpath(".", "out"))
        "--steps"
            help = "Component processing steps to include ('1', '2', and/or '3'). By default this is set to 'all' and runs all 3 component steps."
            nargs = '+'
            default = ["ALL"]
        "--sets" 
            help = "List of set IDs to process (e.g. --sets 11 12 13). Expected to be directory labels immediately below data_root_dir. Every set has two participants and four sessions."
            nargs = '+'
        "--multimodal_yolo_path"
            help = "Path to clone of multimodal-yolo repo. Defaults to the path to this repo's multimodal-yolo submodule"
            default = abspath(joinpath(".", "multimodal-yolo"))
        "--yolo_model_path"
            help = "Path to pretrained YOLO computer vision model directory containing model.yaml and weights.pt files."
        "--yolo_results"
            help = "Path to YOLO computer vision output directory from part 2 of the pipeline."
    end

    return parse_args(s)
end


function validate_pipeline_args(args)
    # Component steps of pipeline to run
    run_steps = args["steps"]
    steps_str = join(run_steps, ", ")
    @info "Running multimodal pipeline steps: $steps_str"

    # Ensure --sets is defined if running step 1
    if "1" in run_steps || "ALL" in run_steps
        if isempty(args["sets"])
            error("--sets input argument is required for running multimodal pipeline step 1")
        end
    end

    # Data root and output directory locations
    data_root_dir = abspath(args["data_root_dir"])
    outdir = abspath(args["outdir"])
    @info "Data root: $data_root_dir"
    @info "Output directory: $outdir"

    # Locations of intermediate output files
    frames_csv = joinpath(outdir, "frame_numbers_corrected_with_tokens.csv")
    args["frames_csv"] = frames_csv
    @debug "Corrected frames CSV file: $frames_csv"

    # Path to multimodal-yolo submodule: required for step 2
    multimodal_yolo_path = abspath(args["multimodal_yolo_path"])
    if "2" in run_steps || "ALL" in run_steps
        find_multimodal_yolo(args["multimodal_yolo_path"])
        @info "Using multimodal-yolo from: $multimodal_yolo_path"
    end
    
    # Path to pretrained YOLO model: required for steps 2 and 3
    yolo_model_path = abspath(args["yolo_model_path"])
    if "2" in run_steps || "3" in run_steps || "ALL" in run_steps
        # Verify that the pretrained YOLO model and its component files exist
        if !isdir(yolo_model_path)
            error("YOLO model not found: $yolo_model_path")
        else
            pretrained_weights = joinpath(yolo_model_path, "weights.pt")
            yolo_model_yaml = joinpath(yolo_model_path, "model.yaml")
            args["yolo_model_yaml"] = yolo_model_yaml
            if !isfile(pretrained_weights) && ("2" in run_steps || "ALL" in run_steps)  # weights.pt only needed for part 2
                error("YOLO model's weights file not found: $pretrained_weights")
            elseif !isfile(yolo_model_yaml) && ("3" in run_steps || "ALL" in run_steps)  # model.yaml only needed for part 3
                error("YOLO model file not found: $yolo_model_yaml")
            end
        end
        @info "Using pretrained YOLO model: $yolo_model_path"
    end

    # YOLO results: required for step 3
    if "3" in run_steps || "ALL" in run_steps
        if args["yolo_results"] === nothing
            yolo_results = joinpath(outdir, "yolo_results")
            args["yolo_results"] = yolo_results
        end
        yolo_results = abspath(args["yolo_results"])
        @info "YOLO output directory: $yolo_results"
    end

    return args
end


function multimodal_pipeline(args)
    @info "Initializing multimodal pipeline..."
    args = validate_pipeline_args(args)
    run_steps = args["steps"]

    # MULTIMODAL PIPELINE PART 1
    if "1" in run_steps || "ALL" in run_steps
        @info "Running multimodal pipeline part 1..."
        multimodal_pipeline_pt1(args)
        @info "Completed multimodal pipeline part 1."
    else
        @info "Skipping multimodal pipeline part 1."
    end
    
    # MULTIMODAL PIPELINE PART 2 (MULTIMODAL-YOLO)
    if "2" in run_steps || "ALL" in run_steps
        @info "Running multimodal pipeline part 2 (multimodal-yolo)..."
        multimodal_pipeline_pt2(args)
        @info "Completed multimodal pipeline part 2."
    else
        @info "Skipping multimodal pipeline part 2."
    end
    
    # MULTIMODAL PIPELINE PART 3
    if "3" in run_steps || "ALL" in run_steps
        @info "Running multimodal pipeline part 3..."
        multimodal_pipeline_pt3(args)
        @info "Completed multimodal pipeline part 3."
    else
        @info "Skipping multimodal pipeline part 3."
    end

    @info "Multimodal pipeline completed successfully."
end


function main()
    args = parse_commandline()
    multimodal_pipeline(args)
end


if !isinteractive()  # required for Julia debugger entrypoint
    main()
end
