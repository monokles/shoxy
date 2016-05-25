import vibe.d;

shared static this()
{
    auto settings = new HTTPServerSettings;
    settings.port = 5050;

    auto DBsettings  = new HTTPServerSettings;
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
