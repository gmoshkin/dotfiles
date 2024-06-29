# picodata

* error returning from clusterwide operations : TODO
* review pico plugin MR: IN PROGRESS
* review shors in picodata MR : DONE

* config.yaml
    - read tarantool box.cfg parameters from config.yaml            : ON REVIEW
    - pico.config -> parameters sources: args, env, file, default   : ON REVIEW
    - nested sections                                               : ON REVIEW
      - EXAMPLE:
        - memtx:
            - memory: 420
            - checkpoint_count: 3500000000
    - explicitness in dynamicness please                            : NOT DOING
    - 2 config files: 1 common, 1 unique                            : DON'T WANNA DO
    - warning is error flag                                         : TODO
    - cli/env/config parameter names consistency                    : ON REVIEW
    - reload config cli command                                     : TODO

* plugin sdk
    - routing by
        - instance_id
        - bucket_id
        - replicaset_id
        - service_name

* proc api

    - add memory info to proc_runtime_info: TODO
        - figure out what box.slab.info returns, find better names for the fields
        - figure out if there are any other useful memory info box.* things

* other
    - 2phase commit situation. We do wait_for_ddl_commit when doing DDL, but
        it's just a entry in the raft log, which may get compacted. So we'll
        just timeout on the wait_for_ddl_commit. We really should have a test
        for simulating this case and see what the fuck happens.
    - benchmark governor/raft log propagation : TODO
    - simulate big cluster : TODO
        - speedbump is a good tool for artificial latency
    - API to change replicaset master : TODO

# tarantool-module #############################################################

    - review Tuple/TupleBuffer merger: TODO

    ## finishing the msgpack encode/decode library
        - serde compatible attributes
        - ...

- MR by Kostja

## fork

* ssl iproto review : TODO


- rename test-runner                          : IN PROGRESS
- network-client: handle packet size overflow : IN PROGRESS
- benchmark bulk inserts against lua          : TODO
- benchmark bulk selects against lua          : TODO
    - figure out getting cache miss info from rust

## life

- kaspi:
    - call beeline customer support to unblock my number

- mom:
    - find a service to repair laptop charging port

- dad:
   - by battery for mom's laptop
