#get_fixations_for_words


using DataFrames
using CSV
include("/Users/varya/Desktop/Julia/functions.jl")

sets = ["04", "05", "06", "07", "08","09", "10", "11", "12"]
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


frame_numbers= DataFrame(:frame_number => Int[], :set => String[], :session => String[], :noun => String[], :time_sec => Float64)
frame_numbers = select(all_fixations, :frame_number, :set, :session, :noun)
frame_numbers = unique!(frame_numbers)
frame_numbers.time_sec = [frame.frame_number/30 for frame in eachrow(frame_numbers)]

CSV.write("frame_numbers.csv", frame_numbers)
CSV.write("all_fixations.csv", all_fixations)

#304 + 414 + 212 +  0 + 305 + 520 + 598 + 804 + 417 = 3574
#nouns altogether
#304 + 408 + 211 + 0 + 305 + 491 + 574 + 796 + 417  = 3506
#nouns with fixations