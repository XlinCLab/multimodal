#functions

# import Pkg
# using Pkg
# Pkg.add("XDF")
# Pkg.add("EzXML")
# Pkg.add("XMLDict")
# Pkg.add("JSON")
# Pkg.add("LinearAlgebra")
# Pkg.add("TextParse")
# Pkg.add("MsgPack")
# Pkg.add("FileIO")
# Pkg.add("DataFrames")
# Pkg.add("CSV")
# Pkg.add("CairoMakie")
# Pkg.add("Images")
# Pkg.add("YAML")
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
using Logging
using YAML


function write_results_csv(results, dir, outcsv, label = ""; out=stdout)
    logger = out === stdout ?
        ConsoleLogger(out, Logging.Info) :
        SimpleLogger(out, Logging.Info)
    with_logger(logger) do
        outcsv = joinpath(dir, outcsv)
        CSV.write(outcsv, results)
        if label != ""
            @info "Wrote $label to $outcsv"
        else
            @info "Wrote $outcsv"
        end
    end
end


pad2zero(obj) = lpad.(string.(obj), 2, '0')


# functions that create aggregated tables with timestamps, lags and coordinates
function get_json_timestamp(participant, session, root_folder=root_folder)
    surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])
    surface_session = surface_sessions[session]
    session_file = joinpath(root_folder, "DGAME3_$participant", "$surface_session", "info.player.json")
    @info "Parsing timestamps from $session_file"
    try
        JSON.parsefile(session_file)
    catch e
        @error "No json file for participant <$participant> for session <$session>"
        return (0,0)
    end
    info = JSON.parsefile(session_file)
    start_time_synced_s = info["start_time_synced_s"]
    duration = info["duration_s"]
    return (start_time_synced_s, duration)
end

function read_timestamps_from_xdf(setting::String, root_folder=root_folder)
    root_folder=joinpath(root_folder,"xdf")
    sessions = Dict([("11","01"),("12","02"), ("21", "03"), ("22" ,"04")])  # condition to session mapping
    director_files = readdir(joinpath(root_folder,  setting, "Director"))
    timestamps = DataFrame(:set => String[], :session => String[],:stream => String[], :created => Float64[], :first_timestamp => Float64[], :last_timestamp => Float64[])
    for file in director_files
        try
            sessions[file[end-5:end-4]]
        catch e
            @warn "No session found for $file or file is irrelevant"
            continue
        end
        session = sessions[file[end-5:end-4]]
        @info "Extracting timestamps from xdf file: $file"
        exp_set = read_xdf(joinpath(joinpath(root_folder, setting, "Director"),file))
        # Extract the timestamps from the XDF file
        # the numbers of streams are random in terms of what is the contents
        # so we have to check the contents of the streams by name
        for i in eachindex(exp_set)
            @debug "" name=exp_set[i]["name"]
            name = exp_set[i]["name"]
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

function get_all_timestamps_xdf(sets, root_folder=root_folder; out=stdout)
    logger = out === stdout ?
        ConsoleLogger(out, Logging.Info) :
        SimpleLogger(out, Logging.Info)
    timestamps_xdf = DataFrame(:set => String[], :session => String[],:stream => String[], :created => Float64[], :first_timestamp => Float64[], :last_timestamp => Float64[], :diff => Float64[], :duration => Float64[])
    with_logger(logger) do
        for set in sets
            @info "Extracting timestamps from xdf files in set <$set>"
            timestamps_xdf = vcat(timestamps_xdf,read_timestamps_from_xdf(set, root_folder))
        end
        # Define a function that converts a float to an integer
        float_to_int(x::Float64) = trunc(Int, x)
        transform!(timestamps_xdf, names(timestamps_xdf, Float64) .=> (x -> x .* 1000) .=> names(timestamps_xdf, Float64))
        # Apply this function to each float column in the DataFrame
        transform!(timestamps_xdf, names(timestamps_xdf, Float64) .=>  (x -> float_to_int.(x)) .=> names(timestamps_xdf, Float64))
    end
    return timestamps_xdf
end

