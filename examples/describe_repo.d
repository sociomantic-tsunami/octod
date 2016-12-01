#!/usr/bin/env dub
/+ dub.sdl:
name "example"
description "Script that fetched various information about content of the repo"
authors "Mihails Strasuns"
copyright "Copyright 2016, Sociomantic Labs"
license "Boost"

targetType "executable"
dependency "octod" version="*" path="../"
+/

import octod.core;
import octod.api.repos;

import std.stdio;

void main ( )
{
    Configuration conf;
    conf.dryRun = true;

    auto client = HTTPConnection.connect(conf);
    auto repo = client.repository("sociomantic-tsunami/ocean");

    writeln("-----------------------------------------------------------");
    writeln("List of known git tags belonging to GitHub release:");
    auto tags = repo.releasedTags();
    foreach (tag; tags)
        writefln("%s: %s", tag.name, tag.sha);

    writeln("-----------------------------------------------------------");
    writeln("Root directory content for the default branch:");
    writeln();
    writeln(repo.download("/").expectDirectory.listAll());

    writeln("-----------------------------------------------------------");
    writeln("Content of LICENSE file:");
    writeln();
    writeln(cast(const(char[])) repo.download("LICENSE.txt").expectFile.content());

    writeln("-----------------------------------------------------------");
    writeln("All submodules:");
    writeln();
    auto submodules = repo.download("submodules/").expectDirectory.listAll();
    foreach (submodule; submodules)
    {
        auto metadata = repo.download(submodule).expectSubmodule();
        writefln("%s: %s", metadata.url, metadata.sha);
    }
}
