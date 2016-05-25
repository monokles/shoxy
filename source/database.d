import mysql.connection;
import std.stdio;
import std.format;


struct DatabaseEntry
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

struct DatabaseSettings
{
    string host; 
    ushort port; 
    string user; 
    string password; 
    string database; 
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
            writeln("Database exists!");
            return !(result.length == 0);
        }

        void createDB()
        {
            auto command = new Command(conn, Schema);
            command.execSQL();
        }

    public:
        this(DatabaseSettings settings)
        {
            this.settings = settings;
            connect();
        }

        DatabaseEntry[] where(string table, string column, string operand = "=")(string value)
        {
            string query = mixin(`"SELECT * FROM `~table~` WHERE `~column~` `~ operand ~ ` '%s'"`)
                .format(value); 
                

            auto command = new Command(conn, query);
            auto result = command.execSQLResult();

            foreach (r; result) {
                writeln(r);
            }

            return null;
        }

        void insertEntry(DatabaseEntry entry)
        {
            string query = "INSERT INTO entries(short_code, url, delete_key) VALUES (%s, %s, %s)"
                .format(entry.shortCode, entry.url, entry.deleteKey);
            auto command = new Command(conn, query);
            command.execSQL();
        }

        void deleteEntry(DatabaseEntry entry)
            in { 
                assert(entry.id > 0);
            }
        body {
            string query = "DELETE FROM entries WHERE id = %d".format(entry.id);;
            auto command = new Command(conn, query);
            command.execSQL();
        }
}
