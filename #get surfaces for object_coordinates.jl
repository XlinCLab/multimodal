#get surfaces for object_coordinates

#get surface coordinates by framenumber 
#for each set
#from all surfaces - to know where it was in any case
#aggregate them together into a reference surface coordinates file
#get the object coordinates for each frame
#aggregate them together
# check if the object coordinates are within the surface coordinates
# if they are, assign this surface to the object

using DataFrames
using CSV
using TextParse



function get_all_surface_coordinates_for_frames(frames=DataFrame())
    root_folder="/Users/varya/Desktop/Julia/"
    if isempty(frames)
        frames=CSV.read(joinpath(root_folder,"frame_numbers_with_tokens.csv"), DataFrame) 
        println("frames read from file")
    end
    frames_sets_and_sessions =  select(frames, [:participant, :session, :frame_number]) |> unique 
    sets_and_sessions = select(frames_sets_and_sessions, [:participant, :session]) |> unique
    surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])  
    all_surface_coordinates = DataFrame(
        world_index = Int[],
        world_timestamp = Float64[],
        img_to_surf_trans = Float64[],
        surf_to_img_trans = Float64[],
        num_detected_markers = Int[],
        dist_img_to_surf_trans = Float64[],
        surf_to_dist_img_trans = Float64[],
        num_definition_markers = Int[],
        surface = String[],
        set=String[],
        session=String[]
    )

    for row in eachrow(sets_and_sessions)
        #row = eachrow(sets_and_sessions)[1]
        participant = row.participant
        set=participant[1:2]
        session = row.session
        surface_session = surface_sessions[lpad(row.session,2,"0")]
        filtered = filter(row -> row.participant == participant && row.session == session, frames_sets_and_sessions)
        frame_numbers = filtered.frame_number
        surface_coordinates = get_surface_coordinates(participant,surface_session,frame_numbers)
        surface_coordinates.set = fill(set, nrow(surface_coordinates))
        surface_coordinates.session = fill(session, nrow(surface_coordinates))
        all_surface_coordinates = vcat(all_surface_coordinates, surface_coordinates)
    end
    CSV.write("all_surface_coordinates.csv", all_surface_coordinates)
    #test_coords=get_surface_coordinates("12_01", "003", [100,200,6888])
end

function get_surface_coordinates(participant,session,framenumbers, root_folder="/Users/varya/Desktop/Julia/DGame data")
    #CSV.read cannot parse nested lists of coordinates
    #!NB this function does not return set and session
    data_type = "surf_positions"
    participant_folder = joinpath(root_folder, "DGAME3_$participant", "$session", "exports")
    try
        readdir(participant_folder)
    catch e
        println("No data for $participant for this session: $session")
        println(e)
        return DataFrame()
    end
    subfolders = [f for f in readdir(participant_folder) if isdir(joinpath(participant_folder, f))]
    if subfolders[1]=="surfaces"
        surface_folder = joinpath(participant_folder, subfolders[1])
    else
        surface_folder = joinpath(participant_folder, subfolders[1],"surfaces")
    end
    surface_files = [file for file in readdir(surface_folder)if occursin(data_type, file)]
    try
        data, names = TextParse.csvread(joinpath(surface_folder, "$data_type"*"_face.csv"))
    catch e
        println("No surface coordinates data for $participant for this session: $session")
        println(joinpath(surface_folder, "$data_type"*"_face.csv"))
        return DataFrame()
    end
    surface_coordinates = DataFrame(
        world_index = Int[],
        world_timestamp = Float64[],
        img_to_surf_trans = Float64[],
        surf_to_img_trans = Float64[],
        num_detected_markers = Int[],
        dist_img_to_surf_trans = Float64[],
        surf_to_dist_img_trans = Float64[],
        num_definition_markers = Int[],
        surface = String[]
    )
    for file in surface_files
        surface = split(file, "_")[end] |> x -> split(x, ".")[1]
        data, names = TextParse.csvread(joinpath(surface_folder, file))
        surface_df =  DataFrame()
        for (i, name) in enumerate(names)
            surface_df[!, Symbol(name)] = data[i]
        end
        filter!(row -> row.world_index in framenumbers, surface_df)
        surface_df.surface = fill(surface, nrow(surface_df))
        surface_coordinates = vcat(surface_coordinates, surface_df)
    end
    return surface_coordinates
end
    # Load the CSV file with TextParse, CSV.read cannot parse it

#Not sure it works properly, check
function get_surface_for_object( object_x, object_y, frame_number, set_surface_positions)
    #this function is work in progress
    img_width = 1920
    img_height = 1080

    # Select the relevant row based on world_index (frame number)
    frame_surfaces = set_surface_positions[set_surface_positions.world_index .== frame_number, :]

    surface_number = "outside all"
    for surface in eachrow(frame_surfaces)
        #surface = eachrow(frame_surfaces)[1]
        println("checking surface: $(surface.surface)")
        # Extract the transformation matrix
        surf_to_img_trans = parse_transformation_matrix(surface.surf_to_dist_img_trans)
        surface_corner =transform_surface_to_image_coordinates(1, 1, surf_to_img_trans)
        img_to_surf_trans = parse_transformation_matrix(surface.dist_img_to_surf_trans)
        surface_corner =transform_image_to_surface_coordinates(0.47,-0.49, img_to_surf_trans)
        center_x_pixel, center_y_pixel = yolo_to_pixel_center(object_x, object_y, img_width, img_height)
        # Transform bounding box center to surface coordinates
        center_x_surf, center_y_surf = transform_image_to_surface_coordinates(center_x_pixel, center_y_pixel, img_to_surf_trans)
        println("Center x surf: $center_x_surf, Center y surf: $center_y_surf")
        function is_inside_surface(x_surf, y_surf)
            return 0.0 <= x_surf <= 1.0 && 0.0 <= y_surf <= 1.0
        end
        if is_inside_surface(center_x_surf, center_y_surf)
            surface_number = surface.surface
            println("Object is inside surface: $surface_number")
            return surface_number
        end
    end
    println(surface_number)
    return surface_number
