
last = nothing
function begyourpardon(collapsein=0)
    # reprint the last output with limit enabled
    lio = IOContext(stdout, :collapsein => collapsein)

    # get the last shown value
    last = Main.ans

    # if there wasn't one, assume there was an exception and recatch it
    if last == nothing
        try
            rethrow()
        catch e
            last = e
        end
        showerror(lio, last)
    else
        show(lio, last)
    end
end

macro comeagain(e, collapsein=0)
    return quote
        try
            $e
        catch err
            showerror(IOContext(stdout, :collapsein => $collapsein, :fullpath=>false), err,
                catch_backtrace(), backtrace=true)
        end
    end
end

byp = begyourpardon
