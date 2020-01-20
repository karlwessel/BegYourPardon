using Serialization

ticketdir = joinpath(@__DIR__, "../tickets")
setticketdir(dir) = (global ticketdir = dir)

# TODO: create random ids (integers) until no ticket (file) for that id exists
function uniqueid()
    ids = union(readdir(ticketdir), keys(ticketcache))
    ids = (tryparse(Int, y) for y in ids)
    validids = (x for x in ids if !isnothing(x))
    isempty(validids) && return "1"
    return string(maximum(validids) + 1)
end

lastticket = nothing


"""Stores all available data for a ticket."""
struct TicketData
    id
    err
    bt
    red
    function TicketData(id, err, bt, red)
        if !(id in keys(ticketcache))
            ticket = new(id, err, bt, red)
            global ticketcache[id] = ticket
        else
            ticket = ticketcache[id]
        end
        return ticket
    end
end
ticketcache = Dict{String, TicketData}()
TicketData(err, bt) =
    TicketData(uniqueid(), err, bt, Base.process_backtrace(bt))

"""Return the path of the file for the passed ticket."""
ticketfile(id::AbstractString) = joinpath(ticketdir, id)
ticketfile(err::TicketData) = ticketfile(id(err))

"""Save the passed ticket to file system."""
storeticket(err) = serialize(ticketfile(err), err)
"""Load the ticket with the passed id from file system."""
function loadticket(id::AbstractString)
    id in keys(ticketcache) && return ticketcache[id]

    file = ticketfile(id)
    !isfile(file) && return nothing

    try
        ticket = deserialize(file)
        global ticketcache[id] = ticket
        return ticket
    catch EOFError
        return nothing
    end
end

TicketData(id::AbstractString) = loadticket(id)

"""Return the ticket id of the error object."""
id(err::TicketData) = err.id





"""
Print general and error specific help for the error with the passed id.

TODO: actually try to load the error and print special help depending on
error type.
"""
help(id::AbstractString) = println("""
Using the error id '$id' there are several ways you can get more
information on the error. For example:

showerror('$id') will reprint the error message.

You can always omit the error id and the last displayed error will be used.
""")

"""Print the error with the passed id in default style."""
function Base.showerror(data::TicketData)
    showerror(IOContext(stdout, :fullpath=>false),
        data.err, data.bt, backtrace=true)
    global lastticket = data
    println("""\nFor more information on this error see `help("$(id(data))")`""")
end
Base.showerror(x::Nothing) = println("No error with the passed id found!")
Base.showerror(id::AbstractString) = showerror(loadticket(id))
Base.showerror() = showerror(lastticket)

"""
Execute the passed expression and in case an error is thrown create and
display an id for that error.

Note that the comeagain macro catches the exception, prints the error
for it but does not forward the original exception, instead it just returns
nothing.

This means that although `sin('a')` throws a MethodError
`@comeagain sin('a')` does not, instead it just returns `nothing`.

TODO: The stack trace of the error is different from the stacktrace when
the error happens without using `comeagain` in the way that it includes the
call to comeagain. In the future this line should be removed from the backtrace.

TODO: it would also be nice if the macro would return the TicketData object
created, but that doesn't work yet...
"""
macro comeagain(e)
    return quote
        try
            $(esc(e))
        catch err
            data = TicketData(err, catch_backtrace())
            storeticket(data)
            showerror(data)
        end
    end
end

