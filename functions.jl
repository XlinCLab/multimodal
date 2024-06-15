#functions

# using Pkg
# Pkg.add("XDF")
# Pkg.add("EzXML")
# Pkg.add("XMLDict")
#Pkg.add("JSON")
#Pkg.add("LinearAlgebra")
#Pkg.add("TextParse")
#Pkg.add("PrettyTables")
#Pkg.add("MsgPack")

function read_intrinsics(file_path)
    binary_content = read_binary_file(file_path)
    data = MsgPack.unpack(binary_content)
    return data
end
using Printf
Base.show(io::IO, f::Float64) = @printf(io, "%.2f", f)
using XDF
using EzXML
using XMLDict
using DataFrames
using CSV
using JSON
using LinearAlgebra
using TextParse

function get_json_timestamp(participant, session, root_folder="/Users/varya/Desktop/Julia/DGAME data/")
    surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])
    surface_session = surface_sessions[session]
    session_file = joinpath(root_folder, "DGAME3_$participant", "$surface_session", "info.player.json")
    println(session_file)
    try
        JSON.parsefile(session_file)
    catch e
        println("No json file for $set for this session: $session")
        return Dict()
    end
    info= JSON.parsefile(session_file)
    start_time_synced_s = info["start_time_synced_s"]
    duration = info["duration_s"]
    return (start_time_synced_s, duration)
end

function read_surfaces(participant, session, data_type = "fixations_on_surface", root_folder="/Users/varya/Desktop/Julia/DGAME data/")
    #participant="04_02"  for testing
    #session="001"  for testing
    surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])  
    participant_folder = joinpath(root_folder, "DGAME3_$participant", "$session", "exports")
    lag_data= DataFrame()
        #/Users/varya/Desktop/Julia/DGAME data/DGAME3_06_01/000/exports/000/surfaces
    try 
        CSV.read(joinpath(root_folder,"lag_data.csv"), DataFrame)
    catch e
        println("No lag data in file")
    end 
    lag_data = CSV.read(joinpath(root_folder,"lag_data.csv"), DataFrame) |>
            #insert zeroes before single digits, so it fits the number of the set passed to the function         
            df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set) |>
            df -> transform!(df, :session => ByRow(x-> lpad(x, 2, "0")) => :session) 
    # Use the map function to apply the dictionary to the session column
    lag_data.session = map(x -> get(surface_sessions, x, x), lag_data.session)
    transform!(lag_data, :stream => (x -> ifelse.(x .== "ET_idslexp", "01", ifelse.(x .== "ET_DESKTOP-5B8EI51", "02", x))) => :participant)
    lag_data.participant = [string(row.set, "_", row.participant) for row in eachrow(lag_data)]
    
    if size(lag_data)[1] != 0
        lag_data = filter(row -> row.participant == participant && row.session == session, lag_data)
        if size(lag_data)[1] != 0
            lag_data = select!(lag_data, [:stream, :lag_duration, :lag_timestamp])
        end
    else
        println("No lag data for $participant for this session: $session, times are not aligned ")
    end

    lag = lag_data.lag_timestamp[1]
    if  lag < 0
        println("check timestamps for $participant for this session: $session, negative lag ")
        return DataFrame()
    elseif lag > 500
        println("check timestamps for $participant for this session: $session, huge lag ")        
        return DataFrame()
    end
    # now process fixations
    try
        readdir(participant_folder)
    catch e
        println("No data for $participant for this session: $session")
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
        CSV.read(joinpath(surface_folder, "$data_type"*"_face.csv"), DataFrame)
    catch
        println("No fixation data for $participant for this session: $session")
        return DataFrame()
    end
        fixations_positions = CSV.read(joinpath(surface_folder, "$data_type"*"_face.csv"), DataFrame)
        filter!(row -> row.on_surf == true, fixations_positions)
        if data_type == "fixations_on_surface"
            time_zero = fixations_positions.start_timestamp[1]
            fixations_positions.time_sec = fixations_positions.start_timestamp .- time_zero
            fixations_positions.time_corrected =  fixations_positions.start_timestamp  .- lag_zero
        else
            time_zero = fixations_positions.gaze_timestamp[1]
            fixations_positions.time_sec = fixations_positions.gaze_timestamp .- time_zero
            fixations_positions.time_corrected =  fixations_positions.gaze_timestamp .- lag_zero
        end
        fixations_positions.surface = fill("face", nrow(fixations_positions))

        for file in surface_files
                    surface = split(file, "_")[end] |> x -> split(x, ".")[1]
                    surface_df =  CSV.read(joinpath(surface_folder, file), DataFrame)
                    if data_type == "fixations_on_surface"
                        time_zero = surface_df.start_timestamp[1]
                        surface_df.time_sec = surface_df.start_timestamp .- time_zero
                        surface_df.time_corrected =  surface_df.start_timestamp .- lag_zero
                    else
                        time_zero = surface_df.gaze_timestamp[1]
                        surface_df.time_sec = surface_df.gaze_timestamp .- time_zero
                        surface_df.time_corrected =  surface_df.gaze_timestamp .- lag_zero
                    end
                    filter!(row -> row.on_surf == true, surface_df) 
                    surface_df.time_sec =  surface_df.time_sec .- lag
                    surface_df.surface = fill(surface, nrow(surface_df))
                    fixations_positions = append!(fixations_positions, surface_df)
        end
        #names(fixations_positions)
        normal_sessions = Dict("000" => "01", "001" => "02", "002" => "03", "003" => "04")
        normal_session= normal_sessions[session]
        fixations_positions.participant = fill(participant, nrow(fixations_positions))
        fixations_positions.session = fill(normal_session, nrow(fixations_positions))
        fixations_positions.lag = fill(lag, nrow(fixations_positions))
        #CSV.write("fixations_positions_12_03.csv", fixations_positions)
        return fixations_positions
