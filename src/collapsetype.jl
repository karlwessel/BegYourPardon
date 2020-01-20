#import Base: show_datatype

function _show_datatype(io::IO, x::DataType)
    istuple = x.name === Tuple.name
    if (!isempty(x.parameters) || istuple) && x !== Tuple
        n = length(x.parameters)

        # Print homogeneous tuples with more than 3 elements compactly as NTuple{N, T}
        if istuple && n > 3 && all(i -> (x.parameters[1] === i), x.parameters)
            print(io, "NTuple{", n, ',', x.parameters[1], "}")
        else
            Base.show_type_name(io, x.name)
            # Do not print the type parameters for the primary type if we are
            # printing a method signature or type parameter.
            # Always print the type parameter if we are printing the type directly
            # since this information is still useful.
            print(io, '{')
			collapsein = get(io, :collapsein, Inf)
            if collapsein > 0
		        for (i, p) in enumerate(x.parameters)
	                show(IOContext(io, :collapsein => collapsein-1), p)
	                i < n && print(io, ',')
	            end
			else
				print(io, "...")
		    end
            print(io, '}')
        end
    else
        Base.show_type_name(io, x.name)
    end
end

function _show(io::IO, @nospecialize(x::Type))
    collapsein = get(io, :collapsein, Inf)

    if x isa DataType
        Base.show_datatype(io, x)
        return
    elseif x isa Union
        print(io, "Union")
        if collapsein > -1
            Base.show_delim_array(IOContext(io, :collapsein => collapsein),
                Base.uniontypes(x), '{', ',', '}', false)
        else
			print(io, "{...}")
	    end
        return
    end
    x::UnionAll

    if Base.print_without_params(x)
        return show(io, Base.unwrap_unionall(x).name)
    end

    if x.var.name === :_ || Base.io_has_tvar_name(io, x.var.name, x)
        counter = 1
        while true
            newname = Symbol(x.var.name, counter)
            if !Base.io_has_tvar_name(io, newname, x)
                newtv = TypeVar(newname, x.var.lb, x.var.ub)
                x = UnionAll(newtv, x{newtv})
                break
            end
            counter += 1
        end
    end

    show(IOContext(io, :unionall_env => x.var), x.body)

    if collapsein > 0
        print(io, " where ")
        show(IOContext(io, :collapsein => collapsein-1), x.var)
    end
end

Base.show(io::IO, @nospecialize(x::Type)) = _show(io, x)
Base.show_datatype(io::IO, x::DataType) = _show_datatype(io, x)

