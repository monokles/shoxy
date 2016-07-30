import std.typecons;
import std.datetime;
import vibe.data.json;
import database;
import std.uni;
import simple;
import lasthit;
import codelength;

interface ExpirationPolicy
{
    /**
     * Initializes the expiration time for a given entry and its
     * corresponding request.
     * The relevant request's json and entry are passed as
     * parameters, as to allow policies to implement custom 
     * post parameters.
     * 
     * Returns true if the entry was changed, otherwise false.
     * 
     */
    bool initExpirationDateTime(Json json, ref Entry entry);

    /**
     * Gets called whenever the entry gets requested by a client.
     * Gives the policy the opportunity to update the entry.
     *
     * Returns true whenever the entry is modified, false otherwise.
     */
    bool updateExpirationDateTime(ref Entry entry);

    static ExpirationPolicy GetPolicy(string policyName, string[string] policySettings)
    {
        switch(toLower(policyName))
        {
            case "lasthit":
                return new LastHitExpirationPolicy(policySettings);
            case "codelength":
                return new CodeLengthExpirationPolicy(policySettings);
            case "simple":
            default:
                return new SimpleExpirationPolicy(policySettings);
        }
    }
}
