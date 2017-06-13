/*******************************************************************************

    Implements persistent HTTP connection to GitHub API server which provides
    basic get/post/patch methods taking care of API details internally (like
    auth or multi-page responses).

    Copyright: Copyright (c) 2016 Sociomantic Labs GmbH. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

*******************************************************************************/

module octod.core;

import std.exception : enforce;

import vibe.http.client;
import vibe.data.json;
import vibe.core.log;

import octod.media;

/**
    Configuration required to interact with GitHub API
 **/
struct Configuration
{
    /// URL prepended to all API requests
    string baseURL = "https://api.github.com";
    /// If present, will be used as auth username
    string username;
    /// If 'this.username' is present, will be used as auth password
    string password;
    /// If 'this.username' is empty, will be used as auth token
    string oauthToken;
    /// By default client works in live mode
    bool dryRun = false;
}

/**
    Thrown upon any protocol/connection issues when trying to
    interact with API HTTP server.
 **/
class HTTPAPIException : Exception
{
    this ( string msg, string file = __FILE__, ulong line = __LINE__ )
    {
        super(msg, file, line);
    }
}

/**
    Wrapper on top of vibe.d `connectHTTP`, describing persistent HTTP
    connection to GitHub API server and providing convenience
    `get`/`post`/`patch` methods taking care of GitHub HTTP specifics.

    Does not implement any of higher level API interpretation, instead should
    be used as a core facilities for such util.

    Currently does not expose any of returned HTTP headers - it is not yet
    clear if this will be necessary for implementing more complex API
    methods.
 **/
struct HTTPConnection
{
    private
    {
        alias Connection = typeof(connectHTTP(null, 0, false));
        Connection connection;

        Configuration config;
    }

    /**
        Setups new connection instance and attempts connecting to the
        configured API server.

        Params:
            config = configuration used for interacting with API server

        Returns:
             instance of this struct connected to the API server and ready to
             start sending requests
     **/
    static HTTPConnection connect ( Configuration config )
    {
        auto conn = typeof(this)(config);
        conn.connect();
        return conn;
    }

    /**
        Constructor

        `connect` method must be called on constructed instance before
        it gets into usable state.

        Params:
            config = configuration used for interacting with API server
     **/
    this ( Configuration config )
    {
        import std.string : startsWith;

        if (config.oauthToken.length > 0)
        {
            if (!config.oauthToken.startsWith("bearer "))
                config.oauthToken = "bearer " ~ config.oauthToken;
        }

        this.config = config;
    }

    /**
        Creates vibe.d persistent HTTP(S) connection to configured API
        server.

        Requires configured base URL to define explicit protocol (HTTP or HTTPS)
     **/
    void connect ( )
    {
        assert(this.connection is null);

        import std.regex;

        logTrace("Connecting to GitHub API server ...");

        static rgxURL = regex(r"^(\w*)://([^/]+)$");
        auto match = this.config.baseURL.matchFirst(rgxURL);

        enforce!HTTPAPIException(
            match.length == 3,
            "Malformed API base URL in configuration: " ~ this.config.baseURL
        );

        string addr = match[2];
        ushort port;
        bool   tls;

        switch (match[1])
        {
            case "http":
                port = 80;
                tls = false;
                break;
            case "https":
                port = 443;
                tls = true;
                break;
            default:
                throw new HTTPAPIException("Protocol not supported: " ~ match[1]);
        }

        this.connection = connectHTTP(addr, port, tls);

        logTrace("Connected.");
    }

    /**
        Sends GET request to API server

        Params:
            url = GitHub API method URL (relative)
            accept = optional argument with custom `Accept` header to
                specify for this one request

        Returns:
            Json body of the response. If response is multi-page, all pages
            are collected and concatenated into one returned json object.
     **/
    Json get ( string url, MediaType accept )
    {
        assert (this.connection !is null);

        logTrace("GET %s", url);

        if (this.config.dryRun)
            return Json.emptyObject;

        // initialize result as array - if actual response isn't array, it
        // will be overwritten by assignement anyway, otherwise it allows
        // easy concatenation of multi-page results

        Json result = Json.emptyArray;
        HTTPClientResponse response;

        url = this.config.baseURL ~ url;

        while (true)
        {
            response = this.connection.request(
                (scope request) {
                    request.requestURL = url;
                    request.method = HTTPMethod.GET;
                    this.prepareRequest(request, accept.toString());
                }
            );

            scope(exit)
                response.dropBody();

            if (auto location = this.handleResponseStatus(response))
            {
                url = location;
                continue;
            }

            // Most responses are JSON, treat all others as plain text and
            // wrap result into JSON string:
            if (accept.format != MediaFormat.JSON)
            {
                import vibe.stream.operations;
                return Json(response.bodyReader.readAllUTF8());
            }

            auto json = response.readJson();
            if (json.type == Json.Type.Array)
            {
                foreach (element; json.get!(Json[]))
                    result.appendArrayElement(element);
            }
            else
                result = json;

            // GitHub splits long response lists into several "pages", each
            // needs to be retrieved by own request. If pages are present,
            // they are defined in "Link" header:

            import std.regex;

            static rgxLink = regex(`<([^>]+)>;\s+rel="next"`);

            if (auto link = "Link" in response.headers)
            {
                assert(result.type == Json.Type.Array);

                auto match = (*link).matchFirst(rgxLink);
                if (match.length == 2)
                    url = match[1];
                else
                    break;
            }
            else
                break;
        }

        return result;
    }