function get_all_timestamps_json(sets, root_folder=root_folder; out=stdout)
    # extract all timestamps from .json files
    logger = out === stdout ?
        ConsoleLogger(out, Logging.Info) :
        SimpleLogger(out, Logging.Info)
    timestamps_json = DataFrame(:set => String[], :session => String[], :stream => String[], :first_timestamp => Float64[],  :duration => Float64[])
    with_logger(logger) do
        for set in sets
            @info "Extracting timestamps from jsons for set <$set>"
            director = set * "_02"
            matcher = set * "_01"
            for session in ["01", "02", "03", "04"]
                start_time_synced_s_dir, duration_dir = get_json_timestamp(director, session, root_folder)
                if start_time_synced_s_dir == 0
                    @error "ERROR: No director json file for set <$set> for session <$session>"
                    continue
                end
                push!(timestamps_json, (set, session,"ET_DESKTOP-5B8EI51", start_time_synced_s_dir, duration_dir))
                start_time_synced_s_matcher = get_json_timestamp(matcher, session, root_folder)
                if start_time_synced_s_matcher == Dict()
                    @error "No matcher json file for <$set> for session <$session>"
                    continue
                else
                    start_time_synced_s_matcher, duration_matcher = get_json_timestamp(matcher, session, root_folder)
                end
                push!(timestamps_json, (set, session,"ET_idslexp", start_time_synced_s_matcher, duration_matcher))
            end
        end
        float_to_int(x::Float64) = trunc(Int, x)
        transform!( timestamps_json, names(timestamps_json, Float64) .=> (x -> x .* 1000) .=> names(timestamps_json, Float64))
        # Apply this function to each float column in the DataFrame
        transform!( timestamps_json, names( timestamps_json, Float64) .=>  (x -> float_to_int.(x)) .=> names(timestamps_json, Float64))
    end
    return timestamps_json
end

function get_lag_ET(root_folder=root_folder; out=stdout)
    logger = out === stdout ?
        ConsoleLogger(out, Logging.Info) :
        SimpleLogger(out, Logging.Info)
    lag = DataFrame()
    with_logger(logger) do
        infile_xdf = joinpath(root_folder, "timestamps_xdf.csv")
        @info "Reading xdf timestamps from:" infile_xdf
        ET_xdf = CSV.read(infile_xdf, DataFrame)|>
        df -> rename!(df, :first_timestamp => :first_timestamp_xdf)|>
        df -> rename!(df, :duration => :duration_xdf)|>
        df -> filter!(row -> row.stream != "audio", df)
        
        infile_et = joinpath(root_folder, "timestamps_ET.csv")
        @info "Reading eye-tracker timestamps from:" infile_et
        json = CSV.read(infile_et, DataFrame)

        lag = innerjoin(ET_xdf, json, on = [:set, :session, :stream]) 
        transform!(lag, [:first_timestamp_xdf, :first_timestamp] => ByRow((x,y) -> (x - y)/1000) => :lag_timestamp)
        transform!(lag, [:duration, :duration_xdf] => ByRow((x,y) -> (x - y)/1000) => :lag_duration)
    end
    return lag 
end

function load_object_labels_from_yaml(yaml_path)
    cfg = YAML.load_file(yaml_path)
    names = cfg["names"]
    return Dict(i - 1 => name for (i, name) in enumerate(names))
end

function get_all_yolo_coordinates(labels_folder, yaml_path)
    @info "Loading object labels from $yaml_path"
    object_labels = load_object_labels_from_yaml(yaml_path)
    msg = join(
        ["  class $k => $(object_labels[k])"
        for k in sort(collect(keys(object_labels)))],
        "\n"
    )
    @info "Object IDs and labels:\n$msg"
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
            set = replace(split(file, "_")[1], "set" => "")
            if length(split(file, "_"))>2
                session = replace(split(file, "_")[3],"session" => "")
            else
                session = "0"
            end
            @debug "Extracting YOLO coordinates from $file" frame_number set session
            data = readlines(joinpath(labels_folder, file))
            for line in data
                object = split(line, " ")[1]
                object = object_labels[parse(Int, object)]
                x = parse(Float64, split(line, " ")[2])
                y = parse(Float64, split(line, " ")[3])
                w = parse(Float64, split(line, " ")[4])
                h = parse(Float64, split(line, " ")[5])
                push!(all_yolo_coordinates, (frame_number, set, session, object, x, y, w, h))
            end
        end
    end
    return all_yolo_coordinates
end

#functions that read words, gazes, fixations and create a framelist with tokens

