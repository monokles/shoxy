import vibe.d;
import vibe.data.json;
import std.ascii;
import std.random;
import database;
import settings;

class ShoxyServer
{
    private:
        Database DB;
        ShoxyServerSettings settings;
        string urlString;

        const string  allowedStringChars   = letters ~ digits;
        const string  allowedURLChars      = "_-./:";
        const string  allowedChars         = allowedStringChars ~ allowedURLChars;

        bool isRealUrl(string url)
        {
            auto ret = true;
            try
            {
                requestHTTP(url, null, 
                        (scope res) {
                            if(!res.statusCode || (res.statusCode == 404)) {
                                ret = false;
                            }
                        });
            }
            catch(Exception e)
            {
                ret = false;
            }
            return ret;
        } unittest {
            ShoxyServer a = new ShoxyServer(null, "bla");
            assert(a.isRealUrl("kernel.org"));
            assert(a.isRealUrl("http://kernel.org"));
            assert(!a.isRealUrl("abc!"));
            assert(!a.isRealUrl("notValid"));
            assert(!a.isRealUrl("Thisisnotavaliddomain.com"));
        }

        string prependHTTP(string url)
        {
            if(!url.startsWith("http")) {
                return "http://" ~ url;
            }
            return url;
        }


        bool isAllowedString(string s)
        {
            foreach(c; s) {
                if(allowedChars.indexOf(c) < 0)
                    return false;
            }
            return true;
        } unittest {
            ShoxyServer a = new ShoxyServer(null, "bla");
            assert(a.isAllowedString("abc"));
            assert(!a.isAllowedString("ab\x10"));
            assert(!a.isAllowedString(""));
            auto badChars = "!@#$%^&*(){}><\\/,';`~|*";
            foreach(c; badChars) {
                assert(!a.isAllowedString(c.to!string));
            }
        }

        void proxyRequest(string url, HTTPServerResponse res)
        {
            auto proxiedReq     = requestHTTP(url);
            res.httpVersion     = proxiedReq.httpVersion;
            res.headers         = proxiedReq.headers;
            res.statusCode      = proxiedReq.statusCode;
            res.statusPhrase    = proxiedReq.statusPhrase;

            while(proxiedReq.bodyReader.dataAvailableForRead) {
                auto buf = new ubyte[proxiedReq.bodyReader.leastSize];
                proxiedReq.bodyReader.read(buf);
                res.writeBody(buf);
            }
        }

        string randomString(int length)
        in {
            assert(length > 0);
        } out (result) {
            assert(result.length == length);
        } body {

            string result = "";
            for(auto i = 0; i < length; ++i)
            {
                result ~= allowedStringChars[uniform(0, allowedStringChars.length)];
            }

            return result;
        }

        void writeBadRequest(string statusPhrase, HTTPServerResponse res)
        {
            res.statusCode      = HTTPStatus.badRequest;
            res.statusPhrase    = statusPhrase;
            res.writeBody("", res.statusCode);
            return;
        }


    public:
        this(ShoxyServerSettings settings)
        {
            this.settings = settings;
            auto portString = settings.port != 80? ":" ~ settings.port.to!string : "";
            this.urlString = settings.url ~ portString;

            auto dbSettings = new DatabaseSettings(settings.dbHost, settings.dbPort, settings.dbUser, settings.dbPassword, settings.dbName);
            this.DB = new Database(dbSettings);
        }

        void showIndex(HTTPServerRequest req, HTTPServerResponse res)
        {
            res.render!("index.dt");
        } 

        void postURLRequest(HTTPServerRequest req, HTTPServerResponse res)
        {
            string url = null;
            try {
                url = req.json["url"].get!string;
            } catch (JSONException e) {
                writeBadRequest("No 'url' parameter found", res);
                return;
            }

            if(!isAllowedString(url)) {
                writeBadRequest("URL string is not allowed", res);
                return;
            }

            //Check if URL is real
            url = prependHTTP(url);
            if(!isRealUrl(url)) {
                writeBadRequest("Not a real URL", res);
                return;
            }

            //If already exists in DB, return shortCode of first match
            auto existingEntries = DB.getBy!"url"(url);
            if(existingEntries.length > 0) 
            {
                res.statusCode = HTTPStatus.found;
                Json[string] json;
                json["url"] = urlString ~ "/" ~ existingEntries[0].shortCode;
                res.writeJsonBody(json);
                return;
            }

            auto shortCode = randomString(5).toLower;
            auto deleteKey = randomString(30).toLower;
            auto entry = Entry(shortCode, url, deleteKey);
            DB.insertEntry(&entry);

            Json[string] json;
            json["url"] = urlString ~ "/" ~ shortCode;
            json["deleteKey"] = deleteKey;
            res.writeJsonBody(json);
        } 

        void deleteURLRequest(HTTPServerRequest req, HTTPServerResponse res)
        {
            auto deleteKey = req.json["key"].get!string;

            if(!isAllowedString(deleteKey)) {
                res.statusCode = HTTPStatus.badRequest;
                res.statusPhrase = "Bad key param";
                return;
            }

            auto entry = DB.getBy!"delete_key"(deleteKey);
            if(entry.length > 0) {
                DB.deleteEntry(entry[0].id);
                return;
            } 

            res.statusCode = HTTPStatus.badRequest;
            res.statusPhrase = "Key not found";
        }

        void getURLRequest(HTTPServerRequest req, HTTPServerResponse res)
        {
            auto shortCode = req.params["shortCode"];

            auto entry = DB.getBy!"short_code"(shortCode);
            if(entry.length > 0) {
                proxyRequest(entry[0].url, res);
                return;
            } 

            res.statusCode = HTTPStatus.notFound;
        }
}
