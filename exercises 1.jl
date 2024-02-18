function babylonian(y, ε, x0 = 1.0)
    root=(x0+y/x0)/2
    while root - sqrt(y)>ε
        root=(root+y/root)/2
        println(root)
    end    
end

babylonian(2.0,1e-12)

# exercise 2

function count_nucl(nucleotide)
    nucl_counts = Dict(
        "A" => count( "A", nucleotide),
        "C" => count( "C", nucleotide),
        "G" => count("G", nucleotide),
        "T" => count("T", nucleotide)) 
    if length(nucleotide) != nucl_counts["A"]+nucl_counts["G"]+nucl_counts["C"]+nucl_counts["T"]
        error("A non listed letter in the nucleotide")
    else
        return(nucl_counts )
    end
end

#count_nucl("ATATATAGGCCAX")
count_nucl("ATATATAGGCCA")

#exercise 3
function fibonacci(x) 
    seq =[x[1]]  
    for i in x
        if i==1 
          push!(seq,i)
         else
            push!(seq,seq[i]+seq[i-1])
         end
    end
    return(seq)
end

function fibonacci_rec(x)
    if length(x) == 2 
        return([1,1])
    else 
        return push!(fibonacci_rec(1:length(x)-1), 
        fibonacci_rec(1:length(x)-1)[end]+fibonacci_rec(1:length(x)-1)[end-1])
    end
end
fibonacci_rec(1:8)

#exercise 4
count(i->(i[1]!=i[2]),zip("AAA","BAB"))