function read_surfaces(participant, session, data_type = "fixations_on_surface", root_folder=root_folder; out=stdout)  # TODO update logging in here
    logger = out === stdout ?
        ConsoleLogger(out, Logging.Info) :
        SimpleLogger(out, Logging.Info)
    fixations_positions = DataFrame()
    with_logger(logger) do
        participant_folder = joinpath(root_folder, "DGAME3_$participant", "$session", "exports")
        lag_data = DataFrame()
        lag_datafile = joinpath(root_folder,"lag_data.csv")
        try 
            CSV.read(lag_datafile, DataFrame)
        catch e
            @error "Lag data file missing or empty" lag_datafile
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
            lag_data = select(lag_data, [:stream, :lag_duration, :lag_timestamp, :first_timestamp_xdf])
        end
        if size(lag_data)[1] == 0
            @error "No lag data for participant <$participant> for session <$session>; times are not aligned"
            return DataFrame()
        end

        lag = lag_data.lag_timestamp[1]
        if  lag < 0
            @error "Check timestamps for participant and session, negative lag found!" lag participant session
            return DataFrame()
        elseif lag > 500
            @warn "Check timestamps for participant and session, unexpectedly large lag found!" lag participant session     
            return DataFrame()
        end
        lag_zero = lag_data.first_timestamp_xdf[1]/1000
        # now process fixations
        try
            readdir(participant_folder)
        catch e
            @error "No data for this participant found in this session" participant session
            return DataFrame()
        end

            subfolders = [f for f in readdir(participant_folder) if isdir(joinpath(participant_folder, f))]
            if subfolders[1] == "surfaces"
                surface_folder = joinpath(participant_folder, subfolders[1])
            else
                surface_folder = joinpath(participant_folder, subfolders[1], "surfaces")
            end
        
            surface_files = [file for file in readdir(surface_folder)if occursin(data_type, file)]
            if size(surface_files)[1] == 0
                @error "No data for this participant found in this session" participant session
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
            normal_sessions = Dict("000" => "01", "001" => "02", "002" => "03", "003" => "04")
            normal_session= normal_sessions[session]
            fixations_positions.participant = fill(participant, nrow(fixations_positions))
            fixations_positions.session = fill(normal_session, nrow(fixations_positions))
            fixations_positions.lag = fill(lag, nrow(fixations_positions))
            n_fixations = size(fixations_positions)[1]
            @info "Participant surface fixation data:" participant n_fixations data_type
        end
        return fixations_positions
end

function get_frames_from_fixations(all_fixations, root_folder=root_folder)
    frame_numbers = select(all_fixations, :frame_number, :participant, :session, :noun, :noun_time)
    frame_numbers = unique!(frame_numbers)
    #take only matcher videos
    frame_numbers = filter(row -> endswith(row.participant, "_01"), frame_numbers)
    frame_numbers.time_sec = [frame.frame_number/30 for frame in eachrow(frame_numbers)]
    frame_numbers.video_path .= ""
    for row in eachrow(frame_numbers)
        session = lpad(row.session,2,"0")
        session = surface_sessions[session]
        row.video_path = joinpath(root_folder, "DGAME3_"*row.participant, session , "world.mp4")
    end
    return frame_numbers
end

#functions that add times of words

function get_and_reannotate_words(set, session, root_folder=root_folder; out=stdout)
    logger = out === stdout ?
        ConsoleLogger(out, Logging.Info) :
        SimpleLogger(out, Logging.Info)
    target_words = DataFrame()
    with_logger(logger) do
        conditions = Dict([("01","11"),("02","12"), ("03", "21"), ("04" ,"22")])
        condition = conditions[session]
        words_folder = joinpath(root_folder, "AUDIO", set, "Wortlisten")
        audio_file = joinpath(words_folder, "words_$set"*"_$condition.csv")
        words = try
            CSV.read(audio_file, DataFrame) 
        catch e
            @error "Expected audio file missing:" audio_file set session
            return DataFrame()
        end
        target_words = filter(row -> !ismissing(row.pos) , words)|>
        df -> rename!(df, names(df) .=> ["line","tmin","text","tmax","condition", "face", "set", "pattern","pos"]) |>
        df -> filter!(row -> row.pos == "N", df)  |>
        df -> transform!(df, :text => ByRow(lowercase) => :text) |>
        df -> transform!(df, :tmin => ByRow(x -> round(x/10000000, digits=7)) => :time)|>
        df -> select!(df, :text, :time, :face)
        object_names_file = joinpath(root_folder, "AUDIO", "Objektbezeichnungen.csv")
        try                 
            words_to_tokens = CSV.read(object_names_file, DataFrame, types=Dict(:subject=>String, :condition=>String)) 
            target_tokens = words_to_tokens |> 
                            df -> rename(df, names(df) .=> strip.(string.(names(df)))) |>
                            row -> filter( row -> row.subject == set && row.condition==condition, row) |>
                            df -> select(df, :name, :token) |>
                            df -> transform(df, :token => ByRow(lowercase) => :token) |>
                            df -> transform(df, :name => ByRow(lowercase) => :name) |>
                            df -> transform(df, :name => ByRow(x -> replace(x, r" " => "")) => :name) |>
                            df -> transform(df, :token => ByRow(x -> replace(x, r"dose" => "creme")) => :token) 

            target_words = leftjoin(target_words, target_tokens , on = :text => :name) |>
            df -> transform!(df, :token => ByRow(row -> ismissing(row) ? missing : row) => :text) |>
            df -> select!(df, :text, :time, :face) |>
            df -> filter!(row -> !ismissing(row.text), df)

        catch e
            @warn "(!) No object names file found! Untokenized transcription will be used, causing significant data loss!" object_names_file
        end

        # Delete consecutive movements of the same object
        for i in nrow(target_words):-1:2
            if target_words.text[i] == target_words.text[i-1]
                delete!(target_words,i)
            end
        end
    end
    return target_words
