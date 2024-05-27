
using Pkg
Pkg.add("MixedModels")
Pkg.add("StatsModels")


using DataFrames
using CSV
using Unfold
using UnfoldSim
using StatsModels
using MixedModels # important to load to activate the UnfoldMixedModelsExtension
using UnfoldMakie, CairoMakie # plotting


## Get the data
files_root = "/Users/varya/Desktop/Julia/EEG_unfold/2varya/"
participants = CSV.read(files_root*"fn2varya.csv", DataFrame)
events = CSV.read(files_root*"events2varya.csv", DataFrame)
data = leftjoin(participants, events, on=:Time => :latency)

#create a new column with the type of the event:
#considering the codes below
# Trigger Codes:
# S1001-S1240 = Stimuli (Fakten)
# S500 = response correct = (= "yes" for items 1001-1180 and "no" for 1181-1240)
# S505 = response incorrect (= "no" for items 1001-1180 and "yes" for 1181-1240)
# S 11 = Feedback "richtig"
# S 12 = Feedback "falsch
# S 13 = feedback "suprise"
# S 14 = feedback "doubt"
# S252 = ms_orange (gesicht erscheint vor Fakt)
# S253 = ms_blue (Gesicht erscheint vor Feedback)
# S254 = blank screen
# S255 = new Trial

face_events = filter(row -> row[:type] in ["S252", "S253"], events)
face_events.type = ifelse.(face_events.type .== "S252", "MsOrange", "MsBlue")


## Mass Univariate Linear Models (with overlap correction)
times = data.Time
figure_1 = Figure()
plot(times[1:1000], data.F7[1:1000])
vlines!(current_axis(),face_events[face_events.latency .<= 1000, :latency] ./ 50) # show events, latency in samples!
figure_1


# Unfold supports multi-channel, so we could provide matrix ch x time, which we can create like this from a vector:
data_r = reshape(data.F7, (1,:))
# cut the data into epochs
#τ specifies the epoch size.
#sfreq - sampling rate, converts τ to samples.

data_epochs, times = Unfold.epoch(data = data_r, tbl = face_events, τ = (-0.5, 1), sfreq = 50);
size(data_epochs)

basisfunction = firbasis(τ=(-0.5,1),sfreq=100,name="stimulus")
formula_by_type = @formula 0 ~ 1 + type
#model_by_type = fit(UnfoldModel, formula_by_type , events, data_epochs, times);
bfDict = Dict(Any=>(formula_by_type,basisfunction))
model_by_type = fit(UnfoldModel,bfDict,face_events ,data.F7, eventcolumn="type" );

results = coeftable(model_by_type)
plot_erp(results)
first(coeftable(model_by_type), 6)