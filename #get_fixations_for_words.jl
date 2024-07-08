#get_fixations_for_words

using TextParse
using DataFrames
using CSV
include("/Users/varya/Desktop/Julia/functions.jl")
sets = ["04", "05", "06", "07", "08","09", "10", "11", "12"]
surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])  
# Open a log file for writing
log_file = open("combine_fixations_by_nouns.log", "w")

# Redirect stdout to the log file
redirect_stdout(log_file) do
    @info "This is the log file of the processing of the fixations by nouns, you can find all the missing values and errors here"
    # get all the fixations for all participants I have
    all_fixations = DataFrame()
    for set in sets
        println("set $set")
        fixations = get_set_fixations_for_nouns(set)
        all_fixations = vcat(all_fixations, fixations)
    end
end
close(log_file)
# Redirect back to the console
redirect_stdout(stdout)

frame_numbers = select(all_fixations, :frame_number, :participant, :session, :noun)
frame_numbers = unique!(frame_numbers)
#take only matcher videos
frame_numbers = filter(row -> endswith(row.participant, "_01"), frame_numbers)
frame_numbers.time_sec = [frame.frame_number/30 for frame in eachrow(frame_numbers)]
frame_numbers.video_path .= ""

#frame_numbers = CSV.read("/Users/varya/Desktop/Julia/frame_numbers.csv", DataFrame)
for row in eachrow(frame_numbers)
    #row=eachrow(frame_numbers)[1]
    session = lpad(row.session,2,"0")
    session = surface_sessions[session]
    row.video_path = joinpath(root_folder, "DGAME3_"*row.participant, session , "world.mp4")
end
frame_numbers= get_tokens_for_nouns(frame_numbers)
CSV.write("frame_numbers_with_tokens_test.csv", frame_numbers)
CSV.write("all_fixations_test.csv", all_fixations)

function check_april_tags_for_frames(frames)
    if isempty(frames)
        frames = CSV.read("frame_numbers_with_tokens.csv", DataFrame) |>
        df -> transform!(df, :participant => ByRow(x-> x[1:2]) => :set) |>
        df -> transform!(df, :session => ByRow(x-> lpad(x, 2, "0")) => :session)
        frames.new_frame_number = zeros(Int,size(frames, 1))
    end
    videos = unique(frames.video_path)
    for video in videos
        surfaces_folder = joinpath(replace(video, "world.mp4" => ""),"exports")
        subfolders = [f for f in readdir(surfaces_folder ) if isdir(joinpath(surfaces_folder, f))]
        if subfolders[1]=="surfaces"
            surface_folder = joinpath(surfaces_folder, subfolders[1])
        else
            surface_folder = joinpath(surfaces_folder, subfolders[1],"surfaces")
        end
        data, surf_names = TextParse.csvread(joinpath(surface_folder, "surf_positions_face.csv"))
        april_tags =  DataFrame()
        for (i, surf_name) in enumerate(surf_names)
            april_tags[!, Symbol(surf_name)] = data[i]
        end
        april_tags_dict = Dict(row[:world_index] => row[:num_detected_markers] for row in eachrow(april_tags))
        for frame in eachrow(frames)
            println(frame.frame_number)
            if haskey(april_tags_dict, frame.frame_number) && april_tags_dict[frame.frame_number] == 6
                frame.new_frame_number = frame.frame_number
                continue
            else
            #I want to have the frame with maximum tags recognized
            #but only before the onset, with 30 fps 200ms is 6 frames
                println("not enough tags frame number: ", frame.frame_number)
                frame_tags = Dict(key => value for (key, value) in april_tags_dict if key >= frame.frame_number - 10 && key <= frame.frame_number + 6)
                println(frame_tags)
                if isempty(frame_tags)
                    frame.new_frame_number = 0
                    continue
                end
                max_tags_recognized = maximum(values(frame_tags))
                frame.new_frame_number =  [key for (key, value) in frame_tags if value == max_tags_recognized][1]
            end
        end
        
    end
    CSV.write("frame_numbers_corrected_with_tokens.csv", frames)
    return frames
end