end


function get_set_fixations_for_nouns(set::String, root_folder, data_type, epoch_start, epoch_end; out=stdout)
    logger = out === stdout ?
        ConsoleLogger(out, Logging.Info) :
        SimpleLogger(out, Logging.Info)
    fixations_for_set = DataFrame()
    with_logger(logger) do
        @debug "Running get_set_fixations_for_noun for set $set and data type $data_type"
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
            @error "Unrecognized data type, use 'fixations_on_surface' or 'gaze_positions_on_surface'" data_type
            return DataFrame()
        end
        words_sessions = ["01", "02", "03", "04"]
        surface_sessions = Dict([("01", "000"), ("02", "001"), ("03", "002"), ("04", "003")])

        nouns_for_set = 0
        for session in words_sessions
            nouns = get_and_reannotate_words(set, session, root_folder; out=out)
            if size(nouns)[1]==0
                @error "No words data for session <$session>; skipping."
                continue
            end
            
            surface_session = surface_sessions[session]
            if data_type == "fixations_on_surface"
                matcher_fixations = read_surfaces("$set"*"_01", surface_session, "fixations_on_surface", root_folder; out=out)
                director_fixations = read_surfaces("$set"*"_02", surface_session, "fixations_on_surface", root_folder; out=out)
            elseif data_type == "gaze_positions_on_surface"
                matcher_fixations = read_surfaces("$set"*"_01", surface_session, "gaze_positions_on_surface", root_folder; out=out)
                director_fixations = read_surfaces("$set"*"_02", surface_session, "gaze_positions_on_surface", root_folder; out=out)
            end
            
            if size(matcher_fixations)[1] == 0
                @error "No matcher data for session <$session>; skipping."
                continue
            elseif size(director_fixations)[1] == 0
                @warn "No director data for session <$session>; data from matcher only will be used."
                set_fixations = matcher_fixations
            else
                set_fixations = vcat(matcher_fixations, director_fixations)
            end
            # find all fixations that are -1 sec from the noun and up to +2 sec from the noun
            nouns_for_set += size(nouns)[1]
            #it was 1 second before ad 2 seconds after, but in two seconds they can switch to another object already
            nouns.time_windows = [(noun.time + epoch_start, noun.time - 0.2, noun.time + epoch_end) for noun in eachrow(nouns)]
            @debug "Time windows:" size=size(nouns.time_windows) set=set session=session
            #set fixations for nouns as an empty dataset of the same structure
            fixations_for_nouns = fixations_for_set
            for noun in eachrow(nouns)
                start_time, frame_time, end_time = noun.time_windows
                fixations_in_window = filter(row -> row.time_corrected >= frame_time && row.time_corrected <= end_time, set_fixations)
                if size(fixations_in_window)[1]==0
                    @warn "No fixations in the period from frame [$frame_time] to end of window [$end_time]; skipping this noun."
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
            @info "Number of fixations in session <$session>:" n_fixations=size(fixations_for_set)
        end
        @info "Numbers of nouns with associated fixations in set <$set>:" nouns_for_set
    end
    return  fixations_for_set
end

