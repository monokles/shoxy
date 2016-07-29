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

        Nullable!SysTime initExpirationDateTime(Json json)
        {
            if(useKey && (json["bypassKey"].to!string) == (settings["bypassKey"]))
            {
                return Nullable!SysTime.init;
            }

            Nullable!SysTime expTime = Clock.currTime;
            auto duration = durFromString(settings["expireAfter"]);
            expTime += duration;
            return expTime;
        }

        bool updateExpirationDateTime(ref Entry entry)
        {
            return false;
        }

}
