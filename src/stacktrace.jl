using BegYourPardon: TicketData, loadticket

function testerrorlevel3()
    throw("something happened!")
end

function testerrorlevel2()
    testerrorlevel3()
end

function testerrorlevel1()
    testerrorlevel2()
end

function filepackage(file)
	file = abspath(file)
	findlast("julia/base", file) != nothing && return "base"
	findlast("./", file) != nothing && return "base"

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

using Base.StackTraces

function showbacktrace(ticket::TicketData)
    filtered = ticket.red
    frame_counter = 0
    io = IOContext(stdout, :backtrace => true)
    print(io, """
    Reading this backtrace top down gives you the function calls in order
      '[1] called [2] called ... called [n]'
    where '[n]' is the function in which the error occured.

    Execution started in """)
    for (last_frame, n) in reverse(filtered)
        frame_counter += 1

        print(io, "\n [", frame_counter, "] ")
        shownew(io, last_frame, full_path=true)
        n > 1 && print(io, " (repeats ", n, " times)")

        if frame_counter != size(filtered, 1)
            print(io, "\n\tcalled ")
        else
            print(io, "\n\traised the exception.")
        end
    end
end
showbacktrace(id) = showbacktrace(loadticket(id))

function shownew(io::IO, frame::Base.StackFrame; full_path::Bool=false)
    Base.StackTraces.show_spec_linfo(io, frame)
    if frame.file !== Base.StackTraces.empty_sym
		println()
        print(io, "\twhich in line ")
        Base.with_output_color(get(io, :color, false) && get(io, :backtrace, false) ? Base.stackframe_lineinfo_color() : :nothing, io) do io
	        if frame.line >= 0
                print(io, frame.line)
            else
                print(io, "?")
            end
        end
		print(io, " in")
		Base.with_output_color(get(io, :color, false) && get(io, :backtrace, false) ? Base.stackframe_lineinfo_color() : :nothing, io) do io
			showpath(io, frame.file)
        end
    end
end
