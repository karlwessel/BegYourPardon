module BegYourPardon
using Base:show_type_name, typesof, methods_including_ambiguous, SimpleVector,
    show_method_candidates

import Base: write, get, showerror, show_datatype, show_trace_entry
export begyourpardon, byp, comeagain

include("helpers.jl")
include("basereplacements.jl")

end # module
