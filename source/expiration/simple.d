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
    private:
        string[string] settings;

    public:
        this(string[string] settings)
        {
            this.settings = settings;
        }

        Nullable!SysTime initExpirationDateTime(Json json)
        {
            Nullable!SysTime expTime = Clock.currTime;
            auto duration = durFromString(settings["expireAfter"]);
            expTime += duration;
            return expTime;
        }

        bool updateExpirationDateTime(Entry entry)
        {
            return false;
        }

}
