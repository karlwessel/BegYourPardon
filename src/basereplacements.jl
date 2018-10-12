
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



function filepackage(file)
	file = abspath(file)
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


function showpath(io::IO, path)
	fullpath = get(io, :fullpath, true)
	file_info = string(path)
	if !fullpath
		modulename = filepackage(file_info)
		if modulename == nothing
			modulename = "unknown package"
		else
			modulename = "package $(modulename)"
		end
		file_info = "file $(basename(file_info)) in $(modulename)"
	end
	print(io, file_info)
end

function show(io::IO, frame::Base.StackFrame; full_path::Bool=false)
    StackTraces.show_spec_linfo(io, frame)
    if frame.file !== StackTraces.empty_sym
		println()
        print(io, "\t at line ")
        Base.with_output_color(get(io, :color, false) && get(io, :backtrace, false) ? Base.stackframe_lineinfo_color() : :nothing, io) do io
	        if frame.line >= 0
                print(io, frame.line)
            else
                print(io, "?")
            end
			print(io, " in ")
			showpath(io, frame.file)
        end
    end
    if frame.inlined
        print(io, " [inlined]")
    end
end

function show_trace_entry(io, frame, n; prefix = "")
    push!(Base.LAST_SHOWN_LINE_INFOS, (string(frame.file), frame.line))
    print(io, "\n", prefix)
    show(io, frame, full_path=get(io, :fullpath, true))
    n > 1 && print(io, " (repeats ", n, " times)")
end

function show_backtrace(io::IO, t::Vector)
    resize!(Base.LAST_SHOWN_LINE_INFOS, 0)
    filtered = Base.process_backtrace(t)
    isempty(filtered) && return

    if length(filtered) == 1 && StackTraces.is_top_level_frame(filtered[1][1])
        f = filtered[1][1]
        if f.line == 0 && f.file == Symbol("")
            # don't show a single top-level frame with no location info
            return
        end
    end

    print(io, "\nStacktrace:")
    if length(filtered) < Base.BIG_STACKTRACE_SIZE
        # Fast track: no duplicate stack frame detection.
        try Base.invokelatest(update_stackframes_callback[], filtered) catch end
        frame_counter = 0
        for (last_frame, n) in filtered
            frame_counter += 1
            show_trace_entry(IOContext(io, :backtrace => true), last_frame, n, prefix = string(" [", frame_counter, "] "))
        end
        return
    end

    Base.show_reduced_backtrace(IOContext(io, :backtrace => true), filtered, true)
end

function showerror(io::IO, ex, bt; backtrace=true)
    try
        Base.with_output_color(get(io, :color, false) ? Base.error_color() : :nothing, io) do io
            showerror(io, ex)
        end
    finally
        backtrace && show_backtrace(io, bt)
    end
end

