# Plugins

# RPC SDK

TODO:
 - integration test:
    - start instances with different replicasets
    - call rpc:
        - by instance_id rw/ro
        - by replicaset_id rw/ro
        - by bucket_id rw/ro
        - by plugin.service
- always send plugin version
- always have service name in request

# Runtime configuration change

- So like I wanna change box.cfg.log_format right?
- Config parameters should be stored in global storage:
    - per-instance
    - per-tier
    - per-cluster
- When booting up on the discovery stage the instance loads the storage and if
  it sees non-default static parameters it rebootstraps with them (this
  means that instance sends to the supervisor not just the next entrypoint but
  also the settings it needs to be ready on the next start). For dynamic
  parametes we can just call box.cfg() right after the first one after we know
  their values, no rebootstrap is needed.
- When changing these parameters at runtime the governor goes to all concerned
  instances (depending on the range of applicability), sends them an rpc to
  update the runtime configuration. As a sign of complete change there's a
  target config version and a current config version for all instances.
