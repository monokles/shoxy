import vibe.data.json;
import std.datetime;
import std.typecons;
import std.array;
import std.format;
import expirationpolicy;
import database;

class SimpleExpirationPolicy  : ExpirationPolicy
{
    private:
        string[string] settings;

        
        Duration genDuration(string unit)(string formatted)
        {
            int v;
            formattedRead(formatted, "%d", &v);
            return dur!unit(v);
        }

        Duration[] getExpireAfterDurations(string expireAfter)
        {
            Duration[] ret;
            foreach(s; settings["expireAfter"].split) {
                switch(s[$-1])
                {
                    case 'd':
                        ret ~= genDuration!"days"(s);
                        break;
                    case 'h':
                        ret ~= genDuration!"hours"(s);
                        break;
                    case 'm':
                        ret ~= genDuration!"minutes"(s);
                        break;
                    case 's':
                        ret ~= genDuration!"seconds"(s);
                        break;
                    default:
                        //ignore
                }
            }
            return ret;
        }

    public:
        this(string[string] settings)
        {
            this.settings = settings;
        }

        Nullable!SysTime initExpirationDateTime(Json json)
        {
            Nullable!SysTime expTime = Clock.currTime;
            auto durs = getExpireAfterDurations(settings["expireAfter"]);
            foreach(d; durs)
            {
                expTime += d;
            }

            return expTime;
        }

        bool updateExpirationDateTime(Entry entry)
        {
            return false;
        }

}