end

function get_joint_attention_fixations(set, session)
        director = set*"_02"
        matcher = set*"_01"
    director_fixations = read_surfaces(director, session) |>
                        df -> select!(df, [ :time_sec, :world_index, :surface, :duration, :start_timestamp])|>
                        df -> rename!(df,  :time_sec => :time_sec_director, :duration => :duration_director, :start_timestamp => :start_timestamp_director)
    matcher_fixations = read_surfaces(matcher, session) |>
                        df -> select!(df, [ :time_sec, :world_index, :surface, :duration, :start_timestamp])
    #world index is the number of the closest video DataFrame
    joint_attention = innerjoin(matcher_fixations,director_fixations, on = [:world_index, :surface] )
    return joint_attention
end


function get_joint_attention_gaze_positions(set, session)
        director = set*"_02"
        matcher = set*"_01"
    director_gps = read_surfaces(director, session, "gaze_positions_on_surface") |>
                        df -> select!(df, [ :time_sec, :world_index, :surface,  :gaze_timestamp])|>
                        df -> rename!(df,  :time_sec => :time_sec_director, :gaze_timestamp => :gaze_timestamp_director)
    matcher_gps = read_surfaces(matcher, session, "gaze_positions_on_surface") |>
                        df -> select!(df, [ :time_sec, :world_index, :surface,  :gaze_timestamp])
    #world index is the number of the closest video DataFrame
    joint_attention = innerjoin(matcher_gps,director_gps, on = [:world_index, :surface] )
    return joint_attention
end

#write face visibility

function get_and_reannotate_words(set, session, root_folder="/Users/varya/Desktop/Julia/Roberts ET data/Dyaden_Analyse")    
    conditions = Dict([("01","11"),("02","12"), ("03", "21"), ("04" ,"22")])
    condition = conditions[session]
    words_folder = joinpath( root_folder, set,"audio",session)
    try
        CSV.read(joinpath(words_folder, "words_$set"*"_$condition.csv"), DataFrame) 
    catch e
        println("No audio file: set: $set session: $session: ")
        return DataFrame()
    end

    words = CSV.read(joinpath(words_folder, "words_$set"*"_$condition.csv"), DataFrame) 
    target_words = filter(row -> !ismissing(row.pos) , words)|>
    df -> rename!(df, names(df) .=> ["line","tmin","text","tmax","condition", "face",	"set", "pattern","pos"]) |>
    df -> filter!(row -> row.pos == "N", df)  |>
    df -> transform!(df, :text => ByRow(lowercase) => :text) |>
    df -> transform!(df, :tmin => ByRow(x -> round(x/10000000, digits=7)) => :time)|>
    df -> select!(df, :text, :time, :face)

    #delete consequent movements of the same object
    for i in nrow(target_words):-1:2
        if target_words.text[i] == target_words.text[i-1]
            delete!(target_words,i)
        end
    end
    return target_words
