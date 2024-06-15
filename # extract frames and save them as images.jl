# extract frames and save them as images to recognize object positions
# this function does not work as package precompilation fails, use python
# using Pkg
# Pkg.add("OpenCV")
#Pkg.update("VideoIO")
# Pkg.add("Images")
#Pkg.add("ImageIO")
# Pkg.add("FileIO")

using OpenCV

function get_frames(video_path, frame_numbers)
    # Open the video file
    cap = cv.VideoCapture(video_path)
    # Frame storage
    frames = []

    for frame_number in frame_numbers
        # Set the video position to the frame number
        cv.set(cap, cv.CAP_PROP_POS_FRAMES, frame_number)
        # Read the frame
        ret, frame = cv.read(cap)
        # Check if the frame was read successfully
        if ret
            # Add the frame to the frames array
            push!(frames, frame)
        else
            println("Failed to read frame $frame_number")
        end
    end
    # Release the video file
    cv.release(cap)
    return frames
end
get_frames("/Users/varya/Desktop/Julia/DGAME data/DGAME3_04_01/001/world.mp4", [100, 225, 3045, 4457])