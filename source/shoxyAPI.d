
interface ShoxyAPI
{
    struct addStruct
    {
        string targetURL;
    }

    void addURL(addStruct data);

    struct removeStruct
    {
        string targetURL, removeKey;
    }

    void removeURL(removeStruct data);
}

