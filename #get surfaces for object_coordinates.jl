#get surfaces for object_coordinates

#get surface coordinates by framenumber 
#for each set
#from all surfaces - to know where it was in any case
#aggregate them together into a reference surface coordinates file
#get the object coordinates for each frame
#aggregate them together
# check if the object coordinates are within the surface coordinates
# if they are, assign this surface to the object
using CairoMakie
using Makie.GeometryBasics
using DataFrames
using CSV
using TextParse
include("/Users/varya/Desktop/Julia/functions.jl")

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
    y_pixel = y * img_height
    return x_pixel, y_pixel
end

function yolo_to_normalized_ET(x, y)
    #x,y = 0.38, 0.58
    x_norm = x - 0.5
    y_norm= y - 0.5
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
    result_homogenous =  transpose(transform_matrix) * pos_homogenous # Actual transform
    #result_homogenous =  transform_matrix * pos_homogenous # Actual transform
    result_homogenous .= result_homogenous ./ result_homogenous[end]  # normalize
    new_pos = result_homogenous[1:end-1]  # projection
    return new_pos[1], new_pos[2]
end


function transform_surface_corners(pos, matrix)
    num_pos = size(pos, 1)
    homogenous_component = ones(num_pos, 1)
    pos_homogenous = hcat(pos, homogenous_component)
    #result_homogenous = pos_homogenous * transpose(matrix)
    result_homogenous = pos_homogenous * matrix
    result_homogenous ./= result_homogenous[:, end:end]  # normalize
    new_pos = result_homogenous[:, 1:end-1]  # projection
    return new_pos
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

function pixel_center_and_flip(x, y, img_width, img_height)
    # Assuming x and y are in pixel center coordinates
    # Flip horizontally
    new_x = img_width - x - 1
    # Flip vertically
    new_y = img_height - y - 1
    
    return x, new_y
end

# this is the function that reads files ;)
function get_surfaces_for_all_objects(yolo_coordinates, surface_positions=DataFrame(), root_folder="/Users/varya/Desktop/Julia/", frames=DataFrame())
    #root_folder="/Users/varya/Desktop/Julia/"
    if isempty(frames)
        frames=CSV.read(joinpath(root_folder,"frame_numbers_with_tokens.csv"), DataFrame) 
        println("frames read from file")
    end

    if isempty(surface_positions)
        data, surf_names = TextParse.csvread("/Users/varya/Desktop/Julia/all_surface_matrices.csv")
        surface_positions =  DataFrame()
        for (i, surf_name) in enumerate(surf_names)
            surface_positions[!, Symbol(surf_name)] = data[i]
        end
    end
    if isempty(yolo_coordinates)
        yolo_coordinates = CSV.read(joinpath(root_folder,"all_yolo_coordinates.csv"), DataFrame) 
        println("yolo_coordinates read from file")
    end


    set_surface_positions = filter(row -> row[:set] == 12 && row[:session] == 4, surface_positions)

    set_yolo_coordinates = filter(row -> row[:set] == 12 && row[:session] == 4, yolo_coordinates)

    frame_objects = filter(row -> row[:frame_number] == 8048, set_yolo_coordinates)
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


function get_all_surfaces_for_a_frame(frame_number, set_surface_positions, write_to_file=false)
    #this function is work in progress
    img_width = 1920
    img_height = 1080

    # Select the relevant row based on world_index (frame number)
    frame_surfaces = set_surface_positions[set_surface_positions.world_index .== frame_number, :]
    surface_coords = Dict()
    for surface in eachrow(frame_surfaces)
        #surface = eachrow(frame_surfaces)[1]
        println("checking surface: $(surface.surface)")
        # Extract the transformation matrix
        transform_matrix=parse_transformation_matrix(surface.surf_to_dist_img_trans)
        corners = [0.0 0.0; 1.0 0.0; 1.0 1.0; 0.0 1.0]
        corners_coords = test_coordinates = transform_surface_corners(corners,  transform_matrix)
        surface_coords[surface.surface] = corners_coords
    end
    if write_to_file
        CSV.write("surface_coords_$frame_number.csv", surface_coords)
    end
    return surface_coords
end

function normalize_coordinates(x, y, img_width, img_height)
    x_norm = x / img_width
    y_norm = y / img_height
    return x_norm, y_norm
end


function plot_surfaces(surface_coordinates)
    # Create a figure and axis for plotting with specified resolution
    fig = Figure(resolution = (1920, 1080))
    ax = Axis(fig[1, 1])
    xlims!(ax, 0, 1920)
    ylims!(ax, 1080, 0)
    # Plot each surface
    for surface in surface_coordinates
        surface_name = surface[1]
        println("Plotting surface: $surface_name, with corners: ")
        println(surface[2])
        surface_corners = surface[2]
        # Extracting the first two elements from each 4-element tuple and converting to Point2f
        preprocessed_coords = [(row[1], row[2])  for row in eachrow(surface_corners)]
        poly!(ax, Point2f.(preprocessed_coords), color = :white, strokecolor = :black, strokewidth = 1)
    end
    # Display the figure
    display(fig)
end

# Example usage with dummy data
# Each surface is defined by its corners (x, y) in a clockwise or counterclockwise order


plot_surfaces(surface_coordinates)

surface_coordinates= get_all_surfaces_for_a_frame(8078, set_surface_positions, true)
flipped_surface_coordinates = Dict()


camera_coeff = read_intrinsics("/Users/varya/Desktop/Julia/DGAME data/DGAME3_12_01/002/world.intrinsics")["(1920, 1080)"]
dist_coefs = camera_coeff["dist_coefs"]
camera_matrix = camera_coeff["camera_matrix"]
resolution = camera_coeff["resolution"][1]
#same resolution, just in 8x system
Int(camera_coeff["resolution"][1])

surface_corners = reshape([0.0 0.0; 1.0 0.0; 1.0 1.0; 0.0 1.0], 4, 1, 2)
corners = [0.0 0.0; 1.0 0.0; 1.0 1.0; 0.0 1.0]
test_matrix = parse_transformation_matrix("[[ 1.67485215e+02,  8.73292787e+01,  1.44740836e+03],[ 5.43594466e+01, -1.56430576e+02,  4.17306338e+02], [ 1.58437206e-02,  4.11481102e-02,  1.00000000e+00]]")
test_coordinates = transform_surface_corners(corners,  test_matrix)
typeof(corners)