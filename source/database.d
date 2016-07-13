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

    this(string shortCode, string url, string deleteKey)
    {
        this.shortCode  = shortCode;
        this.url        = url;
        this.deleteKey  = deleteKey;
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

        Entry getBy(string column)(string value) {
            //static assert (columns.length == values.length);


            string query = mixin(`"SELECT * FROM 'entries' WHERE `~column~` = %s"`).format(value); 

            auto command = new Command(conn, query);
            auto result = command.execSQLResult();

            Entry[] entries;
            foreach (r; result) {
                auto e = new Entry;
                e.id        = r["id"];
                e.shortCode = r["short_code"];
                e.url       = r["url"];
                e.deleteKey = r["delete_key"];
                entries[] = e;
            }

            return entries;
        }

        void insertEntry(Entry* entry)
        {
            string query = "INSERT INTO entries(short_code, url, delete_key) VALUES (%s, %s, %s)"
                .format(entry.shortCode, entry.url, entry.deleteKey);
            auto command = new Command(conn, query);
            command.execSQL();
        }

        void deleteEntry(Entry entry)
            in { 
                enforce(entry.id > 0);
            }

        body {
            string query = "DELETE FROM entries WHERE id = %d".format(entry.id);
            auto command = new Command(conn, query);
            command.execSQL();
        }

        //very basic testing
        unittest
        {
            auto settings = new DatabaseSettings("localhost", 3306, 
                    "shoxy_user", "shoxy_pass", "shoxy");

            auto DB = new Database(settings);

            //Make sure testcase data doesn't get stored to disk
            (new Command(DB.conn, "SET autocommit = 0")).execSQL();

            auto entry = new Entry("bla", "google.com" , "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
            DB.insertEntry(entry);
            auto result = DB.getBy!"short_code"("bla");
            assert(result.url == "google.com");
            DB.deleteEntry(result);

            (new Command(DB.conn, "ROLLBACK")).execSQL();
            (new Command(DB.conn, "SET autocommit = 1")).execSQL();
        }
}

