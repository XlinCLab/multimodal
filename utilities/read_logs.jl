
#using Pkg
#Pkg.add("DataFrames")
using Printf
Base.show(io::IO, f::Float64) = @printf(io, "%.2f", f)

using DataFrames
using CSV

function get_decision_times(session)
    DTrow = (line_num=0, label="", start_time=0, end_time=0, participant="")
    Decision_times = DataFrame(line_num=0, label="", time=0, participant="")

    for filename in readdir(session)
        println(filename)
        open(session * filename, "r") do f
            participant = filename[1:2] * session[1]
            for (i, ln) in enumerate(eachline(f))
                if occursin(r"SOUND_TIMER_target BLOCKS.TRIALS.RECORDING.SOUND_TIMER_target", ln)
                    push!(Decision_times, (i, ln[12:end], parse(Int, ln[1:7]), participant))
                elseif occursin(r"DISPLAY_SCREEN_TRIAL_context .* (BEGIN)", ln)
                    push!(Decision_times, (i, ln[11:end], parse(Int, ln[1:7]), participant))
                elseif occursin(r"UPDATE_ATTRIBUTE_mouse_target BLOCKS.TRIALS.RECORDING.UPDATE_ATTRIBUTE_mouse_target", ln)
                    push!(Decision_times, (i, ln[12:end], parse(Int, ln[1:7]), participant))
                    #elseif occursin(r"NULL_ACTION_AfterMouseResp BLOCKS.TRIALS.RECORDING.NULL_ACTION_AfterMouseResp", ln) 
                    #push!(Decision_times, (i, ln[11:end], parse(Int,ln[1:7]), participant))

                else
                    continue
                end
            end
        end
    end
    return (Decision_times)
end

session = "A/"
function get_trials_timing(session)
    participant = ""
    line_num = 0
    label = ""
    
    Decision_times = DataFrame(participant="", line_num=0, label="", image_clicked="", trial_start_time=0.0, context_start_time=0.0, context_end_time=0.0, target_start_time=0.0, target_audio_start_time=0.0, target_audio_end_time=0.0, mouse_move=0, mouse_start_time=0.0, mouse_end_time=0.0, question_answer_time=0.0, trial_end_time=0.0)

    for filename in readdir(session)
        trial_start_time = 0.0
        context_start_time = 0.0
        context_end_time = 0.0
        target_start_time = 0.0
        target_audio_start_time = 0.0
        target_audio_end_time = 0.0
        mouse_start_time = 0.0
        mouse_end_time = 0.0
        question_answer_time = 0.0
        trial_end_time = 0.0
        image_clicked = ""
        mouse_move=0
        println(filename)
        open(session * filename, "r") do f
            participant = filename[1:2] * session[1]
            trial_num = 1
            for (line_num, ln) in enumerate(eachline(f))
                if occursin(r"DISPLAY_SCREEN_TRIAL_context", ln)
                    trial_start_time = parse(Float64, ln[1:8])
                elseif occursin(r"PLAY_SOUND_context", ln)
                    context_start_time = parse(Float64, ln[1:8])
                elseif occursin(r"SOUND_TIMER_context", ln)
                    context_end_time = parse(Float64, ln[1:8])
                elseif occursin(r"DISPLAY_SCREEN_TRIAL_target", ln)
                    target_start_time = parse(Float64, ln[1:8])
                elseif occursin(r"PLAY_SOUND_target", ln)
                    target_audio_start_time = parse(Float64, ln[1:8])
                elseif occursin(r"UPDATE_ATTRIBUTE_resetMousePos BLOCKS.TRIALS.RECORDING.UPDATE_ATTRIBUTE_resetMousePos", ln)
                    mouse_start_time = parse(Float64, ln[1:8])
                elseif occursin(r"SOUND_TIMER_target", ln)
                    target_audio_end_time = parse(Float64, ln[1:8])
                elseif (occursin(r"DISPLAY_SCREEN_TRIAL_MouseResponse", ln) && target_audio_end_time <= parse(Float64, ln[1:8]))                    
                        print("mouse_move 1 ",   mouse_move, "\n")
                        mouse_move+=1
                        print("mouse_move 2 ",   mouse_move, "\n")
                    elseif occursin(r"UPDATE_ATTRIBUTE_mouse_target", ln)
                        mouse_end_time = parse(Float64, ln[1:8])
                    image_clicked = "target"
                elseif occursin(r"UPDATE_ATTRIBUTE_mouse_competitor", ln)
                    mouse_end_time = parse(Float64, ln[1:8])
                    image_clicked = "competitor"
                elseif occursin(r"UPDATE_ATTRIBUTE_mouse_third", ln)
                    mouse_end_time = parse(Float64, ln[1:8])
                    image_clicked = "third"
                elseif occursin(r"MOUSE_wahr", ln) | occursin(r"MOUSE_falsch", ln)
                    question_answer_time = parse(Float64, ln[1:8])
                elseif occursin(r"DISPLAY_BLANK_TRIAL_END.*(BEGIN)", ln)
                    trial_end_time = parse(Float64, ln[1:8])
                    label = "Trial: $trial_num"
                    push!(Decision_times, (participant, line_num, label,image_clicked, trial_start_time, context_start_time, context_end_time, target_start_time,target_audio_start_time,target_audio_end_time, mouse_move, mouse_start_time, mouse_end_time, question_answer_time, trial_end_time))
                    #print(participant, line_num, label, trial_start_time, context_start_time, context_end_time, target_start_time,target_audio_start_time,target_audio_end_time, mouse_start_time, mouse_end_time, question_answer_time, trial_end_time)
                    trial_num += 1
                    mouse_move=0
                else
                    continue
                end
            end
        end

    end
    return(Decision_times)
end

DT= append!(get_trials_timing("A/") ,get_trials_timing("B/") , cols=:union )

CSV.write("trials timing from log files.csv", DT)
