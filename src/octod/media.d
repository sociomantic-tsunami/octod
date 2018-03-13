/*******************************************************************************

    Wraps media type string used for interaction with GitHub as defined
    by https://developer.github.com/v3/media

    Copyright: Copyright (c) 2016 Sociomantic Labs GmbH. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

*******************************************************************************/

module octod.media;

/**
    Enumerates some of commonly used formats
 **/
 enum MediaFormat
 {
     JSON = "json",
     XML  = "xml",
 }

 /**
    Enumerates known versions
  **/
enum ProtocolVersion
{
    V3 = "v3",
    JeanGreyPreview = "jean-grey-preview",
}

/**
    Stores sub-parts of media type string as separate fields. Simplifies
    branching based on media types and safeguards against some typos in the
    string.
 **/
struct MediaType
{
    /// Media type used by default if none is specified by user of the library
    enum Default = MediaType.init;
    /// Media type that is basically v3 with a v4 extra attribute "node_id"
    enum JeanGreyPreview =
        MediaType(true, ProtocolVersion.JeanGreyPreview, "", MediaFormat.JSON);

    immutable
    {
        /**
            Indicates if this media type is of "vnd.github" ones. If set to
            `false`, this becomes simple `application/something` media type.
         **/
        bool   github_marker = true;
        /**
            API version to be used for the request. If empty, GitHub will
            assume whatever default API version currently is.
         **/
        string ver           = ProtocolVersion.V3;
        /**
            Custom parameters, usually indicate kind of content to serve
            (for example, rendered markdown or raw source)
         **/
        string param         = "";
        /**
            Format of response data, usually "json" or "xml"
         **/
        string format        = MediaFormat.JSON;
    }

    /**
        Constructor for constructing most common media type
        directly (as opposed to string parsing)

        Params:
            format = format of response data (for example "json")
            param = any custom parameters (for example "raw")
     **/
    this ( string format, string param = "" )
    {
        this.param = param;
        this.format = format;
    }

    /**
        Constructor for arbitrary setting of all fields, private usage
        only

        Params:
            format = format of response data (for example "json")
            param = any custom parameters (for example "raw")
     **/
    private this ( bool github_marker, string ver, string param, string format )
    {
        this(format, param);
        this.github_marker = github_marker;
        this.ver = ver;
    }

    /**
        Returns:
            string representation that can be used as `Accept` HTTP header
     **/
    string toString ( )
    {
        import std.format;

        if (!this.github_marker)
            return std.format.format("application/%s", format);
        else
        {
            return std.format.format(
                "application/vnd.github%s%s%s",
                this.ver.length ? "." ~ this.ver : "",
                this.param.length ? "." ~ this.param : "",
                this.format.length ? "+" ~ this.format : ""
            );
        }
    }

    unittest
    {
        assert(MediaType(true, "v2", "", "xml").toString()
            == "application/vnd.github.v2+xml");
        assert(MediaType.init.toString()
            == "application/vnd.github.v3+json");
        assert(MediaType.JeanGreyPreview.toString()
            == "application/vnd.github.jean-grey-preview+json");
    }

    /**
        Params:
            media_type = string in the same format as expected by GitHub
                via `Accept` header

        Returns:
            MediaType instance which contains same media type but split by
            fields
     **/
    static typeof(this) parse ( string media_type )
    {
        import std.regex;
        import std.exception;

        static rgxPlain = regex(r"^application/([^.+]+)$");
        auto groups = media_type.matchFirst(rgxPlain);
        if (!groups.empty)
            return MediaType(false, "", "", groups[1]);

        static rgxGithub =
            regex(r"^application\/vnd.github(\.([^+.]+))?(\.([^+]+))?(\+(.+))?$");

        groups = media_type.matchFirst(rgxGithub);
        enforce(!groups.empty);
        return MediaType(
            true,
            groups[2],
            groups[4],
            groups[6]
        );
    }

    unittest
    {
        auto mt = MediaType.parse("application/vnd.github.inertia-preview+json");
        assert(mt.github_marker);
        assert(mt.ver == "inertia-preview");
        assert(mt.param == "");
        assert(mt.format == "json");
    }

    unittest
    {
        auto mt = MediaType.parse("application/sha");
        assert(!mt.github_marker);
        assert(mt.ver == "");
        assert(mt.param == "");
        assert(mt.format == "sha");
    }

    unittest
    {
        auto mt = MediaType.parse("application/vnd.github.v3.html");
        assert(mt.github_marker);
        assert(mt.ver == "v3");
        assert(mt.param == "html");
        assert(mt.format == "");
    }

    unittest
    {
        auto mt = MediaType.parse("application/vnd.github.v3.raw+xml");
        assert(mt.github_marker);
        assert(mt.ver == "v3");
        assert(mt.param == "raw");
        assert(mt.format == "xml");
    }
}
