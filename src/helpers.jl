struct HelpIO <: IO
    parent::IO
end

for op ∈ [String, Symbol, Char, UInt8]
    @eval write(io::HelpIO, x::$op) = write(io.parent, x)
end
get(io::HelpIO, key, default) = get(io.parent.dict, key, default)

function begyourpardon()
    # reprint the last output with limit enabled
    lio = HelpIO(IOContext(stdout, :limit => true))

    # get the last shown value
    last = Main.ans

    # if there wasn't one, assume there was an exception and recatch it
    if last == nothing
        try
            rethrow()
        catch e
            showerror(lio, e, catch_backtrace(), backtrace=true)
        end
    else
        show(lio, last)
    end
end

byp = begyourpardon
