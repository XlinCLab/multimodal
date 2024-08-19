#functions

# using Pkg
# Pkg.add("XDF")
# Pkg.add("EzXML")
# Pkg.add("XMLDict")
#Pkg.add("JSON")
#Pkg.add("LinearAlgebra")
#Pkg.add("TextParse")
#Pkg.add("MsgPack")
using FileIO
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
using CairoMakie
using Images

# functions that create aggregated tables with timestamps, lags and coordinates
function get_json_timestamp(participant, session, root_folder=root_folder)
    surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])
    surface_session = surface_sessions[session]
    session_file = joinpath(root_folder, "DGAME3_$participant", "$surface_session", "info.player.json")
    println(session_file)
    try
        JSON.parsefile(session_file)
    catch e
        println("No json file for $participant for this session: $session")
        return (0,0)
    end
    info= JSON.parsefile(session_file)
    start_time_synced_s = info["start_time_synced_s"]
    duration = info["duration_s"]
    return (start_time_synced_s, duration)
end

function read_timestamps_from_xdf(setting::String, root_folder::String="")
    if root_folder==""
        root_folder="/Users/varya/Desktop/Julia/DGAME data/xdf"
    end
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

function get_all_timestamps_xdf(sets, root_folder)
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

function get_all_timestamps_json(sets, root_folder=root_folder)
    #now get all timestamps from .json files
    timestamps_json = DataFrame(:set => String[], :session => String[], :stream => String[], :first_timestamp => Float64[],  :duration => Float64[])
    for set in sets
        director = set*"_02"
        matcher = set*"_01"
        for session in ["01", "02", "03", "04"]
            start_time_synced_s_dir, duration_dir = get_json_timestamp(director, session)
            if start_time_synced_s_dir == 0
                println("No json file for $set for this session: $session")
                continue
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

function get_lag_ET(reprocess="no",root_folder=root_folder)
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
        
    CSV.write("$root_folder/lag_data.csv", lag)   
    return lag 
end

function get_all_yolo_coordinates(labels_folder)
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
                set=replace(split(file, "_")[1], "set" => "")
                if length(split(file, "_"))>2
                    session=replace(split(file, "_")[3],"session" => "")
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

#functions that read words, gazes, fixations and create a framelist with tokens

function read_surfaces(participant, session, data_type = "fixations_on_surface", root_folder=root_folder)
    surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])  
    participant_folder = joinpath(root_folder, "DGAME3_$participant", "$session", "exports")
    lag_data= DataFrame()
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
            lag_data = select!(lag_data, [:stream, :lag_duration, :lag_timestamp, :first_timestamp_xdf])
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
    lag_zero = lag_data.first_timestamp_xdf[1]/1000
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
        if size(surface_files)[1]==0
            println("No data for $participant for this session: $session")
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
        n_of_fixations = size(fixations_positions)[1]
        println("Data for $participant for this session: $n_of_fixations fixations ($data_type)")
        return fixations_positions
end

function get_frames_from_fixations(all_fixations)
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
        row.video_path = joinpath(root_folder, "DGAME data/DGAME3_"*row.participant, session , "world.mp4")
    end
    return frame_numbers
end

#functions that add times of words

function get_and_reannotate_words(set, session, root_folder=root_folder)    
    conditions = Dict([("01","11"),("02","12"), ("03", "21"), ("04" ,"22")])
    condition = conditions[session]
    words_folder = joinpath( root_folder, set,"Wortlisten")
    try
        CSV.read(joinpath(words_folder, "words_$set"*"_$condition.csv"), DataFrame) 
    catch e
        println("No audio file: set: $set session: $session: ")
        return DataFrame()
    end

    words = CSV.read(joinpath(words_folder, "words_$set"*"_$condition.csv"), DataFrame) 
    target_words = filter(row -> !ismissing(row.pos) , words)|>
    df -> rename!(df, names(df) .=> ["line","tmin","text","tmax","condition", "face", "set", "pattern","pos"]) |>
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

