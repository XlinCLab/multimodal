using ArgParse

include("multimodal_pipeline_pt1.jl")
include("multimodal_pipeline_pt2.jl")
include("multimodal_pipeline_pt3.jl")


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--data_root_dir"
            help = "Path to root directory containing DGAME data."
        "--outdir"
            help = "Path to desired output directory. Defaults to a subdirectory 'out' of the current working directory."
            default = "./out"
        "--sets" # 
            help = "List of set IDs to process (e.g. --sets 11 12 13). Expected to be directory labels immediately below data_root_dir. Every set has two participants and four sessions."
            nargs = '+'
    end

    return parse_args(s)
end


function multimodal_pipeline(args)
    @info "Initializing multimodal pipeline..."
    data_root_dir = abspath(args["data_root_dir"])
    outdir = abspath(args["outdir"])
    frames_csv = joinpath(outdir, "frame_numbers_corrected_with_tokens.csv")
    args["frames_csv"] = frames_csv
    yolo_outdir = joinpath(outdir, "yolo_results")
    args["yolo_outdir"] = yolo_outdir
    multimodal_yolo_path = abspath(joinpath(".", "multimodal-yolo"))
    args["multimodal_yolo_path"] = multimodal_yolo_path
    labels_yaml = joinpath(multimodal_yolo_path, "data", "dataset", "data.yaml")  # TODO improve this location
    args["labels_yaml"] = labels_yaml
    @info "Data root: $data_root_dir"
    @info "Output directory: $outdir"
    @info "YOLO output directory: $yolo_outdir"

    # MULTIMODAL PIPELINE PART 1
    @info "Running multimodal pipeline part 1..."
    multimodal_pipeline_pt1(args)
    @info "Completed multimodal pipeline part 1."
    
    # MULTIMODAL PIPELINE PART 2 (MULTIMODAL-YOLO)
    @info "Running multimodal pipeline part 2 (multimodal-yolo)..."
    multimodal_pipeline_pt2(args)
    @info "Completed multimodal pipeline part 2."

    # MULTIMODAL PIPELINE PART 3
    @info "Running multimodal pipeline part 3..."
    multimodal_pipeline_pt3(args)
    @info "Completed multimodal pipeline part 3."

    @info "Multimodal pipeline completed successfully."
end


if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_commandline()
    multimodal_pipeline(args)
end
