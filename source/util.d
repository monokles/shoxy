import core.time;
import std.array;
import std.format;
import std.string;

/**
 * Returns true if target consists only of chars in allowedChars
 */
bool madeOf(string target, string allowedChars)
{
    foreach(c; target) {
        if(allowedChars.indexOf(c) < 0)
            return false;
    }
    return true;
}

Duration durFromString(string duration)
{

    Duration genDuration(string unit)(string formatted)
    {
        int v;
        formattedRead(formatted, "%d", &v);
        return dur!unit(v);
    }

    Duration ret;
    foreach(s; duration.split) {
        switch(s[$-1])
        {
            case 'd':
                ret += genDuration!"days"(s);
                break;
            case 'h':
                ret += genDuration!"hours"(s);
                break;
            case 'm':
                ret += genDuration!"minutes"(s);
                break;
            case 's':
                ret += genDuration!"seconds"(s);
                break;
            default:
                //ignore
        }
    }
    return ret;
}