function get_set_fixations_for_nouns(set::String, root_folder=root_folder, data_type = "fixations_on_surface")
    if data_type == "fixations_on_surface"
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
            set = String[],
            time_corrected = Float64[],
            lag = Float64[],
            noun_time = Float64[]
        )
    elseif data_type == "gaze_positions_on_surface"
        fixations_for_set = DataFrame(
            world_timestamp = Float64[],
            world_index = Int[],
            gaze_timestamp = Float64[],
            x_norm = Float64[],
            y_norm = Float64[],
            x_scaled = Float64[],
            y_scaled = Float64[],
            on_surf = Bool[],
            confidence = Float64[],
            time_sec = Float64[],
            surface = String[],
            participant = String[],
            session = String[],
            noun = String[],
            face = String[],
            frame_number = Int[],
            set = String[],
            time_corrected = Float64[],
            lag = Float64[],
            noun_time = Float64[]
        )
    else
        println("wrong data type, choose fixations_on_surface or gaze_positions_on_surface")
        return DataFrame()
    end
    words_sessions = ["01", "02", "03","04"]
    surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])

    nouns_for_set = 0
    for session in words_sessions
        #session = "02" #for testing
        nouns = get_and_reannotate_words(set, session)
        if size(nouns)[1]==0
            println("No data for the words for this session: $session")
            continue
        end
        
        surface_session = surface_sessions[session]
        if data_type == "fixations_on_surface"
            matcher_fixations = read_surfaces("$set"*"_01", surface_session, "fixations_on_surface")
            director_fixations = read_surfaces("$set"*"_02", surface_session, "fixations_on_surface")
        elseif data_type == "gaze_positions_on_surface"
            matcher_fixations = read_surfaces("$set"*"_01", surface_session, "gaze_positions_on_surface")
            director_fixations = read_surfaces("$set"*"_02", surface_session, "gaze_positions_on_surface")
        else
            println("wrong data type, choose fixations_on_surface or gaze_positions_on_surface")
            return DataFrame()
        end
        
        if size(matcher_fixations)[1]==0
            println("No data for the matcher for this session: $session")
            continue
        elseif size(director_fixations)[1]==0
            println("No data for the director for this session: $session, will only take data from the matcher")
            set_fixations = matcher_fixations
        else
            set_fixations = vcat(matcher_fixations, director_fixations)
        end
        #CSV.write("set_fixations.csv", set_fixations)
        # find all fixations that are -1 sec from the noun and up to +2 sec from the noun
        nouns_for_set += size(nouns)[1]
        #it was 1 second before ad 2 seconds after, but in two seconds they can switch to another object already
        nouns.time_windows = [(noun.time - 1, noun.time - 0.2, noun.time + 1) for noun in eachrow(nouns)]
        println(size(nouns.time_windows)," time windows", " set $set session $session")
        #set fixations for nouns as an empty dataset of the same structure
        fixations_for_nouns = fixations_for_set
        for noun in eachrow(nouns)
            start_time, frame_time, end_time = noun.time_windows

            #this is an adaptation for Robert's thesis, delete later
            #println("Noun: ", noun.text, " time: ", noun.time, "start_time: ", start_time, "end_time: ", end_time)
            fixations_in_window = filter(row -> row.time_corrected >= frame_time && row.time_corrected <= end_time, set_fixations)
            if size(fixations_in_window)[1]==0
                println("No fixations in the period: frame_time $frame_time end $end_time")
                nouns_for_set -= 1
                continue
            end
            frame_number = minimum(fixations_in_window[!, :world_index])
            fixations_in_window = filter(row -> row.time_corrected >= start_time && row.time_corrected <= end_time, set_fixations)            
            #noun onset and face visibility and the frame number for the minimum time of the tuple
            fixations_in_window.noun = fill(noun.text, nrow(fixations_in_window))
            fixations_in_window.face = fill(noun.face, nrow(fixations_in_window))
            fixations_in_window.set = fill(set, nrow(fixations_in_window))
            fixations_in_window.noun_time = fill(noun.time, nrow(fixations_in_window))
            fixations_in_window.frame_number = fill(frame_number,nrow(fixations_in_window))
            fixations_for_nouns = vcat(fixations_for_nouns, fixations_in_window)
        end
        fixations_for_set = vcat(fixations_for_set, fixations_for_nouns)
        println("Fixations in the session $session:")
        println(size(fixations_for_set))
    end
    println("Nouns for set $set: ", nouns_for_set)
        return  fixations_for_set
end

function check_april_tags_for_frames(frames)
    if isempty(frames)
        frames = CSV.read("frame_numbers_with_tokens.csv", DataFrame) |>
        df -> transform!(df, :participant => ByRow(x-> x[1:2]) => :set) |>
        df -> transform!(df, :session => ByRow(x-> lpad(x, 2, "0")) => :session)
        frames.new_frame_number = zeros(Int,size(frames, 1))
    else
        frames.new_frame_number = zeros(Int,size(frames, 1))
    end
    videos = unique(frames.video_path)
    for video in videos
        surfaces_folder = joinpath(replace(video, "world.mp4" => ""),"exports")
        if !isdir(surfaces_folder)
            println(surfaces_folder)
            println("No surfaces for this session: $video")
            continue
        end
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

