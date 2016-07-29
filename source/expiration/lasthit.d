import vibe.data.json;
import std.datetime;
import std.typecons;
import std.array;
import std.format;
import expirationpolicy;
import database;
import util;
import simple;
import vibe.d;

class LastHitExpirationPolicy  : SimpleExpirationPolicy
{
    private:

    public:
        this(string[string] policySettings)
        {
            super(policySettings);
        }

        override bool updateExpirationDateTime(ref Entry entry)
        {
            logInfo("got called");
            auto duration = durFromString(settings["expireAfter"]);
            auto newExpire = Clock.currTime + duration;
            entry.expireDateTime = newExpire;
            return true;
        }

}
