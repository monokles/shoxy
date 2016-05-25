import vibe.d;
import vibe.data.json;
import std.ascii;
import std.random;
import database;

class ShoxyServer
{
    private:
        Database DB;
        string serverURL;
        string allowedChars = letters ~ digits ~ "_-";

        bool isRealUrl(string URL)
        {
            if(!isAllowedString(URL)) {
                return false;
            }

            auto streamedReq = requestHTTP(target);
            if(!streamedReq.statusCode || (streamedReq.statusCode == 404)) {
                return false;
            }
            return true;
        } unittest {
            assert(isRealURL("kernel.org"));
            assert(isRealURL("http://kernel.org"));
            assert(!isRealURL("abc!"));
            assert(!isRealURL("notValid"));
            assert(!isRealURL("Thisisnotavaliddomain.com"));
        }

        bool isAllowedString(string s)
        {
            foreach(c; s) {
                if(!allowedChars.contains(c))
                    return false;
            }
            return true;
        } unittest {
            assert(isAllowedString("abc"))
            assert(!isAllowedString("ab\x10"))
            assert(!isAllowedString(""))
            auto badChars = "!@#$%^&*(){}/><\\/.,';`~|*";
            foreach(c; badChars) {
                assert(!isAllowedString(c));
            }
        }

        void proxyRequest(string url, HTTPServerResponse res)
        {
            auto proxiedReq     = requestHTTP(target);
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
            assert(result.length = length);
        } body {

            string result = "";
            for(auto i = 0; i <= length; ++i)
            {
                result ~= allowedChars[uniform(0, allowedChars.length)];
            }

            return result;
        }


    public:
        this(Database  DB, string serverURL)
        {
            this.DB = DB;
            this.serverURL = serverURL;
        }

        void showIndex(HTTPServerRequest req, HTTPServerResponse res)
        {
            res.render!("index.dt");
        } 

        void postURLRequest(HTTPServerRequest req, HTTPServerResponse res)
        {
            auto url = req.json["url"];

            if(!url || !isRealUrl(url)) {
                res.statusCode     = HTTPStatus.badRequest;
                res.statusPhrase = url? "URL does not exist" : "Bad URL param";
                return;
            }

            if(DB.getBy!"url"(url)) 
            {
                res.statusCode = HTTPStatus.found;
                Json[string] json;
                json["url"] = DB.getBy!"url"(url).shortCode;
                res.writeJsonBody(json);
                return;
            }

            auto shortCode = randomString(5);
            auto deleteKey = randomString(30);
            auto entry = DatabaseEntry(shortCode, deleteKey, url);
            DB.insertEntry(entry);

            Json[string] json;
            json["url"] = serverURL ~ "/" ~ shortCode;
            json["deleteKey"] = deleteKey;
            res.writeJsonBody(json);
        } 

        void deleteURLRequest(HTTPServerRequest req, HTTPServerResponse res)
        {
            auto deleteKey = req.json["key"];

            if(!isAllowedString(deleteKey)) {
                res.statusCode = HTTPStatus.badRequest;
                res.statusPhrase = "Bad key param";
                return;
            }

            auto entry = DB.getBy!"deleteKey"(deleteKey);
            if(entry) {
                DB.dropEntry(entry);
                return;
            } 

            res.statusCode = HTTPStatus.badRequest;
            res.statusPhrase = "Key not found";
        }

        void getURLRequest(HTTPServerRequest req, HTTPServerResponse res)
        {
            auto shortCode = req.params["shortCode"];

            auto entry = DB.getBy!"shortCode"(shortCode);
            if(entry) {
                proxyRequest(entry.url, res);
                return;
            } 

            res.statusCode = HTTPStatus.notFound;
        }
}
