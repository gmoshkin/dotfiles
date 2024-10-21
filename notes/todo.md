# picodata

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