function check_april_tags_for_frames(frames; out=stdout)
    logger = out === stdout ?
        ConsoleLogger(out, Logging.Info) :
        SimpleLogger(out, Logging.Info)
    with_logger(logger) do
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
            @info "Processing video $video ..."
            surfaces_folder = joinpath(replace(video, "world.mp4" => ""),"exports")
            if !isdir(surfaces_folder)
                @error "No surfaces found for this session: $video\nExpected location: $surfaces_folder"
                continue
            end
            subfolders = [f for f in readdir(surfaces_folder) if isdir(joinpath(surfaces_folder, f))]
            if subfolders[1] == "surfaces"
                surface_folder = joinpath(surfaces_folder, subfolders[1])
            else
                surface_folder = joinpath(surfaces_folder, subfolders[1], "surfaces")
            end
            data, surf_names = TextParse.csvread(joinpath(surface_folder, "surf_positions_face.csv"))
            april_tags =  DataFrame()
            for (i, surf_name) in enumerate(surf_names)
                april_tags[!, Symbol(surf_name)] = data[i]
            end
            april_tags_dict = Dict(row[:world_index] => row[:num_detected_markers] for row in eachrow(april_tags))
            # Find frame with maximum tags recognized
            # but only before the onset, with 30 fps 200ms is 6 frames
            min_recog_frames_required = 6
            for frame in eachrow(frames)
                frame_number = frame.frame_number
                @debug "Evaluating frame $frame_number..."
                n_tags_recognized = get(april_tags_dict, frame.frame_number, 0)
                if haskey(april_tags_dict, frame.frame_number) && n_tags_recognized >= min_recog_frames_required
                    frame.new_frame_number = frame.frame_number
                    continue
                else
                    @warn "Not enough tags identified in frame number <$frame_number> ($n_tags_recognized/$min_recog_frames_required tags); checking neighboring frames."
                    frame_tags = Dict(
                        key => value for (key, value) in april_tags_dict
                        if key >= frame.frame_number - 10
                            && key <= frame.frame_number + min_recog_frames_required
                    )
                    if isempty(frame_tags)
                        @warn "No suitable neighboring frames to frame <$frame_number>; skipping."
                        frame.new_frame_number = 0
                        continue
                    end
                    # Frames that tie for the maximum number of recognized tags
                    max_tags_recognized = maximum(values(frame_tags))
                    best_candidates = Dict(
                        key => value for (key, value) in frame_tags
                        if value == max_tags_recognized
                    )
                    @debug "Candidate neighboring frames and identified tag counts:" best_candidates
                    
                    # In case of tie, choose the frame closest to the original frame reference
                    new_frame_number = argmin(
                        k -> abs(k - frame.frame_number),
                        keys(best_candidates)
                    )
                    if new_frame_number != frame_number
                        @info "Using neighboring frame <$new_frame_number> with $max_tags_recognized recognized tags"
                    else
                        @warn "Original frame <$frame_number> has more recognized tags than neighboring frames; proceeding with original frame."
                    end
                    frame.new_frame_number = new_frame_number
                end
            end
            
        end
    end
    return frames
end

#functions that perform perspective transformation and assigne surfaces to object for every given moment (frame)

function get_all_surface_matrices_for_frames(frames=DataFrame(), root_folder=root_folder)
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
        participant = row.participant
        set=participant[1:2]
        session = row.session
        surface_session = surface_sessions[lpad(row.session,2,"0")]
        filtered = filter(row -> row.participant == participant && row.session == session, frames_sets_and_sessions)
        frame_numbers = filtered.frame_number
        surface_coordinates = get_surface_matrices(participant, surface_session, frame_numbers, root_folder)
        surface_coordinates.set = fill(set, nrow(surface_coordinates))
        surface_coordinates.session = fill(session, nrow(surface_coordinates))
        all_surface_coordinates = vcat(all_surface_coordinates, surface_coordinates)
    end
    return all_surface_coordinates
end

function get_surface_matrices(participant, session, framenumbers, root_folder=root_folder; out=stdout)
    #CSV.read cannot parse nested lists of coordinates
    #!NB this function does not return set and session
    #NB! this function does not check for markers detected
    data_type = "surf_positions"
    participant_folder = joinpath(root_folder, "DGAME3_$participant", "$session", "exports")
    try
        readdir(participant_folder)
    catch e
        println(out,"No data for $participant for this session: $session")
        println(out,e)
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
        println(out,"No surface coordinates data for $participant for this session: $session")
        println(out,joinpath(surface_folder, "$data_type"*"_face.csv"))
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
    #it looks like transposition brings image coordinate, non-transposed matrix brings normalized image coordinates
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

