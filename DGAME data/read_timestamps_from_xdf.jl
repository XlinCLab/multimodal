# using Pkg
# Pkg.add("XDF")
# Pkg.add("EzXML")
# Pkg.add("XMLDict")
#Pkg.add("JSON")
using Printf
Base.show(io::IO, f::Float64) = @printf(io, "%.2f", f)
using XDF
using EzXML
using XMLDict
using DataFrames
using CSV


sets = ["04", "05", "06", "07", "08", "10", "11", "12"]


function read_timestamps_from_xdf(setting::String, root_folder::String="/Users/varya/Desktop/Julia/DGAME data/xdf")
    sessions = Dict([("11","01"),("12","02"), ("21", "03"), ("22" ,"04")])
    director_files = readdir(joinpath(root_folder, setting, "Director"))
    #setting = "04" #for testing
    timestamps = DataFrame(:set => String[], :session => String[],:stream => String[], :created => Float64[], :first_timestamp => Float64[], :last_timestamp => Float64[])
    #file = director_files[1] #for testing
    for file in director_files
        try
            sessions[file[end-5:end-4]]
        catch e
            println("No session for $file or file is irrelavant")
            continue
        end
        session = sessions[file[end-5:end-4]]
        exp_set = read_xdf(joinpath(joinpath(root_folder, setting, "Director"),file))
        # Extract the timestamps from the XDF file
        # the numbers of streams are random in terms of what is the contents
        #so we have to check the contents of the streams by name
        for i in eachindex(exp_set)
            println(exp_set[i]["name"])
            name=exp_set[i]["name"]
            if name == "audio"
                audio_created = round(parse(Float64,xml_dict(exp_set[i]["header"])["info"]["created_at"]), digits=3)
                audio_first_timestamp = round(parse(Float64, xml_dict(exp_set[i]["footer"])["info"]["first_timestamp"]), digits=3)
                audio_last_timestamp = round(parse(Float64,xml_dict(exp_set[i]["footer"])["info"]["last_timestamp"]), digits=3)
                push!(timestamps, (setting, session, "audio",audio_created, audio_first_timestamp, audio_last_timestamp))
            elseif name == "pupil_capture"
                ET_name=xml_dict(exp_set[i]["header"])["info"]["hostname"]
                ET_created = round(parse(Float64,xml_dict(exp_set[i]["header"])["info"]["created_at"]), digits=3)
                ET_first_timestamp = round(parse(Float64,xml_dict(exp_set[i]["footer"])["info"]["first_timestamp"]), digits=3)
                ET_last_timestamp = round(parse(Float64,xml_dict(exp_set[i]["footer"])["info"]["last_timestamp"]), digits=3)
                push!(timestamps, (setting, session, "ET_$ET_name", ET_created, ET_first_timestamp, ET_last_timestamp))
            end
        end
    end
    timestamps.diff = timestamps.first_timestamp - timestamps.created
    timestamps.duration = timestamps.last_timestamp - timestamps.first_timestamp 
    return timestamps
end

function get_all_timestamps_from_xdf(sets, root_folder)
    timestamps_dir = DataFrame(:set => String[], :session => String[],:stream => String[], :created => Float64[], :first_timestamp => Float64[], :last_timestamp => Float64[], :diff => Float64[], :duration => Float64[])
    for set in sets
        timestamps_dir = vcat(timestamps_dir,read_timestamps_from_xdf(set))
    end

    # Define a function that converts a float to an integer
    float_to_int(x::Float64) = trunc(Int, x)
    transform!(timestamps_dir, names(timestamps_dir, Float64) .=> (x -> x .* 1000) .=> names(timestamps_dir, Float64))
    # Apply this function to each float column in the DataFrame
    transform!(timestamps_dir, names(timestamps_dir, Float64) .=>  (x -> float_to_int.(x)) .=> names(timestamps_dir, Float64))

    #lot's of data missing for the director
    CSV.write(joinpath(root_folder, "timestamps.csv"), timestamps_dir)
    return timestamps_dir
end

