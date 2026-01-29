function multimodal_pipeline_pt2(args)
    outdir = abspath(args["outdir"])
    frames_csv = abspath(args["frames_csv"])
    
    # Find location of multimodal-yolo and its Python environment
    multimodal_yolo_path = abspath(args["multimodal_yolo_path"])
    isdir
    if !isdir(multimodal_yolo_path)
        error("multimodal-yolo not found: $multimodal_yolo_path")
    end
    multimodal_yolo_venv_python = joinpath(multimodal_yolo_path, ".venv", "bin", "python")
    if !isfile(multimodal_yolo_venv_python)
        error("Python environment for multimodal-yolo not found: $multimodal_yolo_venv_python")
    end
    
    # Create temporary directory in outdir with backup of original docker-compose file before modification
    docker_compose_filename = "docker-compose.detect.yml"
    yolo_detect_docker_compose = joinpath(multimodal_yolo_path, docker_compose_filename)
    tmp_dir = joinpath(outdir, "tmp-backup")
    mkpath(tmp_dir)
    yolo_detect_docker_compose_backup = abspath(tmp_dir, "$(docker_compose_filename).bak")
    if isfile(yolo_detect_docker_compose)
        cp(yolo_detect_docker_compose, yolo_detect_docker_compose_backup; force=false)
        @debug "Backed up original docker-compose file to $yolo_detect_docker_compose_backup"
    else
        error("docker-compose file not found: $yolo_detect_docker_compose")
    end
    # Adjust file paths in docker-compose file
    @info "Setting YOLO data source to $outdir ..."
    run(`sed -i "s|<yourdataoutdir>:|$(outdir):|g" $(yolo_detect_docker_compose)`)
    # Make a copy of this docker-compose and save in log directory
    yolo_log_dir = joinpath(outdir, "logs", "yolo")
    mkpath(yolo_log_dir)
    yolo_detect_docker_compose_log = joinpath(yolo_log_dir, docker_compose_filename)
    cp(yolo_detect_docker_compose, yolo_detect_docker_compose_log; force=true)
    @info "Copied active docker-compose file for YOLO to $yolo_detect_docker_compose_log"
    
    # Run video frame extraction
    @info "Running video frame extraction..."
    frame_extraction_script = joinpath(multimodal_yolo_path, "extract_video_frames.py")
    frame_extraction_cmd = `$(multimodal_yolo_venv_python) $(frame_extraction_script) --input_csv $(frames_csv) --outdir $(outdir) --logdir $(yolo_log_dir)`
    run(frame_extraction_cmd)
    @info "Video frame extraction completed."
    
    # Run YOLO computer vision object detection
    @info "Running YOLO computer vision object detection..."
    yolo_docker_cmd = `docker compose -f $(yolo_detect_docker_compose) up`
    run(yolo_docker_cmd)
    @info "YOLO computer vision object detection completed."

    # Restore backed up docker-compose file to its original location and remove temporary directory
    @debug "Cleaning up..."
    mv(yolo_detect_docker_compose_backup, yolo_detect_docker_compose; force=true)
    rm(tmp_dir; recursive = true)
end
