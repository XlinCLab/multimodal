#get surface gazes and fixations for objects
include("functions.jl")

function get_gazes_and_fixations_by_frame_and_surface(set,session, surface, frame_number, surfaces_file)
    #get the gazes and fixations for the surface
    surfaces_file= CSV.read("/Users/varya/Desktop/Julia/Roberts ET data/surface_frames.csv", DataFrame) |>
    df -> transform!(df, :token => ByRow(lowercase) => :token) |>
    df -> rename!(df, :frame => :frame_number) |>
    df -> transform!(df, :surface => ByRow(string) => :surface) |>
    df -> transform!(df, :set => ByRow(x-> lpad(x, 2, "0")) => :set) |>
    df -> transform!(df, :session => ByRow(x-> lpad(x, 2, "0")) => :session) 

    fixations = get_set_fixations_for_nouns("04") |>
    df -> rename!(df, :noun => :token) |>
    df -> select!(df, [:participant, :time_corrected, :noun_time, :fixation_id, :face, :frame_number, :set, :session, :token, :surface])
    fixations = innerjoin(fixations, surfaces_file, on = [ :frame_number, :set, :session, :token, :surface]) |> unique
    fixations.diff_time = [fixation.time_corrected - fixation.noun_time for fixation in eachrow(fixations)]
    
    
    # gazes have different frame numbers
    gazes = get_set_fixations_for_nouns("04", "","gaze_positions_on_surface") |>
    df -> rename!(df, :noun => :token)
    gazes = innerjoin(gazes, surfaces_file, on = [:frame_number, :set, :session, :token, :surface])

    return gazes, fixations
end

participant = "04_01"
session = "003"