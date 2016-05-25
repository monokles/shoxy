struct DatabaseEntry
{
    long id; 
    string shortCode; 
    string url; 
    string deleteKey; 

    this(string shortCode, string url, string deleteKey)
    {
        this.shortCode  = shortCode;
        this.url        = url;
        this.deleteKey  = deleteKey;
    }
}

struct DatabaseSettings
{
    string URL; 
    ushort port; 
    string user; 
    string password; 
}

private string Schema = 
//TODO create schema based on structs
"""
ADD TABLE 'Shoxy' COLUMNS
yaddayadaa
""";

class Database
{
    private:
        DatabaseSettings settings;

        void connect()
        {
        }

        void createDB()
        {
        }

    public:
        this(Databasesettings settings)
        {
            this.settings = settings
        }

        DatabaseEntry getBy(string column)(string value)
        {
            auto query = "SELECT * WHERE "~column~" = "~value~";";
        }

        void insertEntry()
        {
        }

        void deleteEntry(DatabaseEntry entry)
        {
            auto query = "DELETE FROM Shoxy WHERE "~column~" = "~value~";";
        }
}
