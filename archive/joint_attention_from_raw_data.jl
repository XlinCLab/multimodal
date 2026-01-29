#in this file we will look at the movements
# in the raw eyetracker data
#when director and matcher look at the same surface
#and then annotate them by words and it the face was open

using DataFrames
using CSV
surface_list = ["face", "11", "12", "13", "14", "21", "22", "23", "24", "31", "32", "33", "34", "41", "42", "43", "44"]
participants = [ "10_01", "11_01", "12_01", "10_02", "11_02", "12_02"]
sessions = ["000", "001", "002","003"]
root_folder = "/Users/varya/Desktop/Julia/DGAME data/"

function read_surfaces(participant, session, data_type = "fixations_on_surface")
        participant_folder = joinpath(root_folder, "DGAME3_$participant", "$session", "exports")
        subfolders = [f for f in readdir(participant_folder) if isdir(joinpath(participant_folder, f))]
        surface_folder = joinpath(participant_folder, subfolders[1],"surfaces")
        surface_files = [file for file in readdir(surface_folder)if occursin(data_type, file)]

        fixations_positions = CSV.read(joinpath(surface_folder, "$data_type"*"_face.csv"), DataFrame)
        filter!(row -> row.on_surf == true, fixations_positions)
        if data_type == "fixations_on_surface"
            time_zero = fixations_positions.start_timestamp[1]
            fixations_positions.time_sec = fixations_positions.start_timestamp .- time_zero
        else
            time_zero = fixations_positions.gaze_timestamp[1]
            fixations_positions.time_sec = fixations_positions.gaze_timestamp .- time_zero
        end
        fixations_positions.surface = fill("face", nrow(fixations_positions))

        for file in surface_files
                    surface = split(file, "_")[end] |> x -> split(x, ".")[1]
                    surface_df =  CSV.read(joinpath(surface_folder, file), DataFrame)
                    if data_type == "fixations_on_surface"
                        time_zero = surface_df.start_timestamp[1]
                        surface_df.time_sec = surface_df.start_timestamp .- time_zero
                    else
                        time_zero = surface_df.gaze_timestamp[1]
                        surface_df.time_sec = surface_df.gaze_timestamp .- time_zero
                    end
                    filter!(row -> row.on_surf == true, surface_df) 
                    surface_df.surface = fill(surface, nrow(surface_df))
                    fixations_positions = append!(fixations_positions, surface_df)
        end
        fixations_positions.participant = fill(participant, nrow(fixations_positions))
        fixations_positions.session = fill(session, nrow(fixations_positions))

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
    # Rename the columns in `matcher_fixations`
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
# Rename the columns in `matcher_fixations`
joint_attention = innerjoin(matcher_gps,director_gps, on = [:world_index, :surface] )
return joint_attention
end

JA = get_joint_attention_fixations("12", "000") |> 
df -> select!(df, [:time_sec, :world_index, :surface])
unique!(JA)
CSV.write("joint_attention_12_000.csv", JA)



JA = get_joint_attention_fixations("12", "003") |> 
df -> select!(df, [:time_sec, :world_index, :surface])
unique!(JA)
CSV.write("joint_attention_12_003.csv", JA)

using CairoMakie

# Assuming `JA` is your DataFrame and it has columns `time` and `surface`
# Aggregate the data
gazes_by_time = combine(groupby(JA, [:world_index, :surface]), nrow => :gazes)

# Create the plot
fig = Figure()
# Get the unique surfaces
surfaces = unique(JA.surface)
# Create a Figure with one row for each surface
fig = Figure(resolution = (600, 400 * length(surfaces)))

for (i, surface) in enumerate(surfaces)
    ax = Axis(fig[i, 1])
    surface_data = gazes_by_time[gazes_by_time.surface .== surface, :]
    scatter!(ax, surface_data.:world_index, surface_data.gazes, label = surface)
end

fig