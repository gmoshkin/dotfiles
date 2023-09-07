# big snapshots

Problem:

1. Tarantool IPROTO has a hard cap of the size of packet it can process: 2Gb.
   But also there are a bunch of other soft caps which make it so we should
   probably not sending too many megabytes at a time.

2. If we're sending the snapshot in pieces, then we should take care not to send
   dirty data, which can happen if for example global spaces get updated after
   the first piece of the snapshot has been sent.

   Example:

   1. Leader starts sending snapshot to follower.
   2. Leader sends first piece, which contains tuple T from space S.
   3. Leader receives DML request to remove tuple T from space S.
   4. ...

   So basically we need to freeze the contents of the global spaces once we
   start sending the snapshot to the follower.

Solution ideas:

0. Fucking who gives a shit, just send broken data.

   We're not doing that.


1. Stop processing DML requests until pending snapshot has been sent or has been
   cancelled.

   This is a bad idea as it will lead to leader blocking and getting reelected.


2. Open a read_view on the global spaces once the snapshot is needed.

   This is probably the best solution, but we need to patch the fork to export
   read_view apis.


3. Just fucking store the dump of the global spaces until the snapshot is
   processed.

   This is a dirty-hacky version of the read_view. It's less efficient, and it
   will result in leader hanging while creating the space dumps, which is bad.
   But if we're in a hurry this should be a good first approximation.


## Algorithm

1. Leader starts generating the snapshot
   - Opens a read view on global spaces
   - If snapshot data size doesn't exceed the threshold then only all of the
      data is sent in one piece and the read view is closed
   - Otherwise stores the reference to the read view in a table associated with
      the current applied index

2. Follower (replicaset leader) receives the raft snapshot
   2.1 If snapshot data chunk is final (there's a flag in it) applies it and done
   2.2 Otherwise stores the chunk locally and sends an rpc request to the leader
     specifying:
      - the snapshot index (applied index on leader at the moment of snapshot
        creation)
      - the max space id of the chunks so far received
      - the number of tuples in the dump of the last space
   2.3 If Error::NotALeader is returned:
      - the so far collected data is cleared
      - raft ready state is cleared
      - goto next raft loop iteration is
   2.4 Else if the new snapshot chunk is marked final:
      - apply the data so far collected
      - proceed to applying raft ready state
   2.5 Otherwise (if chunk is not final) goto 2.2

## TODO:
   - how does follower handle NotALeader error
   - test/fix simultaneous snapshot application by several followers
   - test/fix leader change during snapshot application
   - test/fix follower failover during snapshot application
   - box_session_push support
   - ...