function get_gazes_and_fixations_by_frame_and_surface(all_frame_objects, all_trial_surfaces_gazes, all_trial_surfaces_fixations; out=stdout)
    # Ensure set and session are both two-character strings, e.g. "01"
    @debug "Standardizing type of set and session to two-character strings..."
    all_frame_objects.set = pad2zero(all_frame_objects.set)
    all_frame_objects.session = pad2zero(all_frame_objects.session)
    all_trial_surfaces_gazes.session = pad2zero(all_trial_surfaces_gazes.session)
    all_trial_surfaces_fixations.session = pad2zero(all_trial_surfaces_fixations.session)
    @debug all_frame_objects.set all_frame_objects.session all_trial_surfaces_gazes.session all_trial_surfaces_fixations.session

    surfaces = rename(all_frame_objects, :object => :token, :surface_number => :surface) |>
    df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set) |>
    df -> transform(df, :session =>ByRow(x-> lpad(x, 2, "0")) => :session)

    gazes =  rename(all_trial_surfaces_gazes, :noun => :token, :frame_number => :gaze_frame_number) |>
    df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set) 

    fixations = rename(all_trial_surfaces_fixations, :noun => :token) |>
    df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set)

    target_gazes = innerjoin(gazes, surfaces, on = [:noun_time, :set, :session, :token, :surface]) 
    target_fixations = innerjoin(fixations, surfaces, on = [:frame_number, :noun_time, :set, :session, :token, :surface])
    return target_gazes, target_fixations
end

function get_all_gazes_and_fixations_by_frame(sets, root_folder, epoch_start, epoch_end; out=stdout)
    logger = out === stdout ?
        ConsoleLogger(out, Logging.Info) :
        SimpleLogger(out, Logging.Info)
    all_gazes = DataFrame()
    all_fixations = DataFrame()
    with_logger(logger) do
        for set in sets
            @info "Processing gaze and fixation data  for set <$set>..."
            fixations = get_set_fixations_for_nouns(set, root_folder, "fixations_on_surface", epoch_start, epoch_end; out)
            gazes = get_set_fixations_for_nouns(set, root_folder, "gaze_positions_on_surface", epoch_start, epoch_end; out)
            all_gazes = vcat(all_gazes, gazes)
            all_fixations = vcat(all_fixations, fixations)
        end
        all_fixations.trial_time = [fixation.time_corrected - fixation.noun_time for fixation in eachrow(all_fixations)]
        all_gazes.trial_time = [gaze.time_corrected - gaze.noun_time for gaze in eachrow(all_gazes)]
    end
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

function get_surfaces_for_all_objects(yolo_coordinates, surface_positions, frames_corrected, image_sizes; out=stdout)
    # Ensure set and session are both two-character strings, e.g. "01"
    @debug "Standardizing type of set and session to two-character strings..."
    yolo_coordinates.set = pad2zero(yolo_coordinates.set)
    yolo_coordinates.session = pad2zero(yolo_coordinates.session)
    image_sizes.set = pad2zero(image_sizes.set)
    image_sizes.session = pad2zero(image_sizes.session)
    surface_positions.set = pad2zero(surface_positions.set)
    surface_positions.session = pad2zero(surface_positions.session)
    frames_corrected.session = pad2zero(frames_corrected.session)
    @debug "" yolo_coordinates.set yolo_coordinates.session image_sizes.set image_sizes.session surface_positions.set surface_positions.session frames_corrected.session

    # now make a file with a map - frame,object,surface
    #assume, we have all the GOOD frames - with 6 April tages recognized
    all_frame_objects = DataFrame()
    for frame in eachrow(frames_corrected)
        set = frame.participant[1:2]
        current_size = filter(row -> row[:frame_number] == frame.new_frame_number && row[:set] == set && row[:session] == frame.session, image_sizes)
        @debug "" frame_number = frame.new_frame_number set current_size
        if isempty(current_size)
            @error "No image size found for current frame; skipping." frame_number = frame.new_frame_number set
            continue
        end
        img_width, img_height = current_size.image_width[1], current_size.image_height[1]
        
        frame_objects = filter(row -> row[:frame_number] == frame.new_frame_number && row[:set] == set && row[:session] == frame.session, yolo_coordinates)
        if isempty(frame_objects)
            @error "No object coordinates found for current frame; skipping." frame_number = frame.new_frame_number set
            continue
        end
        frame_surfaces = filter(row -> row[:world_index] == frame.new_frame_number && row[:set] == set && row[:session] == frame.session && row[:surface] != "face", surface_positions)
        frame_object_with_surfaces = get_surface_for_frame_objects(frame_objects, frame_surfaces, img_width, img_height; out=out)
        frame_object_with_surfaces.corected_frame_number = fill(frame.new_frame_number, nrow(frame_object_with_surfaces))
        frame_object_with_surfaces.frame_number = fill(frame.frame_number, nrow(frame_object_with_surfaces))
        frame_object_with_surfaces.noun_time = fill(frame.noun_time, nrow(frame_object_with_surfaces))
        all_frame_objects = vcat(all_frame_objects, frame_object_with_surfaces)
    end
    return all_frame_objects