end

function yolo_to_pixel_center(x, y, img_width, img_height)
    x_pixel = x * img_width
    y_pixel = (1 - y) * img_height
    return x_pixel, y_pixel
end

function yolo_to_normalized_ET(x, y)
    #x,y = 0.38, 0.58
    x_norm = x -0.5
    y_norm= (1 - y) -0.5
    return x_norm, y_norm
end

function transform_image_to_surface_coordinates(x, y, transform_matrix)
    pos_homogenous = [x, y, 1] # Add homogenous coordinate
    result_homogenous =  (transform_matrix) * pos_homogenous # Actual transform
    result_homogenous .= result_homogenous ./ result_homogenous[end]  # normalize
    new_pos = result_homogenous[1:end-1]  # projection
    return new_pos[1], new_pos[2]
end

function transform_surface_to_image_coordinates(x, y, transform_matrix)
    pos_homogenous = [x, y, 1] # Add homogenous coordinate
    #it looks like transposition brings image coorinate, non-transposed matrix brings normalized image coordinates
    #result_homogenous =  transpose(transform_matrix) * pos_homogenous # Actual transform
    result_homogenous =  transform_matrix * pos_homogenous # Actual transform
    result_homogenous .= result_homogenous ./ result_homogenous[end]  # normalize
    new_pos = result_homogenous[1:end-1]  # projection
    return new_pos[1], new_pos[2]
end


function parse_transformation_matrix(matrix_str)
    # Remove brackets and commas, then split by spaces
    cleaned_str = replace(matrix_str, r"[\[\],]" => "")
    # Split the cleaned string into individual number strings
    number_strs = split(cleaned_str, r"\s+")
    # Filter out any empty strings
    number_strs = filter(x -> !isempty(x), number_strs)
    # Parse the strings to Float64 and reshape into a 3x3 matrix
    return reshape(parse.(Float64, number_strs), 3, 3)
end

function get_all_yolo_coordinates(labels_folder)
 labels_folder = "/Users/varya/Desktop/Python/yoloo/yolo7Test/data/results/output/labels"
 object_names=Dict([(0,"batterie"), (1,"blume"), (2,"creme"), (3,"kerze") ,(4, "spritze"), (5,"tasse"),(6,"tube"), (7,"vase")])
    all_yolo_coordinates = DataFrame(
        frame_number = Int[],
        set = String[],
        session = String[],
        object = String[],
        x = Float64[],
        y = Float64[],
        w = Float64[],
        h = Float64[]
    )
    for file in readdir(labels_folder)
        if occursin(".txt", file)
            frame_number = parse(Int, split(file, "_")[end] |> x -> split(x, ".")[1])
            data = readlines(joinpath(labels_folder, file))
            for line in data
                object = split(line, " ")[1]
                set=split(file, "_")[1]
                if length(split(file, "_"))>2
                    session=string(split(file, "_")[3][1])
                else
                    session="0"
                end
                object = object_names[parse(Int, object)]
                x = parse(Float64, split(line, " ")[2])
                y = parse(Float64, split(line, " ")[3])
                w = parse(Float64, split(line, " ")[4])
                h = parse(Float64, split(line, " ")[5])
                push!(all_yolo_coordinates, (frame_number,set,session, object, x, y, w, h))
            end
        end
    end
    CSV.write("all_yolo_coordinates.csv", all_yolo_coordinates)
    return all_yolo_coordinates

end

function get_surfaces_for_all_objects(yolo_coordinates, surface_positions=DataFrame(), root_folder="/Users/varya/Desktop/Julia/", frames=DataFrame())
    #root_folder="/Users/varya/Desktop/Julia/"
    if isempty(frames)
        frames=CSV.read(joinpath(root_folder,"frame_numbers_with_tokens.csv"), DataFrame) 
        println("frames read from file")
    end

    if isempty(surface_positions)
        data, names = TextParse.csvread("/Users/varya/Desktop/Julia/all_surface_coordinates.csv")
        surface_positions =  DataFrame()
        for (i, name) in enumerate(names)
            surface_positions[!, Symbol(name)] = data[i]
        end
    end
    if isempty(yolo_coordinates)
        yolo_coordinates = CSV.read(joinpath(root_folder,"all_yolo_coordinates.csv"), DataFrame) 
        println("yolo_coordinates read from file")
    end


    set_surface_positions = filter(row -> row[:set] == 6 && row[:session] == 4, surface_positions)
    #CSV.write("set_surface_positions12.csv", set_surface_positions)
    set_yolo_coordinates = filter(row -> row[:set] == 6 && row[:session] == 4, yolo_coordinates)
    #12_01_4vase_8078
    #06_01_4spritze_7748

    frame_objects = filter(row -> row[:frame_number] == 7748, set_yolo_coordinates)
    for object in eachrow(frame_objects)
        #object = eachrow(frame_objects)[1]
        object_name = object.object
        object_x = object.x
        object_y = object.y
        normalized_ET = yolo_to_normalized_ET(object_x, object_y)
        frame_number = 7748
        println("Object: $(object.object), x: $(object.x), y: $(object.y)")
        get_surface_for_object(object_x, object_y, frame_number, set_surface_positions)
    end


    get_surface_for_object( object_x, object_y, frame_number, set_surface_positions)

end

yolo_coordinates = get_all_yolo_coordinates("/Users/varya/Desktop/Python/yoloo/yolo7Test/data/results/output/labels")