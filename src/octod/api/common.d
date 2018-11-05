/*******************************************************************************

    Code shared between higher level GitHub API wrappers, mostly related
    to error handling.

    Copyright: Copyright (c) 2016 dunnhumby Germany GmbH. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

*******************************************************************************/

module octod.api.common;

/**
    Thrown upon any higher level API violations

    Typical example would be trying to use API methods with wrong
    arguments.
 **/
class APIException : Exception
{
    this ( string msg, string file = __FILE__, ulong line = __LINE__ )
    {
        super(msg, file, line);
    }
}

/**
    Thrown in methods that should return wrapper for specific entity (issue,
    repository etc) but the requested one does not exist.
 **/
class EntityNotFound : APIException
{
    this ( string msg, string file = __FILE__, ulong line = __LINE__ )
    {
        super(msg, file, line);
    }
}

package(octod.api):

/**
    Params:
        repo = repository string, must be owner/name format

    Throws:
        APIException if string format does not match
 **/
void validateRepoString ( string repo )
{
    import std.regex;
    import std.exception : enforce;

    static rgxRepo = regex(r"^[^/]+/[^/]+$");
    auto match = repo.matchFirst(rgxRepo);
    enforce!APIException(!match.empty, "Malformed repository string");
}

/**
    Mixes in common fields used by all wrappers on top of API entities like
    issue or repository.
 **/
mixin template CommonEntityMethods ( )
{
    @disable this();

    private
    {
        HTTPConnection* connection;

        this ( HTTPConnection* connection, const Json json )
        {
            this.json = json;
            this.connection = connection;
        }
    }

    const Json json;
}
