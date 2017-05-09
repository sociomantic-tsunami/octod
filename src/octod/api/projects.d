/*******************************************************************************

    Provides wrappers on top of some methods documented in
    https://developer.github.com/v3/projects/

    Relevant GitHub API is considerably more convoluted compared to old ones.
    Because of that, this module features different design than other API
    modules - functions return wrapper objects providing further nested
    methods instead of raw json.

    Copyright: Copyright (c) 2016 Sociomantic Labs GmbH. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

*******************************************************************************/

module octod.api.projects;

import octod.core;
import octod.media;
import octod.api.common;

import vibe.data.json;

/**
    Project API is experimental, thus relevant requests have to use
    specific media type.
 **/
enum ProjectMediaType = "application/vnd.github.inertia-preview+json";

/**
    Lists all projects for given organization

    NB: this requires connection to be setup with `Configuration.accept` set
    to "application/vnd.github.inertia-preview+json". Relevant GitHub API
    may change without noticed.

    Params:
        connection = setup connection to API server
        organization = organization name

    Returns:
        Array of project wrapper structs
 **/
Project[] listOrganizationProjects ( ref HTTPConnection connection, string organization )
{
    import std.algorithm : map;
    import std.array : array;
    import std.format;

    auto url = format("/orgs/%s/projects", organization);
    auto json = connection.get(url, ProjectMediaType);
    return json
        .get!(Json[])
        .map!(json => Project(&connection, json))
        .array();
}

/**
    Creates new project in a given organization

    NB: this requires connection to be setup with `Configuration.accept` set
    to "application/vnd.github.inertia-preview+json". Relevant GitHub API
    may change without noticed.

    Params:
        connection = setup connection to API server
        organization = organization name
        name = project name
        text = optional project description

    Returns:
        wrapper struct for created project
 **/
Project createOrganizationProject ( ref HTTPConnection connection,
    string organization, string name, string text = "" )
{
    import std.format;

    auto url = format("/orgs/%s/projects", organization);
    auto json = connection.post(
        url,
        Json([
            "name" : Json(name),
            "body" : Json(text)
        ])
    );

    return Project(&connection, json);
}

/**
    Abstraction for one GitHub project.

    Internally stores project metadata and connection to API server. Provides
    methods to manipulate that project columns easily.
 **/
struct Project
{
    mixin CommonEntityMethods;

    /**
        Returns:
            project id, unique among all organizations
     **/
    long id ( )
    {
        return this.json["id"].get!long();
    }

    /**
        Fetches all columns defined for this project board

        Returns:
            array of column wrapper structs
     **/
    Column[] listColumns ( )
    {
        import std.format;
        import std.algorithm : map;
        import std.array : array;

        auto url = format("/projects/%s/columns", this.id());
        auto json = connection.get(url, ProjectMediaType);

        return json
            .get!(Json[])
            .map!(json => Column(connection, json))
            .array();
    }

    /**
        Tries to find project board column with certain name

        Params:
            name = column name to look for

        Returns:
            column wrapper struct if it exists, null otherwise

        Throws:
            EntityNotFound if requested column is not found
     **/
    Column getColumn ( string name )
    {
        import std.algorithm.searching;
        auto columns = this.listColumns();
        columns = columns.find!(column => column.name == name);
        if (columns.length > 0)
            return columns[0];
        throw new EntityNotFound("Column '" ~ name ~ "' not found");
    }

    /**
        Creates new column in this project board

        Params:
            name = column name to create

        Returns:
            column wrapper struct for created column
     **/
    Column createColumn ( string name )
    {
        import std.format;

        auto url = format("/projects/%s/columns", this.id());
        auto json = connection.post(url, Json([ "name" : Json(name) ]));

        return Column(connection, json);
    }
}

/**
    Wraps connection and issue metadata for simple shortcut access to
    project board column related API methods. Arbitrary fields can be accessed
    via `json` getter.
 **/
struct Column
{
    mixin CommonEntityMethods;

    /**
        Returns:
            column name as shown in GitHub web UI
     **/
    string name ( )
    {
        return this.json["name"].get!string();
    }

    /**
        Returns:
            column id, unique among all organizations and projects
     **/
    long id ( )
    {
        return this.json["id"].get!long();
    }

    /**
        Fetches all cards assigned to this board column

        Returns:
            array of json objects for card metadata
     **/
    Card[] listCards ( )
    {
        import std.format;
        import std.algorithm.iteration : map;
        import std.array;

        auto url = format("/projects/columns/%s/cards", this.id());
        auto json = connection.get(url, ProjectMediaType);

        return json
            .get!(Json[])
            .map!(element => Card(connection, element))
            .array();
    }

    /**
        Adds existing issue as a new card to this column.

        Internally does extra API query to figure out unique issue ID
        based on repo+number.

        Params:
            repo = repository string of form "owner/repo", for example
                "sociomantic-tsunami/ocean"
            number = issue number in that repository

        Returns:
            json object for created card metadata
     **/
    Card addCard ( string repo, long number )
    {
        import octod.api.issues : getIssue;

        auto issue_id = (*this.connection).getIssue(repo, number).id();
        return this.addCard(issue_id);
    }

    /**
        Adds existing issue as a new card to this column.

        Params:
            issue = id of the issue. It is NOT issue number as visible
                in the repository.

        Returns:
            json object for created card metadata
     **/
    Card addCard ( long issue )
    {
        import std.format;

        auto url = format("/projects/columns/%s/cards", this.id());

        return Card(
            connection,
            connection.post(
                url,
                Json([
                    "content_type" : Json("Issue"),
                    "content_id"   : Json(issue)
                ])
            )
        );
    }

}

/**
    Wraps connection and issue metadata for simple shortcut access
    to card related API methods. Arbitrary fields can be accessed
    via `json` getter.
 **/
struct Card
{
    mixin CommonEntityMethods;
}
