import database;
import vibe.data.json;
import vibe.core.log;
import std.file;

struct ShoxyServerSettings
{
    string url;
    ushort port;

    string dbHost;
    ushort dbPort;
    string dbName;
    string dbUser;
    string dbPassword;

    bool allowVariableshortCodeLength;
    ushort minShortcodeLength;
    ushort maxShortcodeLength;
    ushort defaultShortcodeLength;;

}

class ShoxyServerConfig
{
    private:
        string readFile(string filePath)
        {
            try
            {
                return readText(filePath);
            }
            catch(FileException e)
            {
                logInfo("Can't read file %s.", filePath);
            }
            catch(Exception e)
            {
                logInfo("Exception while reading file %s.", filePath);
            }
                return null;
        }

    public:
        string filePath;
        ShoxyServerSettings settings;

        this(string filePath)
        {
            this.filePath = filePath;
            string jsonString = readFile(filePath);
            this.settings = deserializeJson!ShoxyServerSettings(jsonString);
        }
}
