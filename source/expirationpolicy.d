import std.typecons;
import std.datetime;
import vibe.data.json;
import database;
import std.uni;
import simple;

interface ExpirationPolicy
{
    /**
     * Returns the initial expiration datetime for new entries.
     * 
     * the relevant request's json is passed as a parameter, as to 
     * allow policies to implement custom post parameters.
     * Returns Null if this is infinite;
     * 
     */
    Nullable!SysTime initExpirationDateTime(Json json);

    /**
     * Gets called whenever the entry gets requested by a client.
     * Gives the policy the opportunity to update the entry.
     *
     * Returns true whenever the entry is modified, false otherwise.
     */
    bool updateExpirationDateTime(Entry entry);

    static ExpirationPolicy GetPolicy(string policyName, string[string] policySettings)
    {
        switch(toLower(policyName))
        {
            case "simple":
            default:
                return new SimpleExpirationPolicy(policySettings);
        }
    }
}