#functions that perform perspective transformation and assigne surfaces to object for every given moment (frame)

function get_all_surface_matrices_for_frames(frames=DataFrame())
    if isempty(frames)
        frames=CSV.read(joinpath(root_folder,"frame_numbers_corrected_with_tokens.csv"), DataFrame) 
        println("frames read from file")
    end
    frames_sets_and_sessions =  select(frames, [:participant, :session, :new_frame_number]) |> unique |>
        df -> transform!(df, :new_frame_number => ByRow(x-> x) => :frame_number)
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
        surface_coordinates = get_surface_matrices(participant,surface_session,frame_numbers)
        surface_coordinates.set = fill(set, nrow(surface_coordinates))
        surface_coordinates.session = fill(session, nrow(surface_coordinates))
        all_surface_coordinates = vcat(all_surface_coordinates, surface_coordinates)
    end
    CSV.write("all_surface_matrices.csv", all_surface_coordinates)
    return all_surface_coordinates
end

function get_surface_matrices(participant,session,framenumbers, root_folder=root_folder)
    #CSV.read cannot parse nested lists of coordinates
    #!NB this function does not return set and session
    #NB! this function does not check for markers detected
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
    result_homogenous .= result_homogenous ./ result_homogenous[end]  # normalize
    new_pos = result_homogenous[1:end-1]  # projection
    return new_pos[1], new_pos[2]
end

#this is the function that is used to calculate surfaces to world
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

function get_gazes_and_fixations_by_frame_and_surface(all_frame_objects, all_trial_surfaces_gazes, all_trial_surfaces_fixations, gazes_file="", fixations_file="")
    #get the gazes and fixations for the surface
    surfaces = rename(all_frame_objects, :object => :token, :surface_number => :surface) |>
    df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set) |>
    df -> transform(df, :session =>ByRow(x-> lpad(x, 2, "0")) => :session)

    if isempty(all_trial_surfaces_gazes) && gazes_file != ""
        gazes = CSV.read(gazes_file, DataFrame) |>
        df -> rename(df, :noun => :token) |>
        df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set) 
    else
        gazes =  rename(all_trial_surfaces_gazes, :noun => :token) |>
        df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set) 
    end
    if isempty(all_trial_surfaces_fixations) && fixations_file != ""
        fixations = CSV.read(fixations_file, DataFrame) |>
        df -> rename(df, :object => :token) |>
        df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set) 
    else
        fixations = rename(all_trial_surfaces_fixations, :noun => :token) |>
        df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set)
    end
    target_gazes = innerjoin(gazes, surfaces, on = [:frame_number, :set, :session, :token, :surface])
    target_fixations = innerjoin(fixations, surfaces, on = [:frame_number, :set, :session, :token, :surface])
    return target_gazes, target_fixations
end

function get_all_gazes_and_fixations_by_frame(sets)
    all_gazes = DataFrame()
    all_fixations = DataFrame()
    for set in sets
        fixations = get_set_fixations_for_nouns(set)
        gazes = get_set_fixations_for_nouns(set, "","gaze_positions_on_surface")
        all_gazes = vcat(all_gazes, gazes)
        all_fixations = vcat(all_fixations, fixations)
    end
    all_fixations.trial_time = [fixation.time_corrected - fixation.noun_time for fixation in eachrow(all_fixations)]
    all_gazes.trial_time = [gaze.time_corrected - gaze.noun_time for gaze in eachrow(all_gazes)]
    CSV.write("all_trial_gazes.csv", all_gazes)
    CSV.write("all_trial_fixations.csv", all_fixations)
    return all_gazes, all_fixations
end

function pixel_center_and_flip(x, y, img_width, img_height)
    # Assuming x and y are in pixel center coordinates
    # Flip horizontally
    new_x = img_width - x - 1
    # Flip vertically
    new_y = img_height - y - 1
    
    return x, new_y
