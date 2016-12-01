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

    /**
        Provides access to repository content

        Params:
            path = relative path in the repository to request
            gitref = branch/tag to use. If empty, default branch will be used.

        Returns:
            information about found entity (file/directory/submodule/symlink)
            stored in a wrapper struct
     **/
    RepositoryEntity download ( string path, string gitref = "" )
    {
        import std.format;

        auto url = format(
            "/repos/%s/%s/contents/%s",
            this.json["owner"]["login"].get!string(),
            this.name(),
            path
        );

        if (gitref.length)
            url ~= "?ref=" ~ gitref;

        return RepositoryEntity(this.connection.get(url));
    }
}

/**
    Struct representing some entity stored in a git repository

    Exact kind of entity can be checked by calling `RepositoryEntity.kind`, and
    more strongly typed wrapper structs can be retrieved by
    `RepositoryEntity.expectXXX` methods.
 **/
struct RepositoryEntity
{
    /**
        Represents a file stored in the repository
     **/
    static struct File
    {
        const Json json;

        private this ( Json json )
        {
            this.json = json;
        }

        /**
            Returns:
                Decoded content of the file (if < 1Mb)
         **/
        immutable(void)[] content ( )
        {
            import std.exception : enforce;
            import std.base64;
            import std.range : join;
            import std.algorithm : splitter;

            enforce!HTTPAPIException(
                this.json["encoding"].get!string()== "base64");

            auto encoded = this.json["content"].get!string();
            // GitHub provides base64 with newlines injected to enable per-line
            // decoding, those have to be removed here
            return Base64.decode(encoded.splitter("\n").join(""));
        }
    }

    /**
        Represents a directory stored in the repository
     **/
    static struct Directory
    {
        const Json json;

        private this ( Json json )
        {
            this.json = json;
        }

        /**
            Returns:
                Array of paths for entities within this directory. Paths are
                relative to repository root.
         **/
        const(string)[] listAll ( )
        {
            import std.algorithm.iteration : map;
            import std.array;

            return this.json
                .get!(Json[])
                .map!(element => element["path"].get!string())
                .array();
        }
    }

    /**
        Represents a submodule linked from the repository
     **/
    static struct Submodule
    {
        const Json json;

        private this ( Json json )
        {
            this.json = json;
        }

        /**
            Returns:
                linked submodule hash
         **/
        string sha ( )
        {
            return this.json["sha"].get!string();
        }

        /**
            Returns:
                linked submodule git URL
         **/
        string url ( )
        {
            return this.json["submodule_git_url"].get!string();
        }
    }

    /**
        Raw entity metadata JSON

        See https://developer.github.com/v3/repos/contents/#get-contents for
        more details
     **/
    const Json json;

    /**
        Returns:
            typeid of whatever kind of entity stored metadata describes
     **/
    TypeInfo kind ( )
    {
        if (this.json.type() == Json.Type.Array)
            return typeid(RepositoryEntity.Directory);

        switch (this.json["type"].get!string())
        {
            case "file":
                return typeid(RepositoryEntity.File);
            case "submodule":
                return typeid(RepositoryEntity.Submodule);
            case "symlink":
            default:
                assert(false);
        }
    }

    /**
        Returns:
            current entity wrapped as RepositoryEntity.File

        Throws:
            HTTPAPIException on expectation violation
     **/
    File expectFile ( )
    {
        import std.exception : enforce;
        enforce!HTTPAPIException(this.kind == typeid(RepositoryEntity.File));
        return File(json);
    }

    /**
        Returns:
            current entity wrapped as RepositoryEntity.Directory

        Throws:
            HTTPAPIException on expectation violation
     **/
    Directory expectDirectory ( )
    {
        import std.exception : enforce;
        enforce!HTTPAPIException(this.kind == typeid(RepositoryEntity.Directory));
        return Directory(json);
    }

    /**
        Returns:
            current entity wrapped as RepositoryEntity.Submodule

        Throws:
            HTTPAPIException on expectation violation
     **/
    Submodule expectSubmodule ( )
    {
        import std.exception : enforce;
        enforce!HTTPAPIException(this.kind == typeid(RepositoryEntity.Submodule));
        return Submodule(json);
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
