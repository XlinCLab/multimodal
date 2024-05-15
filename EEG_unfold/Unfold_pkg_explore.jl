using Pkg

Pkg.add("CairoMakie")


using DataFrames
using Unfold
using UnfoldMakie,CairoMakie # for plotting
using UnfoldSim

#Every row is an event. 
#Note that :latency is commonly the timestamp in samples, 
#whereas :onset would typically refer to seconds.
data, evts = UnfoldSim.predef_eeg()
times = range(1/50,length=200,step=1/50)
plot(times,data[1:200])
vlines!(current_axis(),evts[evts.latency.<=200,:latency]./50) # show events, latency in samples!

show(first(evts,6,),allcols=true)

# we have multi channel support
data_r = reshape(data,(1,:))
# cut the data into epochs
data_epochs,times = Unfold.epoch(data=data_r,tbl=evts,τ=(-0.4,0.8),sfreq=50);
size(data_epochs)
typeof(data_epochs)

f  = @formula 0~1+condition+continuous # 0 as a dummy, we will combine wit data later
m = fit(UnfoldModel,f,evts,data_epochs,times);
#or
m = fit(UnfoldModel,Dict(Any=>(f,times)),evts,data_epochs);
first(coeftable(m),6)
results = coeftable(m)
plot_erp(results)

#overlap correction
basisfunction = firbasis(τ=(-0.4,.8),sfreq=100,name="stimulus")
#specify which event and which formula matches 
#this is important in cases where there are multiple events with different formulas
bfDict = Dict(Any=>(f,basisfunction))
#Now we are ready to fit a UnfoldLinearModel. 
#Not that instead of times as in the mass-univariate case, 
#we have to provide the BasisFunction type now.
m = fit(UnfoldModel,bfDict,evts,data);
results = coeftable(m)
plot_erp(results)