end
function get_surfaces_for_all_objects(yolo_coordinates, surface_positions, root_folder, frames_corrected,image_sizes)
    if isempty(frames_corrected)
        frames_corrected=CSV.read(joinpath(root_folder,"frame_numbers_corrected_with_tokens.csv"), DataFrame) 
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
    if isempty(image_sizes)
        image_sizes = CSV.read(joinpath(root_folder,"image_sizes.csv"), DataFrame) 
        println("image_sizes read from file")
    end
    #depending of if we have image sizes and yolo_coordinates in memory or from file#set can be integer or string
    #let's make it string

    if typeof(yolo_coordinates.set[1]) == Int64
        yolo_coordinates.set = lpad.(string.(yolo_coordinates.set), 2, '0')
        yolo_coordinates.session = lpad.(string.(yolo_coordinates.session), 2, '0')
    end
    if typeof(image_sizes.set[1]) == Int64
        image_sizes.set = lpad.(string.(image_sizes.set), 2, '0')
        image_sizes.session = lpad.(string.(image_sizes.session), 2, '0')
    end
    if typeof(frames_corrected.session[1]) == Int64
        frames_corrected.session = lpad.(string.(frames_corrected.session), 2, '0')
    end
    # now make a file with a map - frame,object,surface
    #assume, we have all the GOOD frames - with 6 April tages recognized
    all_frame_objects = DataFrame()
    for frame in eachrow(frames_corrected)
        #frame=eachrow(frames_corrected)[2433]
        set = frame.participant[1:2]
        current_size= filter(row -> row[:frame_number] == frame.new_frame_number && row[:set] == set && row[:session] == frame.session, image_sizes)
        if isempty(current_size)
            println("No image size for frame: $(frame.new_frame_number)")
            continue
        end
        img_width, img_height = current_size.image_width[1], current_size.image_height[1]
        
        frame_objects = filter(row -> row[:frame_number] == frame.new_frame_number && row[:set] == set && row[:session] == frame.session, yolo_coordinates)
        if isempty(frame_objects)
            println("No object coordinates for frame: $(frame.new_frame_number)")
            continue
        end
        frame_surfaces = filter(row -> row[:world_index] == frame.new_frame_number && row[:set] == set && row[:session] == frame.session && row[:surface] != "face", surface_positions)
        frame_object_with_surfaces = get_surface_for_frame_objects(frame_objects, frame_surfaces, img_width, img_height)
        frame_object_with_surfaces.corected_frame_number = fill(frame.new_frame_number, nrow(frame_object_with_surfaces))
        frame_object_with_surfaces.frame_number = fill(frame.frame_number, nrow(frame_object_with_surfaces))
        all_frame_objects = vcat(all_frame_objects, frame_object_with_surfaces)

    end
    CSV.write("all_frame_objects_surfaces.csv", all_frame_objects)
    return all_frame_objects
end

function get_surface_for_frame_objects(frame_objects, frame_surfaces, img_width, img_height)
    #this function is work in progress
    # Select the relevant row based on world_index (frame number)
    corners = [0.0 0.0; 1.0 0.0; 1.0 1.0; 0.0 1.0]
    center = [0.5, 0.5]
    frame_objects.surface_number = fill("outside all", nrow(frame_objects))
    for object in eachrow(frame_objects)
        object.x, object.y, object.w, object.h =  transform_yolo_to_pixels(object.x, object.y, object.w, object.h,img_width, img_height)
        println("Object: $(object.object), x: $(object.x), y: $(object.y)")
        for surface in eachrow(frame_surfaces)
            # Extract the transformation matrix
            surf_to_img_trans = parse_transformation_matrix(surface.surf_to_dist_img_trans)
            surface_corners = transform_surface_corners(corners, surf_to_img_trans)
            surface_center = transform_surface_to_image_coordinates(center[1], center[2], surf_to_img_trans)
                #println("Surface $(surface.surface) center:")
                 #println("x: $(surface_center[1]), y: $(surface_center[2])")
            #check if object is inside the surface
            min_x, max_x, min_y, max_y = minimum(surface_corners[:, 1]), maximum(surface_corners[:, 1]), minimum(surface_corners[:, 2]), maximum(surface_corners[:, 2])
            if object.x >= min_x && object.x <= max_x && object.y >= min_y && object.y <=max_y
                object.surface_number = surface.surface
                println("Object is inside surface: $(surface.surface)")
                continue
            end
        end
             #if an object center is outside all, try lower center
        if object.surface_number == "outside all" 
            for surface in eachrow(frame_surfaces)
                object_y = object.y + object.h/2
                surf_to_img_trans = parse_transformation_matrix(surface.surf_to_dist_img_trans)
                surface_corners = transform_surface_corners(corners, surf_to_img_trans)
                min_x, max_x, min_y, max_y = minimum(surface_corners[:, 1]), maximum(surface_corners[:, 1]), minimum(surface_corners[:, 2]), maximum(surface_corners[:, 2])
                println("Surface $(surface.surface) limits:")
                println("min_x: $min_x, max_x: $max_x, min_y: $min_y, max_y: $max_y")
                if object.x >= min_x && object.x <= max_x && object_y >= min_y && object_y <=max_y
                    object.surface_number = surface.surface
                    println("Object is inside surface: $(surface.surface)")
                    continue
                end
            end
        end

        #if lower center does not work, try upper center
        if object.surface_number == "outside all"
            for surface in eachrow(frame_surfaces)
                object_y = object.y - object.h/2
                surf_to_img_trans = parse_transformation_matrix(surface.surf_to_dist_img_trans)
                surface_corners = transform_surface_corners(corners, surf_to_img_trans)
                if object.x > minimum(surface_corners[:, 1]) && object.x < maximum(surface_corners[:, 1]) && object_y > minimum(surface_corners[:, 2]) && object_y < maximum(surface_corners[:, 2])
                    object.surface_number = surface.surface
                    println("Object is inside surface: $(surface.surface)")
                    continue
                end
            end
        end
    end
    return frame_objects
