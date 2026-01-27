using ArgParse


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--frames_csv"
            help = "Path to CSV file containing (corrected) video frames to extract."
        "--outdir"
            help = "Path to desired output directory. Defaults to a subdirectory 'out' of the current working directory."
            default = "./out"
        "--multimodal_yolo_path"
            help = "Path to clone of multimodal-yolo repo. Defaults to the path to this repo's  multimodal-yolo submodule"
            default = abspath(joinpath(".", "multimodal-yolo"))
    end

    return parse_args(s)
end


function multimodal_pipeline_pt2(args)
    outdir = abspath(args["outdir"])
    frames_csv = abspath(args["frames_csv"])
    frames_outdir = joinpath(outdir, "frames")
    multimodal_yolo_path = abspath(args["multimodal_yolo_path"])
    multimodal_yolo_venv_python = joinpath(multimodal_yolo_path, ".venv", "bin", "python")
    frame_extraction_script = joinpath(multimodal_yolo_path, "efficient_frames_extracting.py")
    frame_extraction_cmd = `$(multimodal_yolo_venv_python) $(frame_extraction_script) --input_csv $(frames_csv) --outdir $(frames_outdir)`
    run(frame_extraction_cmd)
    yolo_detect_docker_compose = joinpath(multimodal_yolo_path, "docker-compose.detect.yml")
    # Adjust file paths in docker compose file
    run(`sed -i "s|<yourdataoutdir>|$(outdir)|g" $(yolo_detect_docker_compose)`)
    yolo_docker_cmd = `docker compose -f $(yolo_detect_docker_compose) up`
    run(yolo_docker_cmd)
    # Change back to placeholder in docker compose file
    run(`sed -i "s|$(outdir)|<yourdataoutdir>|g" $(yolo_detect_docker_compose)`)
end


if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_commandline()
    multimodal_pipeline_pt2(args)
end
