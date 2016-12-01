/*******************************************************************************

    Provides wrappers on top of some methods documented in
    https://developer.github.com/v3/repos/

    Copyright: Copyright (c) 2016 Sociomantic Labs GmbH. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

*******************************************************************************/

module octod.api.repos;

import vibe.data.json;
import octod.core;
import octod.media;
import octod.api.common;

/**
    Aggregate for git tag description

    There are quite some places in GitHub JSON responses where tags are
    referred either by name or by sha exclusively. This API tries to provide
    both when feasible and wraps it with this struct.
 **/
struct Tag
{
    string name;
    string sha;
}

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

    /**
        Makes an API request to resolve specified git reference name to
        its SHA hash in this repo.

        Params:
            refname = git ref (like tag or branch) name

        Returns:
            SHA of commit matching the reference
     **/
    string resolveGitReference ( string refname )
    {
        import std.format;

        auto owner = this.json["owner"]["login"].get!string();
        auto name = this.name();
        auto url = format("/repos/%s/%s/commits/%s", owner, name, refname);
        auto json = this.connection.get(url, MediaType("", "sha"));
        return json.get!string();
    }

    /**
        Fetches repository tags filtered to only released ones

        This utility is useful for projects that strictly require all public
        releases to be actual GitHub releases, making possible to ignore any
        other tags that may exist in the project.

        There is a GitHub API to get both releases and tags, but former lacks
        SHA information and latter has no information about releases. This
        method makes request to both and merges information into one entity.

        Returns:
            array of tag structs for all GitHub releases in this repo
     **/
    Tag[] releasedTags ( )
    {
        import std.format;
        import std.array;
        import std.algorithm.iteration : map;
        import std.algorithm.searching : find;

        auto owner = this.json["owner"]["login"].get!string();
        auto name = this.name();

        auto url = format("/repos/%s/%s/releases", owner, name);
        auto json_releases = this.connection.get(url).get!(Json[]);

        url = format("/repos/%s/%s/tags", owner, name);
        auto json_tags = this.connection.get(url).get!(Json[]);

        Tag resolveTag ( Json release )
        {
            auto tag_name = release["tag_name"].get!string();
            auto tag = json_tags
                .find!(json => json["name"].get!string() == tag_name);
            assert (!tag.empty);
            return Tag(tag_name, tag.front["commit"]["sha"].to!string());
        }

        return json_releases
            .map!resolveTag
            .array();
    }
}

/**
    Fetch specific repository metadata

    Params:
        connection = setup connection to API server
        repo = repository string of form "owner/repo", for example
            "sociomantic-tsunami/ocean"

    Returns:
        Wrapper struct to work with that repo embedding the json metadata
 **/
Repository repository ( HTTPConnection connection, string repo )
{
    import std.format;

    validateRepoString(repo);

    return Repository(
        connection,
        connection.get(format("/repos/%s", repo))
    );
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
