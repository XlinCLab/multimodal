function multimodal_pipeline_pt2(args)
    outdir = abspath(args["outdir"])
    frames_csv = abspath(args["frames_csv"])
    multimodal_yolo_path = abspath(args["multimodal_yolo_path"])
    multimodal_yolo_venv_python = joinpath(multimodal_yolo_path, ".venv", "bin", "python")
    frame_extraction_script = joinpath(multimodal_yolo_path, "efficient_frames_extracting.py")
    frame_extraction_cmd = `$(multimodal_yolo_venv_python) $(frame_extraction_script) --input_csv $(frames_csv) --outdir $(outdir)`
    run(frame_extraction_cmd)
    yolo_detect_docker_compose = joinpath(multimodal_yolo_path, "docker-compose.detect.yml")
    # Adjust file paths in docker compose file
    run(`sed -i "s|<yourdataoutdir>|$(outdir)|g" $(yolo_detect_docker_compose)`)
    yolo_docker_cmd = `docker compose -f $(yolo_detect_docker_compose) up`
    run(yolo_docker_cmd)
    # Change back to placeholder in docker compose file
    run(`sed -i "s|$(outdir)|<yourdataoutdir>|g" $(yolo_detect_docker_compose)`)
end
