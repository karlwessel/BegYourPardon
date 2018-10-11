module BegYourPardon
using Base:show_type_name, typesof, methods_including_ambiguous, SimpleVector,
    show_method_candidates

import Base: write, get, showerror, show_datatype
export begyourpardon, byp

include("helpers.jl")

end # module
