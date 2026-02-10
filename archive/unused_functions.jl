function transform_image_to_surface_coordinates(x, y, transform_matrix)
    pos_homogenous = [x, y, 1] # Add homogenous coordinate
    result_homogenous =  (transform_matrix) * pos_homogenous # Actual transform
    result_homogenous .= result_homogenous ./ result_homogenous[end]  # normalize
    new_pos = result_homogenous[1:end-1]  # projection
    return new_pos[1], new_pos[2]
end


function pixel_center_and_flip(x, y, img_width, img_height)
    # Assuming x and y are in pixel center coordinates
    # Flip horizontally
    new_x = img_width - x - 1
    # Flip vertically
    new_y = img_height - y - 1
    
    return x, new_y
end


#functions for exploratory Plots
function surface_heatmap() 
    #this function is work in progress
    #for each session:
        # fixations on face
        #fixations on hands
        # fixations on target objects
end


function print_folder_structure(path::String, indent::String = "")
    # List all files and directories in the given path
    entries = readdir(path)
    # Sort entries to list directories first, then files
    sorted_entries = sort(entries, by = x -> (isdir(joinpath(path, x)) ? 0 : 1, x))
    
    for (i, entry) in enumerate(sorted_entries)
        # Determine if the current entry is the last in the list
        is_last = i == length(sorted_entries)
        # Prepare the prefix for printing
        prefix = is_last ? "└── " : "├── "
        # Print the current entry
        println(out,indent * prefix * entry)
        
        # If the entry is a directory, recursively print its contents
        full_path = joinpath(path, entry)
        if isdir(full_path)
            new_indent = indent * (is_last ? "    " : "│   ")
            print_folder_structure(full_path, new_indent)
        end
    end
end