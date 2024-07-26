# lua-resty-cache_stats

A Lua module for tracking and reporting cache statistics in Nginx, with support for periodic statistics recording using timers.

## Installation

To install this module, you can use the OpenResty Package Manager (opm):

```sh
opm get iakuf/lua-resty-cache-stats
```

## Dependencies

This module requires the `lua-cjson` library to work. Ensure that `lua-cjson` is installed and accessible in your OpenResty environment.

## Usage

### Nginx Configuration

Add the following configuration to your `nginx.conf` file:

1. **Define shared dictionary**:

```nginx
http {
    lua_shared_dict cache_stats 10m;
}
```

1. **Initialize the module in the worker**:

```nginx
http {
    init_worker_by_lua_block {
        local cache_stats = require "resty.cache_stats"
        cache_stats.init()
    }
}
```

1. **Track cache statistics**:

   Add the following block in the `log_by_lua_block` to log request statuses:

```nginx
http {
    server {
        listen 80;
        server_name example.com;

        location / {
            log_by_lua_block {
                local cache_stats = require "resty.cache_stats"
                cache_stats.track()
            }
            # Other configurations...
        }
    }
}
```

1. **Display cache statistics**:

   Add the following location block to display cache statistics, similar to `squidclient`:

```nginx
http {
    server {
        listen 80;
        server_name example.com;

        location /cache_status {
            content_by_lua_block {
                local cache_stats = require "resty.cache_stats"
                cache_stats.get_stats()
            }
        }
    }
}
```
it will show 
```ini
Cache Stats Overview:

Request Hit Rates:
1 Minute Request Hit Rate: 86.24
5 Minutes Request Hit Rate: 93.99
60 Minutes Request Hit Rate: 99.20

Traffic Hit Rates:
1 Minute Traffic Hit Rate: 66.96
5 Minutes Traffic Hit Rate: 77.38
60 Minutes Traffic Hit Rate: 94.31


Detailed Stats(1min):
1min_hits: 1385
1min_misses: 221
1min_requests: 1606
1min_hit_bytes: 118331709
1min_missed_bytes: 58399549
1min_bytes: 176731258


Detailed Stats(5min):
5min_hits: 6408
5min_misses: 410
5min_requests: 6818
5min_hit_bytes: 744406471
5min_missed_bytes: 217558265
5min_bytes: 961964736


Detailed Stats(60min):
60min_hits: 589097
60min_misses: 4758
60min_requests: 593855
60min_hit_bytes: 35882471518
60min_missed_bytes: 2166475562
60min_bytes: 38048947080
```

### Example

Here is an example `nginx.conf` file with the necessary configuration:

```nginx
http {
    lua_shared_dict cache_stats 10m;

    init_worker_by_lua_block {
        local cache_stats = require "resty.cache_stats"
        cache_stats.init()
    }

    server {
        listen 80;
        server_name example.com;

        location / {
            log_by_lua_block {
                local cache_stats = require "resty.cache_stats"
                cache_stats.track()
            }
            # Other configurations...
        }

        location /cache_status {
            content_by_lua_block {
                local cache_stats = require "resty.cache_stats"
                cache_stats.get_stats()
            }
        }
    }
}
```

## License

MIT
