function find_multimodal_yolo(multimodal_yolo_path)
    multimodal_yolo_path = abspath(multimodal_yolo_path)
    if !isdir(multimodal_yolo_path)
        error("multimodal-yolo not found: $multimodal_yolo_path")
    end
    multimodal_yolo_venv_python = joinpath(multimodal_yolo_path, ".venv", "bin", "python")
    if !isfile(multimodal_yolo_venv_python)
        error("Python virtual environment for multimodal-yolo not found: $multimodal_yolo_venv_python")
    end
    return multimodal_yolo_path, multimodal_yolo_venv_python
end


function multimodal_pipeline_pt2(args)
    outdir = abspath(args["outdir"])
    frames_csv = abspath(args["frames_csv"])
    
    # Verify that the pretrained YOLO model and its component files exist
    yolo_model_path = abspath(args["yolo_model_path"])
    if !isdir(yolo_model_path)
        error("YOLO model not found: $yolo_model_path")
    else
        pretrained_weights = joinpath(yolo_model_path, "weights.pt")
        model_data_yaml = joinpath(yolo_model_path, "model.yaml")
        if !isfile(pretrained_weights)
            error("YOLO model's weights file not found: $pretrained_weights")
        elseif !isfile(model_data_yaml)
            error("YOLO model file not found: $model_data_yaml")
        end
    end
    
    # Find location of multimodal-yolo and its Python virtual environment
    multimodal_yolo_path, multimodal_yolo_venv_python = find_multimodal_yolo(args["multimodal_yolo_path"])
    @info "Using multimodal-yolo from: $multimodal_yolo_path"
    
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
    @info "YOLO data source: $outdir "
    run(`sed -i "s|<yourdatadir>:|$(outdir):|g" $(yolo_detect_docker_compose)`)
    @info "YOLO model: $yolo_model_path"
    run(`sed -i "s|<youryolomodel>:|$(yolo_model_path):|g" $(yolo_detect_docker_compose)`)
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
