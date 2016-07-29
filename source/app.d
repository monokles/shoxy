import vibe.d;
import database;
import shoxyserver;
import settings;

shared static this()
{
    auto settings = new HTTPServerSettings;

    auto config = new ShoxyServerConfig("shoxy.json");
    logInfo("Loaded config file...");

    //copy relevant settings for vibe.d server
    settings.port = config.settings.port;

    auto shoxyServer = new ShoxyServer(config.settings);
    logInfo("Created Server instance...");

    auto router         = new URLRouter;
    router.get("/", &shoxyServer.showIndex);
    router.get("/:shortCode", &shoxyServer.getURLRequest);
    router.delete_("/", &shoxyServer.deleteURLRequest);
    router.post("/", &shoxyServer.postURLRequest);

    listenHTTP(settings, router);
    logInfo("Now listening on http://%s:%d", config.settings.url, config.settings.port);
}
