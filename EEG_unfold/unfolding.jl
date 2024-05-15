
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
#using CategoricalArray

## Get the data
files_root = "/Users/varya/Desktop/Julia/EEG_unfold/2varya/"
participants = CSV.read(files_root*"fn2varya.csv", DataFrame)
events = CSV.read(files_root*"events2varya.csv", DataFrame)
data = leftjoin(participants, events, on=:Time => :latency)
sample_data, evts = UnfoldSim.predef_eeg()

#First we have to creat subsets for each event model_by_type
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

events_MsOrange = 

## Mass Univariate Linear Models (with overlap correction)
times = range(1000, length=1000, step=1/50)
figure_1 = Figure()
plot(figure_1[1, 1], data.F7[1:1000], times)
vlines!(events[events.latency .<= 1000, :latency] ./ 50) # show events, latency in samples!
figure_1


# Unfold supports multi-channel, so we could provide matrix ch x time, which we can create like this from a vector:
data_r = reshape(data.F7, (1,:))
# cut the data into epochs
#τ specifies the epoch size.
#sfreq - sampling rate, converts τ to samples.

data_epochs, times = Unfold.epoch(data = data_r, tbl = events, τ = (-0.4, 0.8), sfreq = 50);
size(data_epochs)

basisfunction = firbasis(τ=(-0.4,.8),sfreq=100,name="stimulus")
formula_by_type = @formula 0 ~ 1 + type
#model_by_type = fit(UnfoldModel, formula_by_type , events, data_epochs, times);
bfDict = Dict(Any=>(formula_by_type,basisfunction))
model_by_type = fit(UnfoldModel,bfDict,events,data.F7, eventcolumn="type" );

results = coeftable(model_by_type)
plot_erp(results)
first(coeftable(model_by_type), 6)