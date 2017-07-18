/*******************************************************************************

    Provides wrappers on top of some methods documented in
    https://developer.github.com/v3/repos/releases/

    Copyright: Copyright (c) 2016 Sociomantic Labs GmbH. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

*******************************************************************************/

module octod.api.releases;

import octod.api.repos;
import octod.core;

/*******************************************************************************

    Creates a new release on github

    Params:
        connection = connection to use
        repo = repository object
        tag  = tag used for the release
        title = title for the release
        content = content of the release

*******************************************************************************/

public void createRelease ( ref HTTPConnection connection, ref Repository repo,
                            string tag, string title, string content )
{
    import std.format;
    import vibe.data.json;

    auto owner = repo.json["owner"]["login"].get!string();
    auto name = repo.name();

    Json json = Json.emptyObject;
    json["tag_name"] = tag;
    json["name"] = title;
    json["body"] = content;
    json["target_committish"] = tag;

    auto url = format("/repos/%s/%s/releases", owner, name);

    connection.post(url, json);
}
