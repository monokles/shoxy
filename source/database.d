import mysql.connection;
import std.stdio;
import vibe.d;
import std.format;


struct Entry
{
    immutable long id; 
    string shortCode; 
    string url; 
    string deleteKey; 
    int proxyType; 
    string ownerIp; 

    this(string shortCode, string url, string deleteKey, int proxyType, string ownerIp)
    {
        this.shortCode  = shortCode;
        this.url        = url;
        this.deleteKey  = deleteKey;
        this.proxyType  = proxyType;
        this.ownerIp    = ownerIp;
    }

    this(long id, string shortCode, string url, string deleteKey, int proxyType, string ownerIp)
    {
        this.id  = id;
        this.shortCode  = shortCode;
        this.url        = url;
        this.deleteKey  = deleteKey;
        this.proxyType  = proxyType;
        this.ownerIp    = ownerIp;
    }
}

class DatabaseSettings
{
    public:
        immutable string host; 
        immutable ushort port; 
        immutable string user; 
        immutable string password; 
        immutable string database; 

        this(string host, ushort port, string user, string password, string database) 
        {
            this.host = host;
            this.port = port;
            this.user = user;
            this.password = password;
            this.database = database;
        }
}

private string Schema = 
"""
CREATE TABLE IF NOT EXISTS entries (
    id              BIGINT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
    short_code      VARCHAR(10)   NOT NULL,
    url             VARCHAR(200)  NOT NULL,
    delete_key      CHAR(30)      NOT NULL,
    proxy_type      INT           NOT NULL,
    owner_ip        VARCHAR(30)   ,
    create_datetime DATETIME      DEFAULT CURRENT_TIMESTAMP,
    UNIQUE INDEX (short_code),
    UNIQUE INDEX (delete_key)
)
""";

class Database
{
    private:
        DatabaseSettings settings;
        Connection conn;

        void connect()
        {
            string connStr = "host=%s;port=%d;user=%s;pwd=%s;db=%s"
                .format(settings.host, settings.port, 
                        settings.user, settings.password, settings.database);
            conn = new Connection(connStr);
        }

        bool DBExists() {
            string query = "SHOW TABLES";
            auto command = new Command(conn, query);
            auto result = command.execSQLResult();
            bool exists = !(result.length == 0);
            if(exists) {
                logInfo("Database schema found.");
            } else {
                logInfo("Database schema not found.");
            }
            return exists;
        }

        void createDB()
        {
            auto command = new Command(conn, Schema);
            command.execSQL();
            logInfo("Database tables created!");
        }

    public:
        this(DatabaseSettings settings)
        {
            this.settings = settings;
            connect();
            if(!DBExists()) {
                createDB();
            }
        }

        Entry[] getBy(string column)(string value) {


            string query = mixin(`"SELECT * FROM entries WHERE `~column~` = '%s'"`).format(value); 

            auto command = new Command(conn, query);
            auto result = command.execSQLResult();

            Entry[] entries;
            foreach (r; result) {
                auto id             = *r[0].peek!long;
                auto shortCode      = (*r[1].peek!string).idup;
                auto url            = (*r[2].peek!string).idup;
                auto deleteKey      = (*r[3].peek!string).idup;
                auto proxyType      = *r[4].peek!int;
                auto ownerIp        = (*r[5].peek!string).idup;
                entries ~= Entry(id, shortCode, url, deleteKey, proxyType, ownerIp);
            }

            return entries;
        }

        void insertEntry(Entry* entry)
        {
            string query = "INSERT INTO entries(short_code, url, delete_key, proxy_type, owner_ip) VALUES ('%s', '%s', '%s', %s, '%s')"
                .format(entry.shortCode, entry.url, entry.deleteKey, 
                        entry.proxyType.to!string, entry.ownerIp);
            auto command = new Command(conn, query);
            command.execSQL();
        }

        void deleteEntry(long id)
            in { 
                enforce(id > 0);
            }
        body {
            string query = "DELETE FROM entries WHERE id = %d".format(id);
            auto command = new Command(conn, query);
            command.execSQL();
        }
}

