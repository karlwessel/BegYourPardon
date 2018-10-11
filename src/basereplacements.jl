
function show_datatype(io::IO, x::DataType)
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

function show_trace_entry(io, frame, n; prefix = "")
    push!(Base.LAST_SHOWN_LINE_INFOS, (string(frame.file), frame.line))
    print(io, "\n", prefix)
    show(io, frame, full_path=get(io, :fullpath, true))
    n > 1 && print(io, " (repeats ", n, " times)")
end

function filepackage(file)
	findlast("julia/base", file) != nothing && return "base"

	path = split(file, "/")

	if findlast("julia/stdlib", file) != nothing
		ind = findlast(x->x=="src", path)
		ind != nothing && return path[ind-1]
	end

	pind = findlast(x->x=="packages", path)
	pind != nothing && pind < length(path) && return path[pind+1]

	return nothing
end

function show(io::IO, frame::Base.StackFrame; full_path::Bool=false)
    StackTraces.show_spec_linfo(io, frame)
    if frame.file !== StackTraces.empty_sym
		file_info = string(frame.file)
		if !full_path
			modulename = filepackage(file_info)
			if modulename == nothing
				modulename = "unknown"
			end
			file_info = "$(moldulename)s $(basename(file_info))"
		end
        file_info = full_path ? string(frame.file) : basename(string(frame.file))
        print(io, " at ")
        Base.with_output_color(get(io, :color, false) && get(io, :backtrace, false) ? Base.stackframe_lineinfo_color() : :nothing, io) do io
            print(io, file_info, ":")
            if frame.line >= 0
                print(io, frame.line)
            else
                print(io, "?")
            end
        end
    end
    if frame.inlined
        print(io, " [inlined]")
    end
end

function showerror(io::IO, ex::MethodError)
    # ex.args is a tuple type if it was thrown from `invoke` and is
    # a tuple of the arguments otherwise.
    is_arg_types = isa(ex.args, DataType)
    arg_types = is_arg_types ? ex.args : Base.typesof(ex.args...)
    f = ex.f
    meth = Base.methods_including_ambiguous(f, arg_types)
    if length(meth) > 1
        return Base.showerror_ambiguous(io, meth, f, arg_types)
    end
    arg_types_param::Base.SimpleVector = arg_types.parameters
    print(io, "MethodError: ")
    ft = typeof(f)
    name = ft.name.mt.name
    f_is_function = false
    kwargs = ()
    if startswith(string(ft.name.name), "#kw#")
        f = ex.args[2]
        ft = typeof(f)
        name = ft.name.mt.name
        arg_types_param = arg_types_param[3:end]
        kwargs = pairs(ex.args[1])
        ex = MethodError(f, ex.args[3:end])
    end
    if f == Base.convert && length(arg_types_param) == 2 && !is_arg_types
        f_is_function = true
        # See #13033
        T = striptype(ex.args[1])
        if T === nothing
            print(io, "First argument to `convert` must be a Type, got ", ex.args[1])
        else
            print(io, "Cannot `convert` an object of type ", arg_types_param[2], " to an object of type ", T)
        end
    elseif isempty(methods(f)) && isa(f, DataType) && f.abstract
        print(io, "no constructors have been defined for $f")
    elseif isempty(methods(f)) && !isa(f, Function) && !isa(f, Type)
        print(io, "objects of type $ft are not callable")
    else
        if ft <: Function && isempty(ft.parameters) &&
                isdefined(ft.name.module, name) &&
                ft == typeof(getfield(ft.name.module, name))
            f_is_function = true
            print(io, "no method matching ", name)
        elseif isa(f, Type)
            print(io, "no method matching ", f)
        else
            print(io, "no method matching (::", ft, ")")
        end
        print(io, "(")
        for (i, typ) in enumerate(arg_types_param)
            print(io, "::")
	        print(io, typ)
            i == length(arg_types_param) || print(io, ", ")
        end
        if !isempty(kwargs)
            print(io, "; ")
            for (i, (k, v)) in enumerate(kwargs)
                print(io, k, "=")
                show(IOContext(io, :limit => true), v)
                i == length(kwargs) || print(io, ", ")
            end
        end
        print(io, ")")
    end
    if ft <: AbstractArray
        print(io, "\nUse square brackets [] for indexing an Array.")
    end
    # Check for local functions that shadow methods in Base
    if f_is_function && isdefined(Base, name)
        basef = getfield(Base, name)
        if basef !== ex.f && hasmethod(basef, arg_types)
            println(io)
            print(io, "You may have intended to import Base.", name)
        end
    end
    if (ex.world != typemax(UInt) && hasmethod(ex.f, arg_types) &&
        !hasmethod(ex.f, arg_types, world = ex.world))
        curworld = ccall(:jl_get_world_counter, UInt, ())
        println(io)
        print(io, "The applicable method may be too new: running in world age $(ex.world), while current world is $(curworld).")
    end
    if !is_arg_types
        # Check for row vectors used where a column vector is intended.
        vec_args = []
        hasrows = false
        for arg in ex.args
            isrow = isa(arg,Array) && ndims(arg)==2 && size(arg,1)==1
            hasrows |= isrow
            push!(vec_args, isrow ? vec(arg) : arg)
        end
        if hasrows && applicable(f, vec_args...)
            print(io, "\n\nYou might have used a 2d row vector where a 1d column vector was required.",
                      "\nNote the difference between 1d column vector [1,2,3] and 2d row vector [1 2 3].",
                      "\nYou can convert to a column vector with the vec() function.")
        end
    end
    try
        Base.show_method_candidates(io, ex, kwargs)
    catch ex
        @error "Error showing method candidates, aborted" exception=ex,catch_backtrace()
    end
end
