

## ネットワーク図

### テスト環境

```mermaid
architecture-beta
    service internet(internet)[Internet]

    group my_network[Home Network]
        service my_home_router(server)[Router] in my_network
        service my_home_l2_sw(server)[L2SW] in my_network

        group main_server(server)[Server] in my_network

            group bot_container[Container] in main_server
                service bot_server(server)[Bot] in bot_container

            group public_api_container[Container] in main_server
                service public_api_server(server)[GameAPIServer] in public_api_container

            group private_network[Private Network] in main_server
                group private_api_container[Container] in private_network
                    service private_api_server(server)[DBAPIServer] in private_api_container

                group game_container[Container] in private_network
                    service game_server(server)[GameServer] in game_container

                group db_container[Container] in private_network
                    service db(database)[Database] in db_container
                    service disk2(disk)[Storage] in db_container

    group aws_network(cloud)[AWS]

    group user_network[User Network]
        service user(server)[User] in user_network

    internet:B -- T:my_home_router
    internet:B -- T:user

    my_home_router:B -- T:my_home_l2_sw
    my_home_l2_sw:B -- T:public_api_server
    my_home_l2_sw:B -- T:bot_server

    game_server:R --> L: bot_server

    public_api_server:B --> T: game_server
    game_server:B --> T: private_api_server
    private_api_server:B --> T: db

    db:B -- T:disk2
```


### 本番環境
