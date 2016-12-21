/*******************************************************************************

    Provides wrappers on top of some methods documented in
    https://developer.github.com/v3/issues/

    Copyright: Copyright (c) 2016 Sociomantic Labs GmbH. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

*******************************************************************************/

module octod.api.issues;

import std.exception : enforce;
import vibe.data.json;
import octod.core;
import octod.api.common;

/**
    Wraps connection and issue metadata for simple shortcut access
    to repository related API methods. Arbitrary fields can be accessed
    via `json` getter.
 **/
struct Issue
{
    mixin CommonEntityMethods;

    /**
        Returns:
            issue title
     **/
    string title ( )
    {
        return this.json["title"].get!string();
    }

    /**
        Returns:
            issue number as shown in web UI
     **/
    long number ( )
    {
        return this.json["number"].get!long();
    }

    /**
        Returns:
            internally used unique issue identifier
     **/
    long id ( )
    {
        return this.json["id"].get!long();
    }
}

/**
    Creates new issues in specified repository

    Params:
        connection = setup connection to API server
        repo = repository string of form "owner/repo", for example
            "sociomantic-tsunami/ocean"
        title = new issue title
        text = new issue body text
        base = json object used as a request base, can contain any additional
            fields as defined by
            https://developer.github.com/v3/issues/#create-an-issue

    Returns:
        created issue
 **/
Issue createIssue ( HTTPConnection connection, string repo, string title,
    string text, Json base = Json.emptyObject )
{
    validateRepoString(repo);

    base["title"] = title;
    base["body"]  = text;

    return Issue(
        connection,
        connection.post("/repos/" ~ repo ~ "/issues", base)
    );
}

/**
    Modifies existing issues with known number in specified repository

    Params:
        connection = setup connection to API server
        repo = repository string of form "owner/repo", for example
            "sociomantic-tsunami/ocean"
        number = issue number to modify
        modificiations = json object with fields to modify, must comply to
            https://developer.github.com/v3/issues/#edit-an-issue
 **/
void modifyIssue ( HTTPConnection connection, string repo, long number,
    Json modifications )
{
    import std.format;

    validateRepoString(repo);

    auto json = connection.patch(format("/repos/%s/issues/%s", repo, number),
        modifications);
}

/**
    Fetches one issue description/metadata

    Params:
        connection = setup connection to API server
        repo = repository string of form "owner/repo", for example
            "sociomantic-tsunami/ocean"
        number = issue number to fetch
 **/
Issue getIssue ( HTTPConnection connection, string repo, long number )
{
    import std.format;

    validateRepoString(repo);

    return Issue(connection,
        connection.get(format("/repos/%s/issues/%s", repo, number)));
}

/**
    Fetches all repo issues description/metadata

    Params:
        connection = setup connection to API server
        repo = repository string of form "owner/repo", for example
            "sociomantic-tsunami/ocean"
 **/
Issue[] listIssues ( HTTPConnection connection, string repo )
{
    import std.format;
    import std.algorithm.iteration : map;
    import std.array;

    validateRepoString(repo);

    return connection
        .get(format("/repos/%s/issues", repo))
        .get!(Json[])
        .map!(element => Issue(connection, element))
        .array();
}
