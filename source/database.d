import mysql.connection;
import std.stdio;
import vibe.d;
import std.format;
import std.datetime;
import std.typecons;


struct Entry
{
    immutable long id; 
    string shortCode; 
    string url; 
    string deleteKey; 
    int proxyType; 
    string ownerIp; 
    Nullable!SysTime createDateTime; 
    Nullable!SysTime expireDateTime; 

    this(string shortCode, string url, string deleteKey, int proxyType, string ownerIp, 
            Nullable!SysTime expireDateTime)
    {
        this.shortCode          = shortCode;
        this.url                = url;
        this.deleteKey          = deleteKey;
        this.proxyType          = proxyType;
        this.ownerIp            = ownerIp;
        this.expireDateTime     = expireDateTime;
    }

    this(long id, string shortCode, string url, string deleteKey, int proxyType, 
            string ownerIp, Nullable!SysTime createDateTime, Nullable!SysTime expireDateTime)
    {
        this.id                 = id;
        this.shortCode          = shortCode;
        this.url                = url;
        this.deleteKey          = deleteKey;
        this.proxyType          = proxyType;
        this.ownerIp            = ownerIp;
        this.createDateTime     = createDateTime;
        this.expireDateTime     = expireDateTime;
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
    expire_datetime DATETIME      ,
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
            string connStr = "host = %s;port = %d;user = %s;pwd = %s;db = %s"
                .format(settings.host, settings.port, 
                        settings.user, settings.password, settings.database);
            conn = new Connection(connStr);
        }

        bool DBExists() {
            string query = "SHOW TABLES";
            auto command = new Command(conn, query);
            auto result = command.execSQLResult();
            bool exists = !(result.length  ==  0);
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

        string toSQLTimestamp(in SysTime t) @safe 
        {
            return "%04d-%02d-%02d %02d:%02d:%02d".format(
                    t.year, t.month, t.day, t.hour, t.minute, t.second);
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
                auto id             = r[0].coerce!long;
                auto shortCode      = r[1].coerce!string;
                auto url            = r[2].coerce!string;
                auto deleteKey      = r[3].coerce!string;
                auto proxyType      = r[4].coerce!int;
                auto ownerIp        = r[5].coerce!string;

                Nullable!SysTime createDateTime = SysTime.fromSimpleString(r[6].coerce!string);
                string expireString = r.isNull(7)? null: r[7].coerce!string;
                Nullable!SysTime expireDateTime;
                if(expireString !is null) {
                    expireDateTime = SysTime.fromSimpleString(expireString);
                }

                entries ~=  Entry(id, shortCode, url, deleteKey, proxyType, 
                        ownerIp, createDateTime, expireDateTime);
            }

            return entries;
        }

        void insertEntry(Entry entry)
        {
            auto expireDateTime = entry.expireDateTime.isNull? 
                "NULL" : "'%s'".format(toSQLTimestamp(entry.expireDateTime));
            string query = "INSERT INTO entries(short_code, url, delete_key, proxy_type, owner_ip, expire_datetime) VALUES ('%s', '%s', '%s', %s, '%s', %s)"
                .format(entry.shortCode, entry.url, entry.deleteKey, 
                        entry.proxyType.to!string, entry.ownerIp, expireDateTime);
            auto command = new Command(conn, query);
            command.execSQL();
        }

        void updateEntry(Entry entry) 
        {
            auto cDateTime = entry.createDateTime.isNull? 
                "NULL" : "'%s'".format(toSQLTimestamp(entry.createDateTime));
            auto eDateTime = entry.expireDateTime.isNull? 
                "NULL" : "'%s'".format(toSQLTimestamp(entry.expireDateTime));

            string query = "UPDATE entries SET short_code = '%s', url = '%s', delete_key = '%s', proxy_type = %d, owner_ip = '%s', create_datetime = %s, expire_datetime = %s WHERE id = %d".format(entry.shortCode, entry.url, entry.deleteKey, 
                    entry.proxyType, entry.ownerIp, 
                    cDateTime, eDateTime, entry.id);
            logInfo(query);

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

        void deleteExpiredEntries()
        {
            //count amount of expired entries so we can log about it
            string cntQ = "select count(*) from entries WHERE expire_datetime <=  CURRENT_TIMESTAMP";
            auto command = new Command(conn, cntQ);
            auto amount = command.execSQLResult()[0][0].coerce!int;
            string query = "DELETE FROM entries WHERE expire_datetime <=  CURRENT_TIMESTAMP";
            command = new Command(conn, query);
            command.execSQL();
            logInfo("Deleted %d expired entries from the database.", amount);
        }
}