end

# TODO this function should be optimized later, use the least distance to the surface center
# TODO this function is work in progress
function get_surface_for_frame_objects(frame_objects, frame_surfaces, img_width, img_height; out=stdout)
    logger = out === stdout ?
        ConsoleLogger(out, Logging.Info) :
        SimpleLogger(out, Logging.Info)
    with_logger(logger) do
        # Select the relevant row based on world_index (frame number)
        corners = [0.0 0.0; 1.0 0.0; 1.0 1.0; 0.0 1.0]
        center = [0.5, 0.5]
        # Initialize surface_number field with "outside all", which will be replaced if an object's coordinates are within the bounds of a surface
        frame_objects.surface_number = fill("outside all", nrow(frame_objects))
        for object in eachrow(frame_objects)
            object.x, object.y, object.w, object.h = transform_yolo_to_pixels(object.x, object.y, object.w, object.h,img_width, img_height)
            @debug object=object.object x=object.x y=object.y
            for surface in eachrow(frame_surfaces)
                # Extract the transformation matrix
                @debug "Extracting transformation matrix from surface..." surface=surface.surface
                surf_to_img_trans = parse_transformation_matrix(surface.surf_to_dist_img_trans)
                surface_corners = transform_surface_corners(corners, surf_to_img_trans)
                surface_center = transform_surface_to_image_coordinates(center[1], center[2], surf_to_img_trans)
                @debug "Surface <$(surface.surface)> center:" x=surface_center[1] y=surface_center[2]
                # Check if object is inside the surface
                min_x, max_x, min_y, max_y = minimum(surface_corners[:, 1]), maximum(surface_corners[:, 1]), minimum(surface_corners[:, 2]), maximum(surface_corners[:, 2])
                if object.x >= min_x && object.x <= max_x && object.y >= min_y && object.y <=max_y
                    @info "Object <$(object.object)> centerpoint detected on surface <$(surface.surface)>" min_x max_x min_y max_y object.x object.y
                    object.surface_number = surface.surface
                    continue
                end
            end

            # If an object's centerpoint is outside the bounds of all surfaces, try object's lower center
            if object.surface_number == "outside all"
                @warn "Object <$(object.object)> center is outside all surfaces; trying object's lower center" object_x=object.x object_y=object.y object_height=object.h new_object_y=(object.y + object.h/2)
                for surface in eachrow(frame_surfaces)
                    object_y = object.y + object.h/2
                    surf_to_img_trans = parse_transformation_matrix(surface.surf_to_dist_img_trans)
                    surface_corners = transform_surface_corners(corners, surf_to_img_trans)
                    min_x, max_x, min_y, max_y = minimum(surface_corners[:, 1]), maximum(surface_corners[:, 1]), minimum(surface_corners[:, 2]), maximum(surface_corners[:, 2])
                    @debug "Surface <$(surface.surface)> limits:" surface_corners min_x, max_x, min_y, max_y
                    if object.x >= min_x && object.x <= max_x && object_y >= min_y && object_y <=max_y
                        @info "Object <$(object.object)> lower centerpoint detected on surface <$(surface.surface)>" min_x max_x min_y max_y object.x object_y
                        object.surface_number = surface.surface
                        continue
                    end
                end
            end
            
            # If lower center does not work, try upper center
            if object.surface_number == "outside all"
                @warn "Object <$(object.object)> center is outside all surfaces; trying object's upper center" object_x=object.x object_y=object.y object_height=object.h new_object_y=(object.y - object.h/2)
                for surface in eachrow(frame_surfaces)
                    object_y = object.y - object.h/2
                    surf_to_img_trans = parse_transformation_matrix(surface.surf_to_dist_img_trans)
                    surface_corners = transform_surface_corners(corners, surf_to_img_trans)
                    min_x, max_x, min_y, max_y = minimum(surface_corners[:, 1]), maximum(surface_corners[:, 1]), minimum(surface_corners[:, 2]), maximum(surface_corners[:, 2])
                    if object.x > min_x && object.x < max_x && object_y > min_y && object_y < max_y
                        @info "Object <$(object.object)> upper centerpoint detected on surface <$(surface.surface)>" min_x max_x min_y max_y object.x object_y
                        object.surface_number = surface.surface
                        continue
                    end
                end
            end
            
            # Log error if still not found on any surface
            if object.surface_number == "outside all"
                @error "Object <$(object.object)> center is still not found on any surfaces. Further handling may need to be implemented."
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
        println(out,indent * prefix * entry)
        
        # If the entry is a directory, recursively print its contents
        full_path = joinpath(path, entry)
        if isdir(full_path)
            new_indent = indent * (is_last ? "    " : "│   ")
            print_folder_structure(full_path, new_indent)
        end
    end
