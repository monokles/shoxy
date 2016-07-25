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

        string getContentType(string url)
        {
            string ret = null;
            try
            {
                requestHTTP(url, null, 
                        (scope res) {
                            if(res.statusCode && (res.statusCode != 404)) {
                                ret = res.headers.get("content-type");
                            }
                        });
            } catch(Exception e) { }

            return ret;
        } 

        string prependHTTP(string url)
        {
            if(!url.startsWith("http://")
                    && !url.startsWith("https://")) {
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

        void proxyResource(string url, HTTPServerResponse res)
        {
            auto proxiedReq     = requestHTTP(url);
            res.httpVersion     = proxiedReq.httpVersion;
            res.headers         = proxiedReq.headers;
            res.statusCode      = proxiedReq.statusCode;
            res.statusPhrase    = proxiedReq.statusPhrase;

            //attempt to make browser display content (instead of showing a download promt)
            res.headers.remove("content-disposition");

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

        string createUniqueValue(string column)(ushort length) 
        {
            ushort inc = 0;
            ushort i = 0;
            string value;
            do
            {
                value = randomString(length + inc).toLower;
                ++i;
                inc += i % 10 == 0 ? 1 : 0;
            } while(DB.getBy!column(value).length > 0);

            return value;
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
            ushort scLength = settings.defaultShortcodeLength;

            //Validate url
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

            //Check if URL is real and if so whether to proxy it
            url = prependHTTP(url);
            string contentType = getContentType(url);
            bool proxyResource = false;
            if(!contentType) {
                writeBadRequest("Not a real URL", res);
                return;
            } else if (settings.proxyResources && 
                    !contentType.startsWith("text")) {
                proxyResource = true;
            }


            //If length param exists, assign it
            try {
                scLength = req.json["length"].get!ushort;
                if(scLength < settings.minShortcodeLength 
                        || scLength >  settings.maxShortcodeLength) {
                    scLength = settings.defaultShortcodeLength;
                }

            } catch (JSONException e) {
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

            auto shortCode  = createUniqueValue!"short_code"(scLength);
            auto deleteKey  = createUniqueValue!"delete_key"(30);
            auto ip         = req.peer;

            auto entry = Entry(shortCode, url, deleteKey, proxyResource, ip);
            DB.insertEntry(&entry);

            Json[string] json;
            json["url"] = urlString ~ "/" ~ shortCode;
            json["deleteKey"] = deleteKey;
            res.writeJsonBody(json);
        } 

        void deleteURLRequest(HTTPServerRequest req, HTTPServerResponse res)
        {
            auto deleteKey = req.json["deleteKey"].get!string;

            if(!isAllowedString(deleteKey)) {
                writeBadRequest("Bad delete key", res);
                return;
            }

            auto entry = DB.getBy!"delete_key"(deleteKey);
            if(entry.length > 0) {
                DB.deleteEntry(entry[0].id);
                res.render!("deleted.dt");
                return;
            } 

            writeBadRequest("Key not found", res);
        }

        void getURLRequest(HTTPServerRequest req, HTTPServerResponse res)
        {
            auto shortCode = req.params["shortCode"];

            if(!isAllowedString(shortCode)) {
                writeBadRequest("Bad shortcode", res);
                return;
            }

            auto entry = DB.getBy!"short_code"(shortCode);
            if(entry.length > 0) {
                if(entry[0].proxyType == 1) {
                    proxyResource(entry[0].url, res);
                } else {
                    res.redirect(entry[0].url);
                }
                return;
            } 

            res.statusCode = HTTPStatus.notFound;
        }
}
