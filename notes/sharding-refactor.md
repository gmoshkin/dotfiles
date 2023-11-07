to offline:
    transfer leadership
    transfer mastership
    vshard cfg

create replicaset:

promote replicaset master:

configure replicaset:

configure vshard:

initial bucket distribution:

update sharding weights:

to online:

configure vshard:

to online:

ddl:


---

TODO:
    - reincarnated instance must reconfigure vshard
    - master switchover
    - tiers

instance I target = Offline:
    1. transfer leadership
    2. transfer mastership
    3. for each J with current grade >= Replicated:
        rpc to J: vshard.cfg { remove I }

instance I with no replicaset R:
    1. promote I to master of R
    2. _pico_replicaset:insert(R)

replicaset R master I is offline:
    1. promote J to master of R
    2. _pico_replicaset:update(R, master = J)

instance I in R has current grade < Replicated:
    1. for each J in R:
        rpc to J: box.cfg { replication = R }
    2. _pico_instance:update(I, current grade = Replicated)

current vshard config != target vshard config:
    1. for each I with current grade >= Replicated:
        rpc to I: vshard.cfg { target config }
    2. _pico_property:replace(current vshard config = target)

NOTE:
    if vshard_bootstrapped then
        generate vshard config includes all replicasets
    else
        generate vshard config only includes first full replicaset
generated vshard config != target vshard config:
    1. _pico_property:replace(target vshard config = generated)

!vshard_bootstrapped && replicaset R has weight != 0:
    1. rpc to R.master: vshard.router.bootstrap
    2. _pico_property:replace(vshard_bootstrapped, true)

replicaset R has initial weight = 0 && if full:
    1. _pico_replicaset:update(R, weight = 1,
            state = if vshard_bootstrapped then Updating else UpToDate)

instance I with current grade = Replicated:
    1. _pico_instance:update(I, current grade = Online)