end

function get_object_position_for_all_trial_fixations(all_frame_objects, all_trial_surfaces_gazes, all_trial_surfaces_fixations; out=stdout)
    # Ensure set and session are both two-character strings, e.g. "01"
    @debug "Standardizing type of set and session to two-character strings..."
    all_frame_objects.set = pad2zero(all_frame_objects.set)
    all_frame_objects.session = pad2zero(all_frame_objects.session)
    all_trial_surfaces_gazes.session = pad2zero(all_trial_surfaces_gazes.session)
    all_trial_surfaces_fixations.session = pad2zero(all_trial_surfaces_fixations.session)
    @debug "" all_frame_objects.set all_frame_objects.session all_trial_surfaces_gazes.session all_trial_surfaces_fixations.session
  
    all_trial_surfaces_fixations.set .= [p[1:2] for p in all_trial_surfaces_fixations.participant]
    all_trial_surfaces_gazes.set .= [p[1:2] for p in all_trial_surfaces_gazes.participant]
    # Join all_frame_objects with all_trial_surfaces_gazes
    joined_gazes = leftjoin(all_trial_surfaces_gazes, all_frame_objects, on = [:set, :session, :frame_number, :noun_time, :surface => :surface_number])
    # Join the result with all_trial_surfaces_fixations
    joined_fixations = leftjoin(all_trial_surfaces_fixations, all_frame_objects, on = [:set, :session, :frame_number, :noun_time, :surface => :surface_number])

    return joined_fixations, joined_gazes
end

#functions for exploratory Plots
function surface_heatmap() 
    #this function is work in progress
    #for each session:
        # fixations on face
        #fixations on hands
        # fixations on target objects
end

#functions for the analysis

#additional utilies to plot surfaces and see if something is wrong 
#note: CairoMakie flips the background image for whatever reason
#fix image sizes in this function
function get_all_surfaces_for_a_frame(frame_number, set_surface_positions; out=stdout)
    # TODO this function is work in progress
    img_width = 1024
    img_height = 768

    # Select the relevant row based on world_index (frame number)
    frame_surfaces = set_surface_positions[set_surface_positions.world_index .== frame_number, :]
    surface_coords = Dict()
    for surface in eachrow(frame_surfaces)
        #surface = eachrow(frame_surfaces)[1]
        println(out,"checking surface: $(surface.surface)")
        # Extract the transformation matrix
        transform_matrix=parse_transformation_matrix(surface.surf_to_dist_img_trans)
        corners = [0.0 0.0; 1.0 0.0; 1.0 1.0; 0.0 1.0]
        corners_coords = test_coordinates = transform_surface_corners(corners,  transform_matrix)
        surface_coords[surface.surface] = corners_coords
    end
    return surface_coords
end

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
        println(out,"Plotting surface: $surface_name, with corners: ")
        println(out,surface[2])
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
        set = replace(split(filename, "_")[1], "set" => "")
        if length(split(filename, "_"))>2
            session = replace(split(filename, "_")[3],"session" => "")
        else
            session = "0"
        end
        @debug "Extracting image dimensions from $file" frame_number set session

        try # Check if the file is an image
            # Load the image
            img = load(file)
            # Get the dimensions of the image
            width, height = size(img)[2], size(img)[1]
            # Append the information to the DataFrame
            push!(image_sizes, (frame_number, set, session, width, height))
        catch e
            # Handle the case where the file is not an image
            @warn "Skipping file $file -- not an image" e
        end
    end
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

