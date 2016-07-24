import vibe.d;
import database;
import shoxyserver;

shared static this()
{
    auto settings = new HTTPServerSettings;
    settings.port = 5050;

    auto DBSettings  = new DatabaseSettings( "127.0.0.1", 3306, 
            "shoxy_user", "shoxy_pass", "shoxy");
    auto DB = new Database(DBSettings);


    auto shoxyServer = new ShoxyServer(new Database(DBSettings), "xn--zce.tv");
    logInfo("Created Server instance...");

    auto router         = new URLRouter;
    router.get("/", &shoxyServer.showIndex);
    router.get("/:shortCode", &shoxyServer.getURLRequest);
    router.delete_("/:deleteKey", &shoxyServer.deleteURLRequest);
    router.post("/", &shoxyServer.postURLRequest);

    listenHTTP(settings, router);
    logInfo("Now listening on http://%s:%d", "localhost", settings.port);
}
