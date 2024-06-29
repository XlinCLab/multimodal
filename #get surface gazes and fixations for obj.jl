#get surface gazes and fixations for objects
include("functions.jl")

function get_gazes_and_fixations_by_frame_and_surface(set, surfaces_file)
    #set = "04"
    #get the gazes and fixations for the surface
    surfaces_1 = select(surfaces_file, [:frame_number, :token, :set, :session, :surface])
    surfaces_2 = select(surfaces_file, [:frame_number, :token, :set, :session, :surface2]) |>
    df -> rename!(df, :surface2 => :surface) |>
    df -> filter(row -> row[:surface]!= "", df)
    surfaces = vcat(surfaces_1, surfaces_2)

    if set in unique(surfaces.set)
        fixations = get_set_fixations_for_nouns(set) |>
        df -> rename!(df, :noun => :token) |>
        df -> select!(df, [:participant, :time_corrected, :noun_time, :fixation_id, :face, :frame_number, :set, :session, :token, :surface])
        fixations = innerjoin(fixations, surfaces, on = [ :frame_number, :set, :session, :token, :surface]) |> unique
        fixations.diff_time = [fixation.time_corrected - fixation.noun_time for fixation in eachrow(fixations)]
    else
        fixations = DataFrame()
    end     
    
    # gazes have different frame numbers
    if set in unique(surfaces.set)
        gazes = get_set_fixations_for_nouns(set, "","gaze_positions_on_surface") |>
        df -> rename!(df, :noun => :token)
        gazes = innerjoin(gazes, surfaces, on = [:frame_number, :set, :session, :token, :surface])
        gazes.diff_time = [gaze.time_corrected - gaze.noun_time for gaze in eachrow(gazes)]
    else
        gazes = DataFrame()
    end

    return gazes, fixations
end
#set = "04"
sets = ["04", "05", "06", "07", "08", "09", "10", "11", "12"]
surfaces_file= CSV.read("/Users/varya/Desktop/Julia/Roberts ET data/surface_frames.csv", DataFrame)  |>
df -> transform!(df, :token => ByRow(lowercase) => :token) |>
df -> rename!(df, :frame => :frame_number) |>
df -> transform!(df, :surface => ByRow(string) => :surface) |>
df -> transform!(df, :surface2 => ByRow(string) => :surface2) |>
df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set) |>
df -> transform!(df, :session => ByRow(x-> lpad(x, 2, "0")) => :session) 

all_gazes = DataFrame()
all_fixations = DataFrame()
for set in sets
    gazes, fixations = get_gazes_and_fixations_by_frame_and_surface(set, surfaces_file)
    all_gazes = vcat(all_gazes, gazes)
    all_fixations = vcat(all_fixations, fixations)
end   
     
CSV.write("/Users/varya/Desktop/Julia/Roberts ET data/all_gazes.csv", all_gazes)
CSV.write("/Users/varya/Desktop/Julia/Roberts ET data/all_fixations.csv", all_fixations)

function check_april_tags_for_frames(frames)
if isempty(frames)
    frames = CSV.read("/Users/varya/Desktop/Julia/Roberts ET data/surface_frames.csv", DataFrame) |>
    df -> transform!(df, :surface => ByRow(string) => :surface) |>
    df -> transform!(df, :participant => ByRow(x-> x[1:2]) => :set) |>
    df -> transform!(df, :session => ByRow(x-> lpad(x, 2, "0")) => :session) 
end
    for frame in eachrow(frames)
        surfaces_folder = replace(frame.video_path, "world.mp4" => "")
        surfaces_folder = surfaces_folder*"exports/"
    end
end
