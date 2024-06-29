# Picodata plugin RPC SDK

Services can create RPC endpoints and invoke RPC requests to other instances.
Routing options:
    - by instance_id
        * supported by picodata connection pool out-of-the-box
    - by bucket_id
        * using vshard.router.internal.routers._static_router:route(bucket_id)
          we get the vshard's replicaset info which has info about the master
          (this info may alternatively be gotten from _pico_replicaset)
          and the closest available replica info
    - by replicaset_id
        * we could use _pico_replicaset to get a
           * master
           * random replica
        * or we could get vshard's replicaset info and get the closest replica info
    - by service_name
        * space _pico_service_route_table contains this info. Currently no way
          to get the closest instance info unfortunately


Nice-to-have: support calling static iproto procs if the route starts with '.'.
For this #[tarantool::proc] macro probably needs to be updated to support getting
a function pointer which doesn't require the FunctionCtx struct to be constructed.
