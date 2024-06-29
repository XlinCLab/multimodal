#get_fixations_for_words


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
