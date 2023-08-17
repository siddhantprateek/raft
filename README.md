# RAFT

> It is the Raft Consensus algorithm Raft implemented in Go.

## Raft Protocol Description 

> Raft nodes exist in one of three states: `follower`, `candidate`, or `leader`. All nodes begin as followers, where they can accept log entries from a leader and cast votes. If no entries arrive, nodes switch to candidates, seeking votes from peers. With a quorum of votes, a candidate becomes a leader. Leaders manage log entries and replicate to followers, also handling queries for real-time data.

Once a cluster has a leader, it can take new log entries. Clients can ask the leader to append entries, which are opaque data to Raft. The leader stores entries, replicates to followers, and after commit, applies them to a finite state machine (FSM). The FSM, tailored to each application, is implemented using an interface.

Addressing the growing log issue, Raft snapshots the current state and compacts logs. Because restoring FSM state must match log replay, logs leading to a state are removed automatically, averting infinite disk usage and minimizing replay time.

Updating the peer set for new or leaving servers is manageable with a quorum. Yet, a challenge arises if quorum isn't attainable. For instance, if only A and B exist, and one fails, quorum isn't possible. Thus, the cluster can't add/remove nodes or commit entries, causing unavailability. Manual intervention to remove one node and restart the other in bootstrap mode is needed to recover.

In essence, Raft ensures consensus among nodes by transitioning states, enabling log management, and addressing membership changes, all while striving to maintain availability and reliability.

## Working 

- Creates a simulated network with the specified nodes and initializes channels for message communication.

```go
func CreateNetwork(nodes ...int) *network {
	nt := network{recvQueue: make(map[int]chan Message, 0)}

	for _, node := range nodes {
		nt.recvQueue[node] = make(chan Message, 1024)
	}

	return &nt
}

```
- Initializes a new Raft server/node with a given ID, role (Follower, Candidate, Leader), communication network, and list of other nodes in the cluster.

```go
func NewServer(id int, role Role, nt nodeNetwork, nodeList ...int) *RaftServer {
	rand.Seed(time.Now().UnixNano())
	expiredMiliSec := rand.Intn(5) + 1
	serv := &RaftServer{id: id,
		role:        role,
		nt:          nt,
		expiredTime: expiredMiliSec,
		isAlive:     true,
		nodeList:    nodeList,
		db:          submittedItems{}}
	go serv.runServerLoop()
	return serv
}

```

- `runServerLoop()`The main loop of the Raft server that continuously handles its state based on its role (Follower, Candidate, Leader).

```go
func (sev *RaftServer) runServerLoop() {

	for {
		switch sev.role {
		case Leader:
			sev.runLeaderLoop()
		case Candidate:
			sev.runCandidateLoop()
		case Follower:
			sev.runFollowerLoop()
		}

		//timer base on milli-second.
		time.Sleep(100 * time.Millisecond)
	}
}
```

-  Sends heartbeats from the leader to its followers.
```go
func (sev *RaftServer) sendHearbit() {
	latestData := sev.db.getLatestLogs()
	for _, node := range sev.nodeList {
		hbMsg := Message{from: sev.id, 
        to: node, 
        typ: Heartbit, 
        val: *latestData}
		sev.nt.send(hbMsg)
	}
}
```

- `majorityCount()` : Calculates the majority count needed for reaching consensus in the Raft algorithm.

```go
func (sev *RaftServer) majorityCount() int {
	return len(sev.nodeList)/2 + 1
}

```

- `roleChange(newRole Role)`: Changes the role of the Raft server and logs the role change.

```go
func (sev *RaftServer) roleChange(newRole Role) {
	log.Println("note:", sev.id, 
    " change role from ", sev.role,
    " to ", newRole)
	sev.role = newRole
}
```

### Reference 

- [Raft Research Paper](https://raft.github.io/raft.pdf)