function show_method_candidates(io::IO, ex::MethodError, @nospecialize kwargs=())
    is_arg_types = isa(ex.args, DataType)
    arg_types = is_arg_types ? ex.args : Base.typesof(ex.args...)
    arg_types_param = Any[arg_types.parameters...]
    # Displays the closest candidates of the given function by looping over the
    # functions methods and counting the number of matching arguments.
    f = ex.f
    ft = typeof(f)
    lines = []
    # These functions are special cased to only show if first argument is matched.
    special = f in [convert, getindex, setindex!]
    funcs = Any[(f, arg_types_param)]

    # An incorrect call method produces a MethodError for convert.
    # It also happens that users type convert when they mean call. So
    # pool MethodErrors for these two functions.
    if f === convert && !isempty(arg_types_param)
        at1 = arg_types_param[1]
        if isa(at1,DataType) && (at1::DataType).name === Type.body.name && !Core.Compiler.has_free_typevars(at1)
            push!(funcs, (at1.parameters[1], arg_types_param[2:end]))
        end
    end

    for (func, arg_types_param) in funcs
        for method in methods(func)
            buf = IOBuffer()
            iob = IOContext(buf, io)
            tv = Any[]
            sig0 = method.sig
            while isa(sig0, UnionAll)
                push!(tv, sig0.var)
                sig0 = sig0.body
            end
            s1 = sig0.parameters[1]
            sig = sig0.parameters[2:end]
            print(iob, "  ")
            if !isa(func, Base.rewrap_unionall(s1, method.sig))
                # function itself doesn't match
                continue
            else
                # TODO: use the methodshow logic here
                use_constructor_syntax = isa(func, Type)
                print(iob, use_constructor_syntax ? func : typeof(func).name.mt.name)
            end
            print(iob, "(")
            t_i = copy(arg_types_param)
            right_matches = 0
            for i = 1 : min(length(t_i), length(sig))
                i > 1 && print(iob, ", ")
                # If isvarargtype then it checks whether the rest of the input arguments matches
                # the varargtype
                if false #Base.isvarargtype(sig[i])
                    sigstr = string(Base.unwrap_unionall(sig[i]).parameters[1], "...")
                    j = length(t_i)
                else
                    sigstr = string(sig[i])
                    j = i
                end
                # Checks if the type of arg 1:i of the input intersects with the current method
                t_in = typeintersect(Base.rewrap_unionall(Tuple{sig[1:i]...}, method.sig),
                                     Base.rewrap_unionall(Tuple{t_i[1:j]...}, method.sig))
                # If the function is one of the special cased then it should break the loop if
                # the type of the first argument is not matched.
                t_in === Union{} && special && i == 1 && break
                if t_in === Union{}
                    if get(io, :color, false)
                        Base.with_output_color(Base.error_color(), iob) do iob
                            print(iob, "::$sigstr")
                        end
                    else
                        print(iob, "!Matched::$sigstr")
                    end
                    # If there is no typeintersect then the type signature from the method is
                    # inserted in t_i this ensures if the type at the next i matches the type
                    # signature then there will be a type intersect
                    t_i[i] = sig[i]
                else
                    right_matches += j==i ? 1 : 0
                    print(iob, "::$sigstr")
                end
            end
            special && right_matches == 0 && continue

            # if length(t_i) > length(sig) && !isempty(sig) && Base.isvarargtype(sig[end])
            #     # It ensures that methods like f(a::AbstractString...) gets the correct
            #     # number of right_matches
            #     for t in arg_types_param[length(sig):end]
            #         if t <: Base.rewrap_unionall(Base.unwrap_unionall(sig[end]).parameters[1], method.sig)
            #             right_matches += 1
            #         end
            #     end
            # end

            if right_matches > 0 || length(ex.args) < 2
                if length(t_i) < length(sig)
                    # If the methods args is longer than input then the method
                    # arguments is printed as not a match
                    for (k, sigtype) in enumerate(sig[length(t_i)+1:end])
                        #sigtype = isvarargtype(sigtype) ? unwrap_unionall(sigtype) : sigtype
                        if false #Base.isvarargtype(sigtype)
                            sigstr = string(sigtype.parameters[1], "...")
                        else
                            sigstr = string(sigtype)
                        end
                        if !((min(length(t_i), length(sig)) == 0) && k==1)
                            print(iob, ", ")
                        end
                        if get(io, :color, false)
                            Base.with_output_color(Base.error_color(), iob) do iob
                                print(iob, "::$sigstr")
                            end
                        else
                            print(iob, "!Matched::$sigstr")
                        end
                    end
                end
                kwords = Symbol[]
                # if isdefined(ft.name.mt, :kwsorter)
                #     kwsorter_t = typeof(ft.name.mt.kwsorter)
                #     kwords = Base.kwarg_decl(method, kwsorter_t)
                #     length(kwords) > 0 && print(iob, "; ", join(kwords, ", "))
                # end
                print(iob, ")")
                Base.show_method_params(iob, tv)
                print(iob, " at ")
				showpath(iob, method.file)
				print(iob, ":", method.line)
                if !isempty(kwargs)
                    unexpected = Symbol[]
                    if isempty(kwords) || !(any(endswith(string(kword), "...") for kword in kwords))
                        for (k, v) in kwargs
                            if !(k in kwords)
                                push!(unexpected, k)
                            end
                        end
                    end
                    if !isempty(unexpected)
                        Base.with_output_color(Base.error_color(), iob) do iob
                            plur = length(unexpected) > 1 ? "s" : ""
                            print(iob, " got unsupported keyword argument$plur \"", join(unexpected, "\", \""), "\"")
                        end
                    end
                end
                if ex.world < Base.min_world(method)
                    print(iob, " (method too new to be called from this world context.)")
                elseif ex.world > Base.max_world(method)
                    print(iob, " (method deleted before this world age.)")
                end
                # TODO: indicate if it's in the wrong world
                push!(lines, (buf, right_matches))
            end
        end
    end

    if !isempty(lines) # Display up to three closest candidates
        Base.with_output_color(:normal, io) do io
            println(io)
            print(io, "Closest candidates are:")
            sort!(lines, by = x -> -x[2])
            i = 0
            for line in lines
                println(io)
                if i >= 3
                    print(io, "  ...")
                    break
                end
                i += 1
                print(io, String(take!(line[1])))
            end
        end
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