end



function get_set_fixations_for_nouns(set)
    #set= "04" #for testing
    words_sessions = ["01", "02", "03","04"]
    surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])
    fixations_for_set = DataFrame(
        world_timestamp = Float64[],
        world_index = Int[],
        fixation_id = Int[],
        start_timestamp = Float64[],
        duration = Float64[],
        dispersion = Float64[],
        norm_pos_x = Float64[],
        norm_pos_y = Float64[],
        x_scaled = Float64[],
        y_scaled = Float64[],
        on_surf = Bool[],
        time_sec = Float64[],
        surface = String[],
        participant = String[],
        session = String[],
        noun = String[],
        face = String[],
        frame_number = Int[],
        set = String[]
    )
    nouns_for_set = 0
    for session in words_sessions
        #session = "02" #for testing
        if size(get_and_reannotate_words(set, session))[1]==0
            println("No data for the words for this session: $session")
            continue
        end
        nouns = get_and_reannotate_words(set, session)
        surface_session = surface_sessions[session]
        matcher_fixations = read_surfaces("$set"*"_01", surface_session, "fixations_on_surface")
        #CSV.write("matcher_fixations.csv", matcher_fixations)
        if size(matcher_fixations)[1]==0
            println("No data for the matcher for this session: $session")
            continue
        end

        director_fixations = read_surfaces("$set"*"_02", surface_session, "fixations_on_surface")
        if size(director_fixations)[1]==0
            println("No data for the director for this session: $session, will only take data from the matcher")
            set_fixations = matcher_fixations
        else
            set_fixations = vcat(matcher_fixations, director_fixations)
        end
        #CSV.write("set_fixations.csv", set_fixations)
        # find all fixations that are -1 sec from the noun and up to +2 sec from the noun
        nouns_for_set += size(nouns)[1]
        #it was 1 second before ad 2 seconds after, but in two seconds they can switch to another object already
        # even 0.5 seconds is too much
        nouns.time_windows = [(noun.time - 0.2, noun.time + 0.5) for noun in eachrow(nouns)]
        println(size(nouns.time_windows)," time windows", " set $set session $session")
        fixations_for_nouns = DataFrame(
            world_timestamp = Float64[],
            world_index = Int[],
            fixation_id = Int[],
            start_timestamp = Float64[],
            duration = Float64[],
            dispersion = Float64[],
            norm_pos_x = Float64[],
            norm_pos_y = Float64[],
            x_scaled = Float64[],
            y_scaled = Float64[],
            on_surf = Bool[],
            time_sec = Float64[],
            time_corrected = Float64[],
            lag = Float64[],
            surface = String[],
            participant = String[],
            session = String[],
            noun = String[],
            face = String[],
            frame_number = Int[]
        )
        for noun in eachrow(nouns)
            println("set $set session $session Noun: ", noun.text)
            start_time, end_time = noun.time_windows
            fixations_in_window = filter(row -> row.time_corrected >= start_time && row.time_corrected <= end_time, set_fixations)
            if size(fixations_in_window)[1]==0
                println("No fixations in the period, only gazes: start $start_time end $end_time")
                nouns_for_set -= 1
                continue
            end
            #noun onset and face visibility and the frame number for the minimum time of the tuple
            fixations_in_window.noun = fill(noun.text, nrow(fixations_in_window))
            fixations_in_window.face = fill(noun.face, nrow(fixations_in_window))
            frame_number = minimum(fixations_in_window[!, :world_index])
            fixations_in_window.frame_number = fill(frame_number,nrow(fixations_in_window))
            fixations_for_nouns = vcat(fixations_for_nouns, fixations_in_window)
        end
        fixations_for_nouns.set = fill(set, nrow( fixations_for_nouns))
        fixations_for_set = vcat(fixations_for_set, fixations_for_nouns)
        #CSV.write("fixations_for_nouns.csv", fixations_for_nouns)
    end
    println("Nouns for set $set: ", nouns_for_set)
        return  fixations_for_set
end


