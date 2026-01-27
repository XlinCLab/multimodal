using ArgParse

@info "Loading environment..."
include("functions.jl")


function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--data_root_dir"
            help = "Path to root directory containing DGAME data."
        "--outdir"
            help = "Path to desired output directory. Defaults to a subdirectory 'out' of the current working directory."
            default = "./out"
        "--yolo_outdir"
            help = "Path to YOLO computer vision output directory from part 2 of the pipeline."
        "--yolo_labels_dir"
            help = "Path to YOLO computer vision labels output directory."  # TODO check if this is redudant
        "--labels_yaml"
            help = "Path to YOLO computer vision model's object names/labels .yaml file"
    end

    return parse_args(s)
end


function main()
    args = parse_commandline()
    data_root_dir = args["data_root_dir"]
    outdir = args["outdir"]
    mkpath(outdir)
    log_dir = joinpath(outdir, "logs")
    mkpath(log_dir)
    # YOLO output paths
    yolo_outdir = args["yolo_outdir"]
    yolo_labels_dir = args["yolo_labels_dir"]  # TODO check if this is redudant given yolo_outdir is already supplied
    labels_yaml = args["labels_yaml"]
    @info "Data root: $data_root_dir"
    @info "YOLO output directory: $yolo_outdir"
    @info "Logs: $log_dir"

    # Default output if no output log file specified
    out = stdout

    # Reload data from previously written results CSV files
    corrected_frames_csv = joinpath(outdir, "frame_numbers_corrected_with_tokens.csv")
    @info "Loading corrected frames data from $corrected_frames_csv"
    frames_corrected = CSV.read(corrected_frames_csv, DataFrame)
    surface_fixation_csv = joinpath(outdir, "all_trial_fixations.csv")
    @info "Loading surface fixation data from $surface_fixation_csv"
    all_trial_surfaces_fixations = CSV.read(surface_fixation_csv, DataFrame)
    surface_gaze_csv = joinpath(outdir, "all_trial_gazes.csv")
    all_trial_surfaces_gazes = CSV.read(surface_gaze_csv, DataFrame)
    @info "Loading surface gaze data from $surface_gaze_csv"

    # Get all transformation matrices for all frames in one aggregated table
    # it will be written to a CSV file "all_surface_matrices.csv"
    surface_positions = get_all_surface_matrices_for_frames(frames_corrected, data_root_dir)
    write_results_csv(surface_positions, outdir, "all_surface_matrices.csv", "surface position matrices"; out=out)
    # in case needed to load it from file
    # NB: CSV package cannot handle surface transformation matrices, so use TextParse
    # if isempty(surface_positions)
    #     data, surf_names = TextParse.csvread(joinpath(outdir,"all_surface_matrices.csv"))
    #     surface_positions =  DataFrame()
    #     for (i, surf_name) in enumerate(surf_names)
    #         surface_positions[!, Symbol(surf_name)] = data[i]
    #     end
    # end

    # Get all coordinates for all recognized objects for all frames and write to a single CSV file
    yolo_coordinates = get_all_yolo_coordinates(yolo_labels_dir, labels_yaml)
    write_results_csv(yolo_coordinates, outdir, "all_yolo_coordinates.csv", "YOLO coordinates")
    # Yolo may change image size deleting the black borders, so we need to check the image sizes
    image_sizes = collect_image_dimensions(yolo_outdir)
    write_results_csv(image_sizes, outdir, "image_sizes.csv", "image sizes")

    # Get surface information for recognized objects
    log_file = joinpath(log_dir, "object_coordinates.log")
    @info "Extracting surface information for recognized objects...\nLog file: $log_file"
    log_file = open(log_file, "w")
    all_frame_objects = get_surfaces_for_all_objects(yolo_coordinates, surface_positions, frames_corrected, image_sizes; out=log_file)
    write_results_csv(all_frame_objects, outdir, "all_frame_objects_surfaces.csv", "surface data for recognized objects"; out=log_file)
    close(log_file)

    # Join this with the gazes and fixations, so we have all objects for all frames of interest
    log_file = joinpath(log_dir, "get_object_position_for_all_trial_fixations.log")
    @info "Combining surface information for recognized objects with gaze and fixation data...\nLog file: $log_file"
    log_file = open(log_file, "w")
    all_trial_fixations_with_objects, all_trial_gazes_with_objects = get_object_position_for_all_trial_fixations(all_frame_objects, all_trial_surfaces_gazes, all_trial_surfaces_fixations; out=log_file)
    @debug "" all_trial_gazes_with_objects=describe(all_trial_gazes_with_objects)
    write_results_csv(all_trial_fixations_with_objects, outdir, "all_trial_surfaces_fixations_with_objects.csv", "all trial surface fixations with objects"; out=log_file)
    write_results_csv(all_trial_gazes_with_objects, outdir, "all_trial_surfaces_gazes_with_objects.csv", "all trial surface gazes with objects"; out=log_file)
    close(log_file)

    # TODO check the join here, we need inner but with face
    #or add an extra column which tells where is the target object
    #check where the gazes go - I have 4,5 million observtions
    log_file = joinpath(log_dir, "get_gazes_and_fixations_by_frame_and_surface.log")
    @info "Extracting gazes and fixation by frame and surface...\nLog file: $log_file"
    log_file = open(log_file, "w")
    target_gazes, target_fixations = get_gazes_and_fixations_by_frame_and_surface(all_frame_objects, all_trial_surfaces_gazes, all_trial_surfaces_fixations; out=log_file)
    write_results_csv(target_gazes, outdir, "target_gazes_1sec.csv"; out=log_file)
    write_results_csv(target_fixations, outdir, "target_fixations_1sec.csv"; out=log_file)
    close(log_file)

    # TODO
    #this is an optional part to plot a frame if there is something suspicious going on with the surfaces
    #surface_coordinates=get_all_surfaces_for_a_frame(19787, frame_surfaces)
    #plot_surfaces(surface_coordinates, img_width, img_height, "/Users/varya/Desktop/Python/multimodal-yolo/data/results/output/set05_01_session2_frame_9690.jpg")

    ### analysis
        #fit the model
        #model = fit(MixedModel, @formula(dependant_variable ~ fixed_effects + (1|random_effects)), data)
end


main()
