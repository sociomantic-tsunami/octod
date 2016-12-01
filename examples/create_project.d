#!/usr/bin/env dub
/+ dub.sdl:
name "example"
description "Creation of new project with one card per repo"
authors "Mihails Strasuns"
copyright "Copyright 2016, Sociomantic Labs"
license "Boost"

targetType "executable"
dependency "octod" version="*" path="../"
+/

import octod;

import std.algorithm;
import std.array;

import vibe.data.json;

void main ( )
{
    Configuration conf;
    conf.oauthToken = "XXXXXXX";
    conf.accept = "application/vnd.github.inertia-preview+json";
    conf.dryRun = true;

    auto client = HTTPConnection.connect(conf);

    auto repos = client
        .listOrganizationRepos("sociomantic")
        .filter!(repo => repo.language() == "D")
        .map!(repo => repo.name())
        .array();

    auto project = client.createOrganizationProject(
        "sociomantic",
        "D2 migration progress",
        "Board tracking progress of D2 migration of all Sociomantic projects" ~
            " through various stages"
    );

    auto column = project.createColumn("Unported");
    project.createColumn("Stage 1: compiles with -v2");
    project.createColumn("Stage 2: .D2-ready in default branch");
    project.createColumn("Stage 3: tested live, no performance issues");
    project.createColumn("Stage 4: deployed with D2 build");

    foreach (repo; repos)
    {
        try
        {
            auto issue = client.createIssue(
                "sociomantic/" ~ repo,
                "D2 " ~ repo,
                issue_text
            );

            column.addCard(issue.id);
        }
        catch (Exception e)
        {
            continue;
        }
    }
}

string issue_text = "This issue is automatically created to act as a card for
Sociomantic D2 migration project board.

All other issues and pull request in this repository that are related to D2
migration should be referenced from this issue. It is highly appreciated
to provide short status reports on any breakthroughs in form of issue comments.

If this is not a D project (GitHub language detection is imperfect), please
both close the issue and remove matching card from the linked project.
";