function read_timestamps_from_xdf(setting::String, root_folder::String="/Users/varya/Desktop/Julia/DGAME data/xdf")
    sessions = Dict([("11","01"),("12","02"), ("21", "03"), ("22" ,"04")])
    director_files = readdir(joinpath(root_folder,  setting, "Director"))
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

function get_all_timestamps_xdf(sets, root_folder="/Users/varya/Desktop/Julia/DGAME data")
    timestamps_xdf = DataFrame(:set => String[], :session => String[],:stream => String[], :created => Float64[], :first_timestamp => Float64[], :last_timestamp => Float64[], :diff => Float64[], :duration => Float64[])
    for set in sets
        timestamps_xdf = vcat(timestamps_xdf,read_timestamps_from_xdf(set))
    end
    # Define a function that converts a float to an integer
    float_to_int(x::Float64) = trunc(Int, x)
    transform!(timestamps_xdf, names(timestamps_xdf, Float64) .=> (x -> x .* 1000) .=> names(timestamps_xdf, Float64))
    # Apply this function to each float column in the DataFrame
    transform!(timestamps_xdf, names(timestamps_xdf, Float64) .=>  (x -> float_to_int.(x)) .=> names(timestamps_xdf, Float64))
    #lot's of data missing for the director
    CSV.write(joinpath(root_folder, "timestamps_xdf.csv"), timestamps_xdf)
    return timestamps_xdf
end

function get_all_timestamps_json(sets, root_folder="/Users/varya/Desktop/Julia/DGAME data")
    #now get all timestampd from .json files
    timestamps_json = DataFrame(:set => String[], :session => String[], :stream => String[], :first_timestamp => Float64[],  :duration => Float64[])
    for set in sets
        director = set*"_02"
        matcher = set*"_01"
        for session in ["01", "02", "03", "04"]
            start_time_synced_s_dir = get_json_timestamp(director, session)
            if start_time_synced_s_dir == Dict()
                println("No json file for $set for this session: $session")
                continue
            else
                start_time_synced_s_dir, duration_dir = get_json_timestamp(director, session)
            end
            push!(timestamps_json, (set, session,"ET_DESKTOP-5B8EI51", start_time_synced_s_dir, duration_dir))
            start_time_synced_s_matcher = get_json_timestamp(matcher, session)
            if start_time_synced_s_matcher == Dict()
                println("No json file for $set for this session: $session")
                continue
            else
                start_time_synced_s_matcher, duration_matcher = get_json_timestamp(matcher, session)
            end
            push!(timestamps_json, (set, session,"ET_idslexp", start_time_synced_s_matcher, duration_matcher))
        end
    end
    float_to_int(x::Float64) = trunc(Int, x)
    transform!( timestamps_json, names(timestamps_json, Float64) .=> (x -> x .* 1000) .=> names(timestamps_json, Float64))
    # Apply this function to each float column in the DataFrame
    transform!( timestamps_json, names( timestamps_json, Float64) .=>  (x -> float_to_int.(x)) .=> names(timestamps_json, Float64))
    CSV.write(joinpath(root_folder, "timestamps_ET.csv"), timestamps_json)
    return timestamps_json
end

function get_lag_ET(reprocess="no",root_folder="/Users/varya/Desktop/Julia/DGAME data")
    #call the functions to refresf the data
    if reprocess == "yes"
        sets = ["04", "05", "06", "07", "08", "10", "11", "12"]
        get_all_timestamps_xdf(sets)
        get_all_timestamps_json(sets)
    end
        ET_xdf = CSV.read(joinpath(root_folder, "timestamps_xdf.csv"), DataFrame)|>
        df -> rename!(df, :first_timestamp => :first_timestamp_xdf)|>
        df -> rename!(df, :duration => :duration_xdf)|>
        df -> filter!(row -> row.stream != "audio", df)

        json = CSV.read(joinpath(root_folder, "timestamps_ET.csv"), DataFrame)

        lag = innerjoin(ET_xdf, json, on = [:set, :session, :stream]) 
        transform!(lag, [:first_timestamp_xdf, :first_timestamp] => ByRow((x,y) -> (x - y)/1000) => :lag_timestamp)
        transform!(lag, [:duration, :duration_xdf] => ByRow((x,y) -> (x - y)/1000) => :lag_duration)
        
    CSV.write("/Users/varya/Desktop/Julia/DGAME data/lag_data.csv", lag)   
    return lag 
end
get_lag_ET()
