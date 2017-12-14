Configure `/etc/prosody/prosody.cfg.lua`:

```
VirtualHost "<IP>"                                                     
    allow_unencrypted_plain_auth = true                                         

<...>

Component "rooms.<IP>" "muc"                                           
    name = "Chatrooms"                                                          
    restrict_room_creation = false                                              
    modules_enabled = { "freechains" }                                          
```