end

function transform_yolo_to_pixels(x,y,w,h,img_width,img_height)
    new_x = x*img_width
    new_w = w*img_width
    new_y = y*img_height
    new_h = h*img_height
    return new_x, new_y, new_w, new_h
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
        println(indent * prefix * entry)
        
        # If the entry is a directory, recursively print its contents
        full_path = joinpath(path, entry)
        if isdir(full_path)
            new_indent = indent * (is_last ? "    " : "│   ")
            print_folder_structure(full_path, new_indent)
        end
    end
end
function get_all_surfaces_for_a_frame(frame_number, set_surface_positions, write_to_file=false)
    #this function is work in progress
    img_width = 1024
    img_height = 768

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

#additional utiliies to plot surfaces and see if something is wrong 
#note: CairoMakie flips the background image for whatever reason
function plot_surfaces(surface_coordinates, img_width, img_height, background_image_path)
    img = FileIO.load(background_image_path)
    img = rotl90(img)
    # Create a figure and axis for plotting with specified resolution
    fig = Figure(resolution = (img_width, img_height))
    ax = Axis(fig[1, 1])
    # Set the image as the background
    image!(ax, img, scale_to_fit=true, align = (0, 0))
    xlims!(ax, 0, img_width)
    ylims!(ax, img_height, 0)
    # Plot each surface
    for surface in surface_coordinates
        surface_name = surface[1]
        println("Plotting surface: $surface_name, with corners: ")
        println(surface[2])
        surface_corners = surface[2]
        # Extracting the first two elements from each 4-element tuple and converting to Point2f
        preprocessed_coords = [(row[1], row[2])  for row in eachrow(surface_corners)]
        poly!(ax, Point2f.(preprocessed_coords), color = :transparent, strokecolor = :black, strokewidth = 1)
    end
    # Display the figure
    display(fig)
end

function collect_image_dimensions(recognized_images_folder_path::String)
    # Get a list of all files in the folder
    files = filter(f -> occursin(r"\.jpg$", f), readdir(recognized_images_folder_path, join=true))
    # Initialize an empty DataFrame
    image_sizes = DataFrame(
        frame_number = Int[],
        set = String[],
        session = String[],
        image_width = Int[],
        image_height = Int[]
    )
 for file in files
        filename = basename(file)
        frame_number = parse(Int, split(filename, "_")[end] |> x -> split(x, ".")[1])
        set=replace(split(filename, "_")[1], "set" => "")
        if length(split(filename, "_"))>2
            session=replace(split(filename, "_")[3],"session" => "")
        else
            session="0"
        end

        try
            # Load the image
            img = load(file)
            # Check if the file is an image
                # Get the dimensions of the image
                width, height = size(img)[2], size(img)[1]
                # Append the information to the DataFrame
                push!(image_sizes, (frame_number,set,session, width, height))
        catch e
            # Handle the case where the file is not an image
            println("Skipping file $file: $e")
        end
    end
    CSV.write("/Users/varya/Desktop/Julia/image_sizes.csv", image_sizes)
    return image_sizes
end

#additional utilities to get joint attention

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

#additional utilities to get camera parameters
function read_intrinsics(file_path)
    binary_content = read_binary_file(file_path)
    data = MsgPack.unpack(binary_content)
    return data
end