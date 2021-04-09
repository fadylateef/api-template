import Vapor
import FluentMySQL
import Leaf

let wss = NIOWebSocketServer.default()

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register providers first
    try services.register(FluentMySQLProvider())
    try services.register(LeafProvider())
    services.register(APIAccessMiddleware.self)
    services.register(APIAccessMiddleware2.self)

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    // middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    // middlewares.use(APIAccessMiddleware.self)
    services.register(middlewares)

    // Configure a SQLite database
    var databases = DatabasesConfig()
    let databaseConfig = MySQLDatabaseConfig(hostname: "localhost", username: "root", password: "fady", database: "drmdnapi")
    let database = MySQLDatabase(config: databaseConfig)
    databases.add(database: database, as: .mysql)
    services.register(databases)

    // Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: Series.self, database: DatabaseIdentifier<Series.Database>.mysql)
    migrations.add(model: Episode.self, database: DatabaseIdentifier<Episode.Database>.mysql)
    migrations.add(model: ApiControl.self, database: DatabaseIdentifier<ApiControl.Database>.mysql)
    migrations.add(model: Category.self, database: DatabaseIdentifier<Category.Database>.mysql)
    services.register(migrations)
    




    // Register our server
    services.register(wss, as: WebSocketServer.self)
    // Web Renderer
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
}
