using ArgParse

include("main.jl")
include("main_pt2.jl")


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
    @info "Data root: $data_root_dir"
    @info "Output directory: $outdir"
    

    # MULTIMODAL PIPELINE PART 1
    @info "Running multimodal pipeline part 1..."
    multimodal_pipeline_pt1(args)
    @info "Completed multimodal pipeline part 1."
    
    # TODO add multimodal-yolo step as separate script
    # MULTIMODAL PIPELINE PART 2 (MULTIMODAL-YOLO)
    @info "Running multimodal pipeline part 2 (multimodal-yolo)..."
    corrected_frames_csv = joinpath(outdir, "frame_numbers_corrected_with_tokens.csv")
    frames_outdir = joinpath(outdir, "frames")
    multimodal_yolo_path = joinpath(".", "multimodal-yolo")
    multimodal_yolo_venv_python = joinpath(multimodal_yolo_path, ".venv", "bin", "python")
    frame_extraction_script = joinpath(multimodal_yolo_path, "efficient_frames_extracting.py")
    frame_extraction_cmd = `$(multimodal_yolo_venv_python) $(frame_extraction_script) --input_csv $(corrected_frames_csv) --outdir $(frames_outdir)`
    run(frame_extraction_cmd)
    yolo_detect_docker_compose = joinpath(multimodal_yolo_path, "docker-compose.detect.yml")
    # Adjust file paths in docker compose file
    run(`sed -i "s|<yourdataoutdir>|$(outdir)|g" $(yolo_detect_docker_compose)`)
    yolo_docker_cmd = `docker compose -f $(yolo_detect_docker_compose) up`
    run(yolo_docker_cmd)
    # Change back to placeholder in docker compose file
    run(`sed -i "s|$(outdir)|<yourdataoutdir>|g" $(yolo_detect_docker_compose)`)

    # MULTIMODAL PIPELINE PART 3
    @info "Running multimodal pipeline part 3..."
    yolo_outdir = joinpath(outdir, "yolo_results")
    args["yolo_outdir"] = yolo_outdir
    labels_yaml = joinpath(multimodal_yolo_path, "data", "dataset", "data.yaml")  # TODO improve this
    args["labels_yaml"] = labels_yaml
    multimodal_pipeline_pt2(args)
    @info "Completed multimodal pipeline part 3."

    @info "Multimodal pipeline completed successfully."
end


if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_commandline()
    multimodal_pipeline(args)
end
