import vibe.d;
import vibe.data.json;
import std.ascii;
import std.random;
import database;
import settings;
import std.datetime;
import std.typecons;
import expirationpolicy;
import simple;
import util;

class ShoxyServer
{
    private:
        Database DB;
        ShoxyServerSettings settings;
        ExpirationPolicy policy;
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
            //BROKEN 
            ShoxyServer a = new ShoxyServer(null, "bla");
            assert(a.isAllowedString("abc"));
            assert(!a.isAllowedString("ab\x10"));
            assert(!a.isAllowedString(""));
            auto badChars = "!@#$%^&*(){}><\\/,';`~|*";
            foreach(c; badChars) {
                assert(!a.isAllowedString(c.to!string));
            }
        }

        bool proxyResource(string url, HTTPServerResponse res)
        {
            auto proxiedReq     = requestHTTP(url);

            //return false if resource is unacceptable
            if(proxiedReq.statusCode == HTTPStatus.notFound
                    || proxiedReq.headers.get("content-type").startsWith("text")) {
                return false;
            }

            res.httpVersion     = proxiedReq.httpVersion;
            res.statusCode      = proxiedReq.statusCode;
            res.statusPhrase    = proxiedReq.statusPhrase;


            while(proxiedReq.bodyReader.dataAvailableForRead) {
                auto buf = new ubyte[proxiedReq.bodyReader.leastSize];
                proxiedReq.bodyReader.read(buf);
                res.writeBody(buf);
            }

            return true;
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
                if(length + inc > settings.maxShortcodeLength) {
                    --inc;
                }
            } while(DB.getBy!column(value).length > 0);

            return value;
        }


    public:
        this(ShoxyServerSettings settings)
        {
            this.settings = settings;
            auto portString = canFind([80, 443], settings.port)? 
                "" : ":" ~ settings.port.to!string;
            this.urlString = settings.url ~ portString;

            auto dbSettings = new DatabaseSettings(settings.dbHost, settings.dbPort, settings.dbUser, settings.dbPassword, settings.dbName);
            this.DB = new Database(dbSettings);

            this.policy = ExpirationPolicy.GetPolicy(
                    settings.expirationPolicy, 
                    settings.expirationPolicySettings);

            auto expInterval = durFromString(settings.expireCheckInterval);
            setTimer(expInterval, toDelegate(&DB.deleteExpiredEntries), true);
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

            } catch (JSONException e) { }

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
            Nullable!SysTime expireDateTime = policy.initExpirationDateTime(req.json);

            auto entry = Entry(shortCode, url, deleteKey, proxyResource, ip, expireDateTime);
            DB.insertEntry(&entry);

            logInfo("%s submitted %s as %s/%s", entry.ownerIp, 
                    entry.url, urlString, entry.shortCode);

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
                    auto stillExists = proxyResource(entry[0].url, res);
                    if(!stillExists) {
                        logInfo("Deleting '%s'->'%s' due to 404 or bad content-type", entry[0].shortCode, entry[0].url);
                        DB.deleteEntry(entry[0].id);
                        res.statusCode = HTTPStatus.notFound;
                    }
                } else {
                    res.redirect(entry[0].url);
                }
                return;
            } 

            res.statusCode = HTTPStatus.notFound;
        }
}
