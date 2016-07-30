import vibe.data.json;
import core.time;
import std.datetime;
import std.typecons;
import std.array;
import std.format;
import expirationpolicy;
import database;
import util;

class CodeLengthExpirationPolicy  : ExpirationPolicy
{
    private:
        Nullable!SysTime calculateExpirationTime(ulong codeLength)
        {
            Nullable!SysTime expTime = Clock.currTime;
            auto expirationHours = (codeLength * 14) - 12;
            
            expTime += dur!"hours"(expirationHours);
            
            return expTime;
        }
        
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
            if (useKey && json["bypassKey"].to!string == (settings["bypassKey"]))
            {
                return false;
            }
            auto codeLength = entry.shortCode.length;
            entry.expireDateTime = calculateExpirationTime(codeLength);
            return true;
        }

        bool updateExpirationDateTime(ref Entry entry)
        {
            return false;
        }
}
