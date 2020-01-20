# collection of interesting real and artificial error messages

"""
This creates a Method error where the candidates have a really long
signature.
"""
function longmethodsignatureerror()
    [1, 2] * [3, 4]
end


"""
The following three methods create an artificial error where the
exception is raised a few levels deeper.

This is used to generate a more interesting test stacktrace.
"""
function testerrorlevel3()
    throw("something happened!")
end
function testerrorlevel2()
    testerrorlevel3()
end
function testerrorlevel1()
    testerrorlevel2()
end
