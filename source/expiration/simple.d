import vibe.data.json;
import std.datetime;
import std.typecons;
import std.array;
import std.format;
import expirationpolicy;
import database;
import util;

class SimpleExpirationPolicy  : ExpirationPolicy
{
    protected:
        string[string] settings;
        bool useKey;

    public:
        this(string[string] settings)
        {
            this.settings = settings;
            this.useKey = ("bypassKey" in settings) !is null;
        }

        bool initExpirationDateTime(Json json, ref Entry entry)
        {
            if(useKey && (json["bypassKey"].to!string) == (settings["bypassKey"]))
            {
                return false;
            }

            Nullable!SysTime expTime = Clock.currTime;
            auto duration = durFromString(settings["expireAfter"]);
            expTime += duration;
            entry.expireDateTime = expTime;
            
            return true;
        }

        bool updateExpirationDateTime(ref Entry entry)
        {
            return false;
        }

}
