using LinearAlgebra

# Function to transform surface coordinates to image coordinates
function transform_surface_corners(pos, matrix)
    pos_homogenous = [pos..., 1] # Add homogenous coordinate    
    # Actual transform
    result_homogenous =  transpose(matrix) * pos_homogenous
    result_homogenous .= result_homogenous ./ result_homogenous[end]  # normalize
    new_pos = result_homogenous[1:end-1]  # projection
    return new_pos
end

# Function to transform image coordinates to surface coordinates
function transform_image_to_surface(pos, matrix)
    inv_matrix = inv(matrix)
    transform_surface_to_image(pos, inv_matrix)
end

# Example usage:
using MsgPack

# Path to the binary file
file_path = "/Users/varya/Desktop/Julia/DGAME data/DGAME3_12_01/003/world.intrinsics"

# Read the binary file
function read_binary_file(file_path)
    open(file_path, "r") do file
        return read(file)
    end
end

function read_intrinsics(file_path)
    binary_content = read_binary_file(file_path)
    data = MsgPack.unpack(binary_content)
    return data
end

function get_all_camera_intrinsics(frames,root_folder = "/Users/varya/Desktop/Julia/DGAME data/")
    if isempty(frames)
        frames=CSV.read(joinpath(root_folder,"frame_numbers_with_tokens.csv"), DataFrame) 
        println("frames read from file")
    end
    frames_sets_and_sessions =  select(frames, [:participant, :session, :frame_number]) |> unique 
    sets_and_sessions = select(frames_sets_and_sessions, [:participant, :session]) |> unique
    surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])  

    
    data = read_intrinsics(file_path)
    return data["intrinsics"]
end