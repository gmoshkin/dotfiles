# picodata
- follow-ups to pico_service MR: ON REVIEW
- pico_service password file: NEEDS TESTS
- review batch dml : TODO
- add memory info to proc_runtime_info: TODO
    - figure out what box.slab.info returns, find better names for the fields
    - figure out if there are any other useful memory info box.* things

- read startup parameters from init.cfg : TODO

- benchmark governor/raft log propagation : TODO
- simulate big cluster : TODO
- API to change replicaset master : TODO

# tarantool-module

## tcp connection improvements
    - asynchronous connect (without blocking the fiber)

## finishing the msgpack encode/decode library
    - serde compatible attributes
    - ...


- log set_/get_current_level: ON REVIEW
- fiber safety primitives: ON REVIEW
- iproto client error extension support : IN PROGRESS
- rename test-runner                          : IN PROGRESS
- network-client: handle packet size overflow : IN PROGRESS
- benchmark bulk inserts against lua          : TODO
- benchmark bulk selects against lua          : TODO
    - figure out getting cache miss info from rust

## life

- mom:
    - find a service to repair laptop charging port

- dad:
   - by battery for mom's laptop

- da:
    - gaming laptop
