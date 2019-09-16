using Serialization

ticketdir = joinpath(@__DIR__, "../tickets")
setticketdir(dir) = (global ticketdir = dir)

# TODO: create random ids (integers) until no ticket (file) for that id exists
function uniqueid()
    ids = (tryparse(Int, y) for y in readdir(ticketdir))
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
end
TicketData(err, bt) = TicketData(uniqueid(), err, bt)

"""Return the path of the file for the passed ticket."""
ticketfile(id::AbstractString) = joinpath(ticketdir, id)
ticketfile(err::TicketData) = ticketfile(id(err))

"""Save the passed ticket to file system."""
storeticket(err) = serialize(ticketfile(err), err)
"""Load the ticket with the passed id from file system."""
function loadticket(id::AbstractString)
    file = ticketfile(id)
    !isfile(file) && return nothing

    try
        deserialize(file)
    catch EOFError
        return nothing
    end
end

TicketData(id::AbstractString) = loadticket(id)

"""Return the ticket id of the error object."""
id(err::TicketData) = err.id





"""
Print general and ticket specific help for the passed ticket.

TODO: actually try to load the ticket and print special help depending on
error type.
"""
help(id::AbstractString) = println("""
Using the ticket id '$id' there are several ways you can get more
information on the error. For example:

showticket('$id') will reprint the error message.

You can always omit the ticket id and the last displayed ticket will be used.
""")

"""Print the passed ticket in default style."""
function showticket(data::TicketData)
    showerror(IOContext(stdout, :fullpath=>false),
        data.err, data.bt, backtrace=true)
    global lastticket = data
    println("\nFor more information on this error see `help('$(id(data))')")
end
showticket(x::Nothing) = println("No ticket with the passed id found!")
showticket(id::AbstractString) = showticket(loadticket(id))
showticket() = showticket(lastticket)

"""
Execute the passed expression and in case an error is thrown create and
display a ticket for that error.

Note that the createticket macro catches the exception, prints the ticket
for it but does not forward the original exception, instead it just returns
nothing.

This means that although `sin('a')` throws a MethodError
`@createticket sin('a')` does not, instead it just returns `nothing`.

TODO: The stack trace of the error is different from the stacktrace when
the error happens without using `createticket` in the way that it includes the
call to createticket. In the future this line should be removed from the backtrace.

TODO: it would also be nice if the macro would return the TicketData object
created, but that doesn't work yet...
"""
macro createticket(e)
    return quote
        try
            $(esc(e))
        catch err
            data = TicketData(err, catch_backtrace())
            storeticket(data)
            showticket(data)
        end
    end
end
