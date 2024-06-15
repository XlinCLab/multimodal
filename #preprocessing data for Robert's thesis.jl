#preprocessing data for Robert's thesis
#this script will take the audio transcription, object positions and the gaze positions and a timeline of object positions
#combine them together
#reannotate objects to match all the three files
#and then take all the fixations that happened at word onset + 3s
# problems
using Pkg
Pkg.add(["DataFrames", "DataFramesMeta", "StatsPlots"])
using Printf
Base.show(io::IO, f::Float64) = @printf(io, "%.2f", f)

using DataFrames
using CSV

participants = ["04", "05", "06", "07", "08","09", "10", "11", "12"]
sessions = ["01", "02", "03","04"]
conditions = Dict([("01","11"),("02","12"), ("03", "21"), ("04" ,"22")])
root_folder = "/Users/varya/Desktop/Julia/Roberts ET data/Dyaden_Analyse"

for participant in participants
    println("participant $participant")
    for session in sessions
        println("session $session")
        if participant == "04" && session == "01"
            continue
        end
#  participant = "04"
#  session="04"

 condition = conditions[session]

                words_folder = joinpath(root_folder, participant,"audio",session)
                surface_folder = joinpath(root_folder, participant, "eyetracking", session, "surfaces")
                object_positions_file = joinpath(root_folder, participant, "object_positions", "01")
                object_positions_times_path = joinpath(root_folder,  "movement annotations")
                object_positions = CSV.read(joinpath(object_positions_file, "Objektlisten_$participant.csv"), DataFrame)
                try
                    object_positions_times = CSV.read(joinpath(object_positions_times_path, "words_$participant"*"_$condition"*"_times.csv"), DataFrame)
                catch e
                    println("No timed object positions file: $participant $condition: ")
                    continue
                end

                #first look at the words files to see, what will be the target objects 
                #make a list then left_join object_positions_file
                words_to_tokens = CSV.read(joinpath(root_folder, "Objektbezeichnungen.csv"), DataFrame, types=Dict(:subject=>String, :condition=>String)) 
                words = CSV.read(joinpath(words_folder, "words_$participant"*"_$condition.csv"), DataFrame) 


                target_tokens = words_to_tokens |> 
                                df -> rename(df, names(df) .=> strip.(string.(names(df)))) |>
                                row -> filter( row -> row.subject ==  participant && row.condition==condition, row) |>
                                df -> select(df, :name, :token) |>
                                df -> transform(df, :token => ByRow(lowercase) => :token) |>
                                df -> transform(df, :name => ByRow(lowercase) => :name) |>
                                df -> transform(df, :name => ByRow(x -> replace(x, r" " => "")) => :name) 

                target_words = filter(row -> !ismissing(row.pos) , words)|>
                                df -> rename!(df, names(df) .=> strip.(string.(names(df)))) |>
                                df -> filter!(row -> row.pos == "N", df)  |>
                                df -> transform!(df, :text => ByRow(lowercase) => :text)
                target_words = leftjoin(target_words, target_tokens , on = :text => :name) |>
                df -> filter!(row -> !ismissing(row.token), df) 

println("target_tokens")
print(target_tokens)
                #there is something weird with the names
                #OK, typos, included Baterie in the list of tokens
                # CSV.write("object_positions_11.csv", object_positions)


                object_positions = object_positions |>
                df -> rename!(df, names(df) .=> strip.(string.(names(df)))) |>
                df -> transform!(df, :object => ByRow(x -> replace(x, r"\d" => "")) => :text) |>
                df -> transform!(df, :object => ByRow(x -> replace(x, r"[^\d]" => "")) => :token_number) |>
                df -> transform!(df, :text .=> ByRow(x -> replace(x, " " => "")) => :text) |>
                df -> transform!(df, [:set, :pattern] => ByRow((x, y) -> string(x, y)) => :cond) |>
                row -> filter!(row -> row.cond == condition, row)  |>
                df -> select(df, :text,:condition,:surface, :surface_competitor, :token_number, :cond) 

                object_positions = leftjoin(object_positions, target_tokens , on = :text => :name)  
                object_positions[!, :token] = coalesce.(object_positions[!, :token], object_positions[!,:text])


                current_tokens = unique(target_words, :token)
                object_tokens = unique(object_positions, :token)
println("current tokens")
print(current_tokens)
println("object tokens")
print(object_tokens)

                object_positions_times =  transform!(object_positions_times, :text => ByRow(lowercase) => :text)|>
                                        df -> transform!(df, :text .=> ByRow(x -> replace(x, " " => "")) => :text)|>
                                        df -> filter!(row -> !ismissing(row.pos), df)   

                object_positions_times = leftjoin(object_positions_times, target_tokens , on = :text => :name)  |>
                                        df -> rename!(df, names(df) .=> strip.(replace.(string.(names(df)), " " => ""))) |>
                                        df -> filter!(row -> !ismissing(row.token), df) |>
                                        df -> transform!(df, :token .=> ByRow(x -> replace(x, " " => "")) => :token) |>
                                        df -> rename!(df, :facevisibility => :face) |>
                                        df -> select(df, :tmax,:face, :token)
 

print(unique(object_positions_times, :token))
print(unique(object_positions, :token))
                
                if "creme" in current_tokens.token && !("creme" in object_tokens.token) && "tube" in object_tokens.token
                    print("creme=tube")
                    object_positions_times = transform!(object_positions_times, :token .=> ByRow(x -> replace(x,"creme"=> "tube")) => :token) 
                end

                times_grouped_by_token = groupby(object_positions_times, :token)
                movements_grouped_by_token = groupby(object_positions, :token)
                #
                # annotate object movements by time,
                #this will also give us if they had to move the same object twice in a row
                # => create a timeline of object positions

                timed_object_positions = DataFrame() 
                # do it by row, by token assigns akl the times to all the movements inside one group
                for (key, group) in pairs(movements_grouped_by_token)
                    token = key.token
                    println(token)
                    times =times_grouped_by_token[(token,)]
                    println(size(times))
                    times[!, :index] = 1:nrow(times)
                    group[!, :index] = 1:nrow(group)
                    timed_object_positions = vcat(timed_object_positions, leftjoin(group, times, on = [:token, :index])) # Append the results to the DataFrame
                end
                CSV.write("$object_positions_times_path/draft_timed_object_positions_$participant$session.csv", timed_object_positions)

                unique(timed_object_positions, :surface)

                # now take all fixations from the target surfaces and the face that happened at word onset + 3s
                surface_list =string.(unique(timed_object_positions, :surface).surface)
                

                #read all surfaces and delete the "false" rows
                gaze_positions = CSV.read(joinpath(surface_folder, "gaze_positions_on_surface_face.csv"), DataFrame)
                filter!(row -> row.on_surf == true, gaze_positions)
                gaze_positions.surface = fill("face", nrow(gaze_positions))

                for file in readdir(surface_folder)
                    for surface in surface_list
                        if occursin(surface, file)
                            surface_df =  CSV.read(joinpath(surface_folder, file), DataFrame)|>
                                        df -> filter!(row -> row.on_surf == true, df) 
                            surface_df.surface = fill(surface, nrow(surface_df))
                            gaze_positions = append!(gaze_positions, surface_df)

                        end
                    end
                end
#Now we need to get gaze positions +3s after the word onset
            end
        end
            