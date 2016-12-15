/*******************************************************************************

    Provides wrappers on top of some methods documented in
    https://developer.github.com/v3/repos/

    Copyright: Copyright (c) 2016 Sociomantic Labs GmbH. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

*******************************************************************************/

module octod.api.repos;

import vibe.data.json;
import octod.core;
import octod.api.common;

/**
    Wraps connection and repository metadata for simple shortcut access
    to repository related API methods. Arbitrary fields can be accessed
    via `json` getter.
 **/
struct Repository
{
    mixin CommonEntityMethods;

    /**
        Returns:
            repository name
     **/
    string name ( )
    {
        return this.json["name"].get!string();
    }

    /**
        Returns:
            programming language used for majority of repository files
     **/
    string language ( )
    {
        return this.json["language"].get!string();
    }
}

/**
    Lists all repos for given organization

    Params:
        connection = setup connection to API server
        name = organization name
        type = project filter to use, as defined by
            https://developer.github.com/v3/repos/#list-organization-repositories

    Returns:
        Array of json objects one per each repo
 **/
Repository[] listOrganizationRepos ( HTTPConnection connection, string name,
    string type = "sources" )
{
    import std.format;
    import std.exception : enforce;
    import std.algorithm : map, canFind;
    import std.array;

    enforce!APIException(
        canFind(["all", "public", "private", "forks", "sources", "member"], type),
        "Unknown repository filter type"
    );

    auto url = format("/orgs/%s/repos?type=%s", name, type);
    auto json = connection.get(url);

    return json
        .get!(Json[])
        .map!(elem => Repository(connection, elem))
        .array();
}