    /**
        ditto
     **/
    Json get ( string url, string accept = "" )
    {
        return this.get(url, accept.length
            ? MediaType.parse(accept) : MediaType.Default);
    }

    /**
        Sends POST request to API server

        Params:
            url = GitHub API method URL (relative)
            json = request body to send
            accept = optional, request media type

        Returns:
            Json body of the response.
     **/
    Json post ( string url, Json json, MediaType accept )
    {
        assert (this.connection !is null);

        logTrace("POST %s", url);

        if (this.config.dryRun)
            return Json.emptyObject;

        auto response = this.connection.request(
            (scope request) {
                request.requestURL = url;
                request.method = HTTPMethod.POST;
                this.prepareRequest(request, accept.toString());
                request.writeJsonBody(json);
            }
        );

        scope(exit)
            response.dropBody();

        if (auto location = this.handleResponseStatus(response))
        {
            return this.post(location, json);
        }

        return response.readJson();
    }

    /**
        ditto
     **/
    Json post ( string url, Json json, string accept = "")
    {
        return this.post(url, json, accept.length
            ? MediaType.parse(accept) : MediaType.Default);
    }

    /**
        Sends PATCH request to API server

        Params:
            url = GitHub API method URL (relative)
            json = request body to send
            accept = optional, request media type

        Returns:
            Json body of the response.
     **/
    Json patch ( string url, Json json, MediaType accept )
    {
        assert (this.connection !is null);

        logTrace("PATCH %s", url);

        if (this.config.dryRun)
            return Json.emptyObject;

        auto response = this.connection.request(
            (scope request) {
                request.requestURL = url;
                request.method = HTTPMethod.PATCH;
                this.prepareRequest(request, accept.toString());
                request.writeJsonBody(json);
            }
        );

        scope(exit)
            response.dropBody();

        if (auto location = this.handleResponseStatus(response))
        {
            return this.patch(location, json);
        }

        return response.readJson();
    }

    /**
        ditto
     **/
    Json patch ( string url, Json json, string accept = "")
    {
        return this.post(url, json, accept.length
            ? MediaType.parse(accept) : MediaType.Default);
    }

    /**
        Common request setup code shared by all request kinds

        Params:
            request = vibe.d request object to prepare
            accept = optional argument with custom `Accept` header to
                specify for this one request
     **/
    private void prepareRequest ( scope HTTPClientRequest request,
        string accept = "" )
    {
        import vibe.http.auth.basic_auth : addBasicAuth;

        if (this.config.username.length > 0)
            request.addBasicAuth(this.config.username, this.config.password);
        else if (this.config.oauthToken.length > 0)
            request.headers["Authorization"] = this.config.oauthToken;

        if (accept.length)
            request.headers["Accept"] = accept;
        else
            request.headers["Accept"] = MediaType.Default.toString();
    }

    /**
        Ensures that HTTP response succeeded

        Params:
            response = vibe.d response object that needs to be checked

        Returns:
            new URL string in case of redirect, null otherwise
     **/
    private string handleResponseStatus ( scope HTTPClientResponse response )
    {
        import std.format;
        import vibe.http.status;

        auto status = response.statusCode;

        if (status == HTTPStatus.notFound)
            throw new HTTPAPIException("Requested non-existent API URL");

        if (status == HTTPStatus.found)
            return response.headers["Location"];

        enforce!HTTPAPIException(
            status >= 200 && status < 300,
            format("Expected status code 2xx, got %s\n\n%s\n",
                response.statusCode, response.readJson())
        );

        return null;
    }
